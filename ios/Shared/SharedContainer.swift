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
    /// Always a file directly inside the media folder. Any name that isn't an app-generated media name
    /// (e.g. "../betterhalf.json" smuggled in by synced data) maps to a path that never exists.
    static func mediaURL(_ fileName: String) -> URL {
        mediaDir.appendingPathComponent(PrivacyGuard.isSafeMediaName(fileName) ? fileName : "_blocked_")
    }
    static func hasMedia(_ fileName: String) -> Bool {
        PrivacyGuard.isSafeMediaName(fileName) && FileManager.default.fileExists(atPath: mediaURL(fileName).path)
    }

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

/// The privacy boundary between the two partners' phones, written once and used by every sync path.
///
/// What can ever cross from one phone to the other:
///   1. `SpaceState` — the JSON the two of you typed into this app (names, memories' text, answers, lists, pets).
///   2. Media files the app itself created in its own media folder AND that `SpaceState` references.
/// Nothing else: no photo library, contacts, location, files, clipboard, device info or other apps' data.
/// The sync code has no API to request anything else, and everything incoming is validated here.
enum PrivacyGuard {
    /// App-generated media names look like "a1b2c3d4e5f6.jpg" / "<id>-<timestamp>.png". No paths, no dots-only names.
    static func isSafeMediaName(_ name: String) -> Bool {
        guard name.count <= 80, !name.hasPrefix("."), name.filter({ $0 == "." }).count == 1 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard name.unicodeScalars.allSatisfy(allowed.contains) else { return false }
        let parts = name.split(separator: ".")
        return parts.count == 2 && !parts[0].isEmpty && (1...8).contains(parts[1].count)
    }

    /// Clean data that came from the partner (or a backup) before it touches this phone:
    /// drop any file reference that isn't a plain app media name.
    static func sanitize(_ s: SpaceState) -> SpaceState {
        var out = s
        out.moments = s.moments.map { m in
            var m = m
            m.media = m.media?.filter { isSafeMediaName($0.fileName) }
            if m.media?.isEmpty == true { m.media = nil }
            return m
        }
        out.pets = s.pets?.map { p in
            var p = p
            if let f = p.imageFile, !isSafeMediaName(f) { p.imageFile = nil }
            return p
        }
        return out
    }
}
