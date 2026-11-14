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
    /// Latest "快来回答 / 想你了" poke sent through sync.
    var poke: Poke? = nil

    var petList: [Pet] {
        get { pets ?? [] }
        set { pets = newValue }
    }

    mutating func markDeleted(_ id: String) {
        var d = deleted ?? []
        if !d.contains(id) { d.append(id) }
        deleted = d
    }

    /// Every media file this state references — the ONLY files sync or backup will ever read and send.
    var referencedFiles: [String] {
        (moments.flatMap { ($0.media ?? []).map(\.fileName) } + petList.compactMap(\.imageFile))
            .filter(PrivacyGuard.isSafeMediaName)
    }

    /// The same data seen from the partner's phone: "me" and "partner" swap.
    func flippedPerspective() -> SpaceState {
        var s = self
        swap(&s.me, &s.partner)
        s.moments = moments.map { m in
            var m = m
            m.by = m.by.other
            m.notes = m.notes?.map { var n = $0; n.by = n.by.other; return n }
            return m
        }
        s.answers = answers.mapValues { Answer(me: $0.partner, partner: $0.me, meAt: $0.partnerAt, partnerAt: $0.meAt) }
        return s
    }
}

enum Author: String, Codable {
    case me, partner
    var other: Author { self == .me ? .partner : .me }
}

/// Something one partner sends to the other through sync (shown as a notification there).
struct Poke: Codable, Equatable {
    enum Kind: String, Codable { case answer, miss }
    var kind: Kind
    var from: String
    var at: Double = Date().timeIntervalSince1970
}

struct Moment: Codable, Identifiable, Equatable {
    var id: String = newID()
    var date: String
    var text: String
    var mood: String
    var photo: String? // legacy/web: JPEG data URL
    var by: Author
    var media: [MediaItem]? = nil // iOS: files in the shared media folder
    /// Last edit time + editor name; the newer edit wins when both phones changed the same memory.
    var updatedAt: Double? = nil
    var editedBy: String? = nil
    /// Each partner's own additions. They never overwrite each other, so both can add at the same time.
    var notes: [MomentNote]? = nil
}

struct MomentNote: Codable, Identifiable, Equatable {
    var id: String = newID()
    var by: Author
    var text: String
    var at: Double = Date().timeIntervalSince1970
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
    var updatedAt: Double? = nil
}

struct BucketItem: Codable, Identifiable, Equatable {
    var id: String = newID()
    var text: String
    var done: Bool = false
    var doneAt: String?
    var updatedAt: Double? = nil
}

struct DecisionList: Codable, Identifiable, Equatable {
    var id: String = newID()
    var name: String
    var options: [String]
    var updatedAt: Double? = nil
    var emoji: String? = nil
    /// Option → weight 1…5 (missing = 1). Heavier options get bigger slices and win more often.
    var weights: [String: Int]? = nil
    /// "不重复" mode: options already drawn are skipped until everything has been drawn once.
    var noRepeat: Bool? = nil
    var drawn: [String]? = nil

    func weight(_ option: String) -> Int { max(1, min(5, weights?[option] ?? 1)) }
    /// Options still in play (all of them unless no-repeat mode has used some up).
    var available: [String] {
        guard noRepeat == true else { return options }
        let left = options.filter { !(drawn ?? []).contains($0) }
        return left.isEmpty ? options : left
    }
}

struct Answer: Codable, Equatable {
    var me: String?
    var partner: String?
    var meAt: Double? = nil
    var partnerAt: Double? = nil
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
    /// Name of whoever did `lastAction` (so the other partner sees "小红 刚刚喂过").
    var lastActionBy: String? = nil
    /// A message left for the other partner, delivered by the pet ("小红让我告诉你…").
    var note: PetNote? = nil
    /// Recent care, newest first (capped), and the days anyone cared for the pet (for the streak).
    var log: [PetLogEntry]? = nil
    var careDays: [String]? = nil
    var accessory: String? = nil
    /// Days whose daily wish reward was already claimed.
    var wishClaimed: [String]? = nil
    /// Profile edits (name, look, personality, accessory); stats merge field by field.
    var updatedAt: Double? = nil
}

struct PetNote: Codable, Equatable {
    var text: String
    var from: String
    var at: Double = Date().timeIntervalSince1970
}

struct PetLogEntry: Codable, Identifiable, Equatable {
    var id: String = newID()
    var action: String
    var by: String
    var at: Double = Date().timeIntervalSince1970
}

func newID() -> String { String(UUID().uuidString.prefix(12)).lowercased() }
