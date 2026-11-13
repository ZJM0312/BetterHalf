import SwiftUI
import UIKit

enum Theme {
    static let pink = Color(red: 1, green: 0.435, blue: 0.557)
    static let pinkSoft = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.23, green: 0.13, blue: 0.19, alpha: 1) : UIColor(red: 1, green: 0.89, blue: 0.92, alpha: 1) })
    static let bg = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.09, green: 0.075, blue: 0.10, alpha: 1) : UIColor(red: 1, green: 0.97, blue: 0.976, alpha: 1) })
    static let card = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.133, green: 0.11, blue: 0.15, alpha: 1) : .white })
    static let gradient = LinearGradient(colors: [Color(red: 1, green: 0.56, blue: 0.64), Color(red: 0.78, green: 0.43, blue: 0.84)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let wheel: [Color] = [
        Color(red: 1, green: 0.56, blue: 0.64), Color(red: 1, green: 0.72, blue: 0.42), Color(red: 1, green: 0.85, blue: 0.42),
        Color(red: 0.56, green: 0.84, blue: 0.58), Color(red: 0.42, green: 0.78, blue: 1), Color(red: 0.66, green: 0.55, blue: 1),
        Color(red: 1, green: 0.56, blue: 0.85), Color(red: 0.5, green: 0.88, blue: 0.82),
    ]
}

struct CardStyle: ViewModifier {
    var fill: Color = Theme.card
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.pink.opacity(0.08), radius: 12, y: 4)
    }
}

extension View {
    func card(_ fill: Color = Theme.card) -> some View { modifier(CardStyle(fill: fill)) }
    func screenBackground() -> some View { background(Theme.bg.ignoresSafeArea()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = true
    func makeBody(configuration: Configuration) -> some View { StyledLabel(configuration: configuration, fullWidth: fullWidth) }

    private struct StyledLabel: View {
        let configuration: Configuration
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13).padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
        }
    }
}

struct SectionTitle: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.headline)
            if let trailing { Text(trailing).font(.subheadline).foregroundStyle(.secondary) }
            Spacer()
        }
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 28)
    }
}

/// Data-URL <-> UIImage helpers (photos are stored the same way as the web app).
enum PhotoCodec {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(from dataURL: String) -> UIImage? {
        if let hit = cache.object(forKey: dataURL as NSString) { return hit }
        guard let comma = dataURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])),
              let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: dataURL as NSString)
        return img
    }

    /// Downscale to `maxSide` and JPEG-encode, matching the web app's 720px / 0.7 settings.
    static func dataURL(from data: Data, maxSide: CGFloat = 720, quality: CGFloat = 0.7) -> String? {
        guard let img = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: (img.size.width * scale).rounded(), height: (img.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: quality) else { return nil }
        return "data:image/jpeg;base64," + jpeg.base64EncodedString()
    }
}
