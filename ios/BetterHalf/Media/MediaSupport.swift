import SwiftUI
import AVFoundation
import AVKit
import CoreTransferable
import ImageIO
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Picking

/// A video picked from Photos, copied to a temp file we own.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: received.file, to: dst)
            return PickedMovie(url: dst)
        }
    }
}

/// An attachment waiting in the composer before the moment is saved.
struct PendingMedia: Identifiable {
    let id = UUID()
    let kind: MediaKind
    var data: Data? = nil   // images
    var fileURL: URL? = nil // video / audio temp file
    var ext: String
    var duration: Double? = nil
    var thumbnail: UIImage? = nil
}

enum MediaImporter {
    /// Images are re-encoded to JPEG (≤1600px) so HEIC/PNG/WebP all display everywhere; GIFs are kept as-is.
    static func load(_ item: PhotosPickerItem) async -> PendingMedia? {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try? await item.loadTransferable(type: PickedMovie.self) else { return nil }
            return await pendingVideo(at: movie.url)
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return pendingImage(data: data, isGIF: item.supportedContentTypes.contains(.gif))
    }

    static func pendingImage(data: Data, isGIF: Bool = false) -> PendingMedia? {
        if isGIF, let img = UIImage(data: data) {
            return PendingMedia(kind: .image, data: data, ext: "gif", thumbnail: img)
        }
        guard let img = Thumbnailer.downsample(data: data, maxPixel: 1600),
              let jpeg = img.jpegData(compressionQuality: 0.82) else { return nil }
        return PendingMedia(kind: .image, data: jpeg, ext: "jpg", thumbnail: img)
    }

    static func pendingVideo(at url: URL) async -> PendingMedia {
        let asset = AVURLAsset(url: url)
        let seconds = (try? await asset.load(.duration)).map(CMTimeGetSeconds)
        let thumb = await Thumbnailer.videoFrame(url: url)
        return PendingMedia(kind: .video, fileURL: url, ext: url.pathExtension.isEmpty ? "mov" : url.pathExtension,
                            duration: seconds, thumbnail: thumb)
    }
}

// MARK: - Thumbnails

enum Thumbnailer {
    private static let cache = NSCache<NSString, UIImage>()

    static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return downsample(src, maxPixel: maxPixel)
    }

    static func downsample(_ src: CGImageSource, maxPixel: CGFloat) -> UIImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func videoFrame(url: URL) async -> UIImage? {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 600, height: 600)
        guard let (cg, _) = try? await gen.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// Cached thumbnail for a stored media item.
    static func thumbnail(for item: MediaItem, maxPixel: CGFloat = 600) async -> UIImage? {
        let key = "\(item.fileName)@\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let url = SharedContainer.mediaURL(item.fileName)
        var img: UIImage?
        switch item.kind {
        case .image:
            if let src = CGImageSourceCreateWithURL(url as CFURL, nil) { img = downsample(src, maxPixel: maxPixel) }
        case .video:
            img = await videoFrame(url: url)
        case .audio:
            img = nil
        }
        if let img { cache.setObject(img, forKey: key) }
        return img
    }
}

func formatDuration(_ s: Double?) -> String {
    guard let s, s.isFinite else { return "" }
    let t = Int(s.rounded())
    return String(format: "%d:%02d", t / 60, t % 60)
}

// MARK: - Voice recording

@Observable
final class VoiceRecorder: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    var elapsed: Double = 0
    var denied = false
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var url: URL?

    func start() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { denied = true; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            let rec = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ])
            rec.record(forDuration: 300) // 5 minutes max
            recorder = rec
            self.url = url
            elapsed = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self, let r = self.recorder else { return }
                self.elapsed = r.currentTime
                if !r.isRecording { self.timer?.invalidate() }
            }
        } catch {
            isRecording = false
        }
    }

    /// Stops and returns the pending voice memo (nil if too short).
    func stop() -> PendingMedia? {
        let duration = recorder?.currentTime ?? elapsed
        recorder?.stop()
        timer?.invalidate()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard let url, duration >= 0.8 else { return nil }
        return PendingMedia(kind: .audio, fileURL: url, ext: "m4a", duration: duration)
    }
}

// MARK: - Display

/// Grid of photos/videos inside a moment card; tap opens the full-screen viewer.
struct MediaGrid: View {
    let items: [MediaItem]
    @State private var viewerIndex: Int?

