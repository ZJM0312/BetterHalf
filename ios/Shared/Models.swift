import Foundation

/// Mirrors the web app's localStorage schema (v1) so backups are interchangeable.
/// iOS-only fields are optional so web backups (which lack them) still decode.
struct SpaceState: Codable, Equatable {
    var v: Int = 1
    var me: String
    var partner: String
    var startDate: String // yyyy-MM-dd
    var moments: [Moment] = []
    var anniversaries: [Anniversary] = []
    var bucket: [BucketItem] = []
    var decisions: [DecisionList] = []
    var answers: [String: Answer] = [:]
    // iOS extensions
    var pets: [Pet]? = nil
    /// Tombstones so a deletion on one phone also deletes on the other during P2P sync.
    var deleted: [String]? = nil
    var profileUpdatedAt: Double? = nil

    var petList: [Pet] {
        get { pets ?? [] }
        set { pets = newValue }
    }

    mutating func markDeleted(_ id: String) {
        var d = deleted ?? []
        if !d.contains(id) { d.append(id) }
        deleted = d
    }

    /// Every media file this state references (for backups and P2P transfer).
    var referencedFiles: [String] {
        moments.flatMap { ($0.media ?? []).map(\.fileName) } + petList.compactMap(\.imageFile)
    }

    /// The same data seen from the partner's phone: "me" and "partner" swap.
    func flippedPerspective() -> SpaceState {
        var s = self
        swap(&s.me, &s.partner)
        s.moments = moments.map { var m = $0; m.by = m.by == .me ? .partner : .me; return m }
        s.answers = answers.mapValues { Answer(me: $0.partner, partner: $0.me) }
        return s
    }
}

enum Author: String, Codable { case me, partner }

struct Moment: Codable, Identifiable, Equatable {
    var id: String = newID()
    var date: String
    var text: String
    var mood: String
    var photo: String? // legacy/web: JPEG data URL
    var by: Author
    var media: [MediaItem]? = nil // iOS: files in the shared media folder
}

enum MediaKind: String, Codable { case image, video, audio }

struct MediaItem: Codable, Identifiable, Equatable {
    var id: String = newID()
    var kind: MediaKind
    var ext: String
    var duration: Double? = nil
    var fileName: String { "\(id).\(ext)" }
}

struct Anniversary: Codable, Identifiable, Equatable {
    var id: String = newID()
    var name: String
    var date: String
    var yearly: Bool
}

struct BucketItem: Codable, Identifiable, Equatable {
    var id: String = newID()
    var text: String
    var done: Bool = false
    var doneAt: String?
}

struct DecisionList: Codable, Identifiable, Equatable {
    var id: String = newID()
    var name: String
    var options: [String]
}

struct Answer: Codable, Equatable {
    var me: String?
    var partner: String?
    var bothAnswered: Bool { !(me ?? "").isEmpty && !(partner ?? "").isEmpty }
    subscript(_ who: Author) -> String? {
        get { who == .me ? me : partner }
        set { if who == .me { me = newValue } else { partner = newValue } }
    }
}

struct Pet: Codable, Identifiable, Equatable {
    var id: String = newID()
    var name: String
    var species: String // emoji, e.g. 🐱
    var imageFile: String? // background-removed PNG in the media folder
    var createdAt: Double = Date().timeIntervalSince1970
    var lastFed: Double = Date().timeIntervalSince1970
    var lastPetted: Double = Date().timeIntervalSince1970
    var affection: Int = 0
    var lastAction: String? = nil
    var lastActionAt: Double? = nil
    var personality: String? = nil // e.g. "粘人精、吃货"
    var appearance: String? = nil  // used for AI image prompts
}

func newID() -> String { String(UUID().uuidString.prefix(12)).lowercased() }
