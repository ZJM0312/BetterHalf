import Foundation

/// Storage shared by the app and its widgets through an App Group.
enum SharedContainer {
    static let appGroup = "group.com.betterhalf.hxiz1q"

    static var baseURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var stateURL: URL { baseURL.appendingPathComponent("betterhalf.json") }
    static var mediaDir: URL {
        let url = baseURL.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func mediaURL(_ fileName: String) -> URL { mediaDir.appendingPathComponent(fileName) }
    static func hasMedia(_ fileName: String) -> Bool { FileManager.default.fileExists(atPath: mediaURL(fileName).path) }

    static func load() -> SpaceState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(SpaceState.self, from: data)
    }

    /// "Until first unlock" protection so lock-screen widgets can still read the file.
    static func save(_ state: SpaceState) throws {
        try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: stateURL)
        try? FileManager.default.removeItem(at: mediaDir)
    }

    /// v1.0 kept the file in the app's Documents folder; move it into the shared container once.
    static func migrateLegacyIfNeeded() {
        let fm = FileManager.default
        let legacy = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("betterhalf.json")
        guard legacy != stateURL, fm.fileExists(atPath: legacy.path), !fm.fileExists(atPath: stateURL.path) else { return }
        try? fm.moveItem(at: legacy, to: stateURL)
    }
}
