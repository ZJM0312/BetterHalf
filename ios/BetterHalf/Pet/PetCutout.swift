import CoreImage
import UIKit
import Vision

/// Turns a pet photo into a sticker: Vision lifts the subject off the background (iOS 17+).
enum PetCutout {
    static func lift(_ image: UIImage) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let src = normalized(image, maxSide: 1024)
            guard let cg = src.cgImage else { return nil }
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cg)
            do {
                try handler.perform([request])
                guard let obs = request.results?.first, !obs.allInstances.isEmpty else { return nil }
                let buffer = try obs.generateMaskedImage(ofInstances: obs.allInstances, from: handler,
                                                         croppedToInstancesExtent: true)
                let ci = CIImage(cvPixelBuffer: buffer)
                guard let out = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
                return normalized(UIImage(cgImage: out), maxSide: 600)
            } catch {
                return nil
            }
        }.value
    }

    /// Fallback when subject lifting isn't available: a soft circular crop.
    static func circleCrop(_ image: UIImage) -> UIImage {
        let src = normalized(image, maxSide: 600)
        let side = min(src.size.width, src.size.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side)).addClip()
            src.draw(at: CGPoint(x: (side - src.size.width) / 2, y: (side - src.size.height) / 2))
        }
    }

    /// Redraws upright at scale 1 so CGImage orientation matches what the user sees.
    static func normalized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
