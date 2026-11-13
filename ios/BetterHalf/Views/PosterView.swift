import SwiftUI
import Photos

/// 1080x1440 shareable poster, same layout as the web version.
struct PosterView: View {
    let me: String, partner: String, days: Int, startDate: String, line: String

    var body: some View {
        ZStack {
            Theme.gradient
            ForEach(0..<18, id: \.self) { i in
                Image(systemName: "heart.fill")
                    .font(.system(size: CGFloat(40 + (i % 5) * 28)))
                    .foregroundStyle(.white.opacity(0.12))
                    .position(x: CGFloat((i * 173) % 1080), y: CGFloat((i * 311) % 1440))
            }
            VStack(spacing: 0) {
                Text("\(me)  ♥  \(partner)").font(.system(size: 52, weight: .semibold)).padding(.top, 280)
                Text("我们已经在一起").font(.system(size: 44)).padding(.top, 140)
                Text("\(days)").font(.system(size: 300, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                Text("天").font(.system(size: 56))
                Text("“\(line)”").font(.system(size: 40).italic()).opacity(0.92).padding(.top, 110)
                Spacer()
                Text("since \(DateKit.shortDate(startDate))  ·  BetterHalf").font(.system(size: 32)).opacity(0.75).padding(.bottom, 90)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 60)
        }
        .frame(width: 1080, height: 1440)
    }

    @MainActor
    static func render(me: String, partner: String, days: Int, startDate: String) -> UIImage? {
        let view = PosterView(me: me, partner: partner, days: days, startDate: startDate,
                              line: Catalog.posterLines[days % Catalog.posterLines.count])
        let r = ImageRenderer(content: view)
        r.scale = 1
        return r.uiImage
    }
}

struct PosterSheet: View {
    let image: UIImage
    let days: Int
    @Environment(\.dismiss) private var dismiss
    @State private var saved: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 8, y: 4)
                if let saved { Text(saved).font(.footnote).foregroundStyle(.secondary) }
                HStack(spacing: 12) {
                    Button("保存到相册", systemImage: "square.and.arrow.down") { save() }
                        .buttonStyle(PrimaryButtonStyle())
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("我们在一起第 \(days) 天", image: Image(uiImage: image))) {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold)).padding(.vertical, 13).frame(maxWidth: .infinity)
                            .background(Theme.pinkSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(20)
            .navigationTitle("分享卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }

    private func save() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in saved = "没有相册权限，可以在“设置”里开启" }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { ok, _ in
                Task { @MainActor in saved = ok ? "已保存到相册 ✓ 去发朋友圈 / 小红书吧" : "保存失败，请重试" }
            }
        }
    }
}