    var body: some View {
        let visual = items.filter { $0.kind != .audio }
        let audio = items.filter { $0.kind == .audio }
        VStack(alignment: .leading, spacing: 8) {
            if visual.count == 1 {
                MediaThumb(item: visual[0], maxPixel: 1200, fill: false).onTapGesture { viewerIndex = 0 }
            } else if !visual.isEmpty {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: visual.count <= 4 ? 2 : 3)
                LazyVGrid(columns: cols, spacing: 4) {
                    ForEach(Array(visual.enumerated()), id: \.element.id) { i, item in
                        MediaThumb(item: item, maxPixel: 400, fill: true)
                            .aspectRatio(1, contentMode: .fit)
                            .onTapGesture { viewerIndex = i }
                    }
                }
            }
            ForEach(audio) { AudioPlayerRow(url: SharedContainer.mediaURL($0.fileName), duration: $0.duration) }
        }
        .fullScreenCover(item: Binding(get: { viewerIndex.map(ViewerStart.init) }, set: { viewerIndex = $0?.index })) { start in
            MediaViewer(items: visual, index: start.index)
        }
    }
}

private struct ViewerStart: Identifiable { let index: Int; var id: Int { index } }

struct MediaThumb: View {
    let item: MediaItem
    var maxPixel: CGFloat = 400
    var fill = true
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                if fill {
                    Color.clear.overlay(Image(uiImage: image).resizable().scaledToFill()).clipped()
                } else {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            } else if !SharedContainer.hasMedia(item.fileName) {
                Rectangle().fill(Theme.pinkSoft).overlay(
                    VStack(spacing: 4) { Image(systemName: "icloud.and.arrow.down"); Text("等待同步").font(.caption2) }
                        .foregroundStyle(.secondary))
                    .frame(minHeight: 120)
            } else {
                Rectangle().fill(Theme.pinkSoft).frame(minHeight: 120).overlay(ProgressView())
            }
            if item.kind == .video {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "play.circle.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4).frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text(formatDuration(item.duration)).font(.caption2.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(.black.opacity(0.5), in: Capsule()).padding(6)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .task(id: item.id) { image = await Thumbnailer.thumbnail(for: item, maxPixel: maxPixel) }
    }
}

struct AudioPlayerRow: View {
    let url: URL
    let duration: Double?
    @State private var player: AVAudioPlayer?
    @State private var playing = false
    @State private var progress: Double = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggle) {
                Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill").font(.title)
            }
            .disabled(!FileManager.default.fileExists(atPath: url.path))
            .accessibilityLabel(playing ? "暂停语音" : "播放语音")
            HStack(spacing: 2) {
                ForEach(0..<28, id: \.self) { i in
                    Capsule()
                        .fill(Double(i) / 28 <= progress ? Theme.pink : Theme.pink.opacity(0.25))
                        .frame(width: 3, height: CGFloat(6 + (i * 37 % 17)))
                }
            }
            Spacer()
            Text(formatDuration(duration)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Theme.pinkSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDisappear { stop() }
    }

    private func toggle() {
        if playing { stop(); return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        player = p
        p.play()
        playing = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let p = player else { return }
            progress = p.duration > 0 ? p.currentTime / p.duration : 0
            if !p.isPlaying { stop() }
        }
    }

    private func stop() {
        player?.stop()
        timer?.invalidate()
        playing = false
        progress = 0
    }
}

/// Full-screen swipeable viewer: pinch / double-tap to zoom photos, play videos inline.
struct MediaViewer: View {
    let items: [MediaItem]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    Group {
                        if item.kind == .video {
                            VideoPlayer(player: AVPlayer(url: SharedContainer.mediaURL(item.fileName)))
                        } else {
                            ZoomableImage(url: SharedContainer.mediaURL(item.fileName))
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title).symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.25))
            }
            .padding()
            .accessibilityLabel("关闭")
        }
        .statusBarHidden()
    }
}

private struct ZoomableImage: View {
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        if let img = UIImage(contentsOfFile: url.path) {
            Image(uiImage: img).resizable().scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(MagnifyGesture()
                    .onChanged { scale = max(1, min(5, lastScale * $0.magnification)) }
                    .onEnded { _ in lastScale = scale; if scale == 1 { offset = .zero; lastOffset = .zero } })
                .simultaneousGesture(scale > 1 ? DragGesture()
                    .onChanged { offset = CGSize(width: lastOffset.width + $0.translation.width, height: lastOffset.height + $0.translation.height) }
                    .onEnded { _ in lastOffset = offset } : nil)
                .onTapGesture(count: 2) {
                    withAnimation(.spring) {
                        scale = scale > 1 ? 1 : 2.5
                        lastScale = scale
                        if scale == 1 { offset = .zero; lastOffset = .zero }
                    }
                }
        } else {
            Text("文件还没有同步过来").foregroundStyle(.white.opacity(0.7))
        }
    }
}
