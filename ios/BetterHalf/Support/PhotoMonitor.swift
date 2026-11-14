import AVFoundation
import Photos
import UIKit

/// The two photo switches in Settings. Both are the user's choice and both are checked before any photo code runs.
/// Photos are only ever read on this phone; nothing from the library is synced unless the user adds it to a memory.
enum PhotoAccess {
    static let pickerKey = "photoPickerEnabled"

    /// 「允许从相册选择照片」— on by default (the system picker only hands over what the user taps).
    static var pickerEnabled: Bool { UserDefaults.standard.object(forKey: pickerKey) as? Bool ?? true }

    static func setPickerEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: pickerKey)
        if !on { PhotoMonitor.disable() } // new-photo hints read the library too, so they go off with it
    }
}

/// Spots photos/videos taken since the last check so the app can suggest turning them into a memory.
/// iOS doesn't let apps watch the library in the background, so this runs whenever the app opens.
enum PhotoMonitor {
    static let enabledKey = "newPhotoHintsEnabled"
    private static let lastCheckKey = "newPhotoLastCheck"

    /// 「读取最新照片并提醒记录」— off by default; needs the photo switch on and system permission.
    static var isEnabled: Bool { PhotoAccess.pickerEnabled && UserDefaults.standard.bool(forKey: enabledKey) }

    static func enable() async -> Bool {
        guard PhotoAccess.pickerEnabled else { return false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let ok = status == .authorized || status == .limited
        UserDefaults.standard.set(ok, forKey: enabledKey)
        if ok, UserDefaults.standard.object(forKey: lastCheckKey) == nil {
            UserDefaults.standard.set(Date().addingTimeInterval(-86_400).timeIntervalSince1970, forKey: lastCheckKey)
        }
        return ok
    }

    static func disable() { UserDefaults.standard.set(false, forKey: enabledKey) }

    static func newAssets(limit: Int = 12) -> [PHAsset] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard isEnabled, status == .authorized || status == .limited else { return [] }
        let since = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: lastCheckKey))
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "creationDate > %@ AND (mediaType == %d OR mediaType == %d)",
                                     since as NSDate, PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = limit
        let result = PHAsset.fetchAssets(with: opts)
        return (0..<result.count).map { result.object(at: $0) }
    }

    static func markChecked() { UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey) }

    static func thumbnail(_ asset: PHAsset, side: CGFloat = 160) async -> UIImage? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: side * 2, height: side * 2),
                                                  contentMode: .aspectFill, options: opts) { img, _ in cont.resume(returning: img) }
        }
    }

    /// Loads the asset as a composer attachment.
    static func pending(from asset: PHAsset) async -> PendingMedia? {
        if asset.mediaType == .video {
            let url: URL? = await withCheckedContinuation { cont in
                let opts = PHVideoRequestOptions()
                opts.isNetworkAccessAllowed = true
                opts.deliveryMode = .highQualityFormat
                PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { av, _, _ in
                    guard let src = (av as? AVURLAsset)?.url else { cont.resume(returning: nil); return }
                    let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + src.pathExtension)
                    cont.resume(returning: (try? FileManager.default.copyItem(at: src, to: dst)) != nil ? dst : nil)
                }
            }
            guard let url else { return nil }
            return await MediaImporter.pendingVideo(at: url)
        }
        let data: Data? = await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { d, _, _, _ in cont.resume(returning: d) }
        }
        return data.flatMap { MediaImporter.pendingImage(data: $0) }
    }
}
