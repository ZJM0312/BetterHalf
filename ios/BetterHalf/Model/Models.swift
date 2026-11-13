import Foundation

/// Mirrors the web app's localStorage schema (v1) so backups are interchangeable.
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
}

enum Author: String, Codable { case me, partner }

struct Moment: Codable, Identifiable, Equatable {
    var id: String = newID()
    var date: String
    var text: String
    var mood: String
    var photo: String? // JPEG data URL, same as web
    var by: Author
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

func newID() -> String { String(UUID().uuidString.prefix(12)).lowercased() }
