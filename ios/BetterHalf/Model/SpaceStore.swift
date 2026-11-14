import Foundation
import Observation
import WidgetKit

/// Single source of truth for the app. Persists to the App Group container on every change,
/// so widgets see updates immediately.
@Observable
final class SpaceStore {
    private(set) var state: SpaceState?
    var lastError: String?

    init() {
        SharedContainer.migrateLegacyIfNeeded()
        state = SharedContainer.load()
    }

    /// Widgets can change pet stats while the app is in the background; pick that up.
    func reloadFromDisk() {
        let disk = SharedContainer.load()
        if disk != state {
            state = disk
            onChange?()
        }
    }

    // MARK: lifecycle
    func create(me: String, partner: String, startDate: String) {
        state = SpaceState(me: me, partner: partner, startDate: startDate,
                           decisions: [DecisionList(name: Catalog.decisionPresets[0].name,
                                                    options: Catalog.decisionPresets[0].options)],
                           profileUpdatedAt: Date().timeIntervalSince1970)
        save()
    }

    func reset() {
        state = nil
        SharedContainer.wipe()
        Reminders.cancelAll()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Called after every local change or merge that changed data (cloud sync uploads on this).
    @ObservationIgnored var onChange: (() -> Void)?
    /// Called with what the partner did, after merging their data.
    @ObservationIgnored var onPartnerEvents: (([SyncEvent]) -> Void)?

    /// Mutate state and persist. No-op before onboarding.
    /// Items that changed get an edit timestamp, so the newer edit wins when both phones edited them.
    func update(_ body: (inout SpaceState) -> Void) {
        guard let old = state else { return }
        var s = old
        body(&s)
        guard s != old else { return }
        EditStamp.apply(old: old, new: &s, editor: s.me, at: Date().timeIntervalSince1970)
        state = s
        save()
    }

    private func save() {
        guard let state else { return }
        do {
            try SharedContainer.save(state)
            lastError = nil
        } catch {
            lastError = "保存失败：\(error.localizedDescription)"
        }
        Reminders.reschedule(for: state)
        WidgetCenter.shared.reloadAllTimelines()
        onChange?()
    }

    // MARK: media files
    func storeMedia(data: Data, kind: MediaKind, ext: String, duration: Double? = nil) -> MediaItem? {
        let item = MediaItem(kind: kind, ext: ext.lowercased(), duration: duration)
        do {
            try data.write(to: SharedContainer.mediaURL(item.fileName), options: .atomic)
            return item
        } catch {
            lastError = "保存媒体失败：\(error.localizedDescription)"
            return nil
        }
    }

    /// Moves a temp file (video / voice memo) into the media folder.
    func storeMedia(fileAt url: URL, kind: MediaKind, duration: Double? = nil) -> MediaItem? {
        let item = MediaItem(kind: kind, ext: url.pathExtension.isEmpty ? "dat" : url.pathExtension.lowercased(), duration: duration)
        do {
            try FileManager.default.moveItem(at: url, to: SharedContainer.mediaURL(item.fileName))
            return item
        } catch {
            lastError = "保存媒体失败：\(error.localizedDescription)"
            return nil
        }
    }

    func deleteMoment(_ m: Moment) {
        for item in m.media ?? [] { try? FileManager.default.removeItem(at: SharedContainer.mediaURL(item.fileName)) }
        update { s in
            s.moments.removeAll { $0.id == m.id }
            s.markDeleted(m.id)
        }
    }

    func deletePet(_ p: Pet) {
        if let f = p.imageFile { try? FileManager.default.removeItem(at: SharedContainer.mediaURL(f)) }
        update { s in
            s.petList.removeAll { $0.id == p.id }
            s.markDeleted(p.id)
        }
    }

    // MARK: backup
    /// JSON in the web format, plus a "blobs" map of base64 media so nothing is lost.
    func exportData() throws -> Data {
        guard let state else { throw CocoaError(.fileNoSuchFile) }
        let base = try JSONEncoder().encode(state)
        guard var dict = try JSONSerialization.jsonObject(with: base) as? [String: Any] else { return base }
        var blobs: [String: String] = [:]
        for name in state.referencedFiles {
            if let data = try? Data(contentsOf: SharedContainer.mediaURL(name)) { blobs[name] = data.base64EncodedString() }
        }
        if !blobs.isEmpty { dict["blobs"] = blobs }
        return try JSONSerialization.data(withJSONObject: dict)
    }

    @discardableResult
    func importData(_ data: Data) -> Bool {
        guard let raw = try? JSONDecoder().decode(SpaceState.self, from: data), raw.v == 1,
              !raw.me.isEmpty, !raw.startDate.isEmpty else { return false }
        let s = PrivacyGuard.sanitize(raw)
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let blobs = dict["blobs"] as? [String: String] {
            for (name, b64) in blobs where s.referencedFiles.contains(name) {
                if let d = Data(base64Encoded: b64) { try? d.write(to: SharedContainer.mediaURL(name)) }
            }
        }
        state = s
        save()
        return true
    }

    // MARK: P2P merge
    /// Merge a snapshot sent from the partner's phone (in *their* perspective).
    func mergeFromPartner(_ incoming: SpaceState) {
        let theirs = PrivacyGuard.sanitize(incoming).flippedPerspective()
        guard let mine = state else {
            state = theirs // joining the partner's space on a fresh phone
            save()
            return
        }
        let merged = SyncMerge.merge(mine: mine, theirs: theirs, partnerOwnName: incoming.me)
        guard merged != mine else { return }
        let events = SyncEvent.diff(before: mine, after: merged)
        state = merged
        save()
        if !events.isEmpty { onPartnerEvents?(events) }
    }

    /// Restore this person's own snapshot (e.g. after reinstalling) — same perspective, no flip.
    func mergeOwnSnapshot(_ ownRaw: SpaceState) {
        let own = PrivacyGuard.sanitize(ownRaw)
        guard let mine = state else {
            state = own
            save()
            return
        }
        var merged = SyncMerge.merge(mine: mine, theirs: own, partnerOwnName: mine.partner)
        merged.me = mine.me
        if merged != mine {
            state = merged
            save()
        }
    }

    /// Ask the partner to come answer / say 想你了 (delivered by sync as a notification).
    func sendPoke(_ kind: Poke.Kind) {
        update { $0.poke = Poke(kind: kind, from: $0.me) }
    }

    // MARK: derived
    var daysTogether: Int {
        guard let s = state else { return 0 }
        return DateKit.daysBetween(s.startDate, DateKit.key()) + 1 // 在一起当天算第 1 天
    }

    func name(_ who: Author) -> String { who == .me ? (state?.me ?? "") : (state?.partner ?? "") }

    /// Consecutive days (ending today) where both partners answered.
    var answerStreak: Int {
        guard let s = state else { return 0 }
        var n = 0
        var d = Date()
        while s.answers[DateKit.key(d)]?.bothAnswered == true {
            n += 1
            d = DateKit.calendar.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }
}

/// Merge of two phones' data. Union by id, tombstones win, and when both sides edited the same item
/// the newer edit wins — except additions (notes, attachments, care log) which are always kept from both.
enum SyncMerge {
    static func merge(mine: SpaceState, theirs: SpaceState, partnerOwnName: String) -> SpaceState {
        var out = mine
        let tomb = Set((mine.deleted ?? []) + (theirs.deleted ?? []))
        out.deleted = Array(tomb).sorted()

        out.partner = partnerOwnName // each person is the authority on their own name
        if (theirs.profileUpdatedAt ?? 0) > (mine.profileUpdatedAt ?? 0) {
            out.startDate = theirs.startDate
            out.profileUpdatedAt = theirs.profileUpdatedAt
        }
        if let p = theirs.poke, p.at > (mine.poke?.at ?? 0) { out.poke = p }

        out.moments = union(mine.moments, theirs.moments, tomb) { a, b in
            var m = newer(a, b, a.updatedAt, b.updatedAt)
            m.media = unionByID(a.media, b.media, tomb)
            m.notes = unionByID(a.notes, b.notes, tomb)?.sorted { $0.at < $1.at }
            return m
        }
        .sorted { $0.date > $1.date }
        out.anniversaries = union(mine.anniversaries, theirs.anniversaries, tomb) { a, b in newer(a, b, a.updatedAt, b.updatedAt) }
        out.bucket = union(mine.bucket, theirs.bucket, tomb) { a, b in
            if a.updatedAt != nil || b.updatedAt != nil { return newer(a, b, a.updatedAt, b.updatedAt) }
            var m = a // legacy items without timestamps
            m.done = a.done || b.done
            m.doneAt = [a.doneAt, b.doneAt].compactMap { $0 }.max()
            return m
        }
        out.decisions = union(mine.decisions, theirs.decisions, tomb) { a, b in
            if a.updatedAt != nil || b.updatedAt != nil { return newer(a, b, a.updatedAt, b.updatedAt) }
            var m = a
            for o in b.options where !m.options.contains(o) && m.options.count < 12 { m.options.append(o) }
            return m
        }
        let pets = union(mine.petList, theirs.petList, tomb) { a, b in
            var m = newer(a, b, a.updatedAt, b.updatedAt) // profile fields
            m.lastFed = max(a.lastFed, b.lastFed)
            m.lastPetted = max(a.lastPetted, b.lastPetted)
            m.affection = max(a.affection, b.affection)
            if m.imageFile == nil { m.imageFile = a.imageFile ?? b.imageFile }
            let act = (a.lastActionAt ?? 0) >= (b.lastActionAt ?? 0) ? a : b
            m.lastAction = act.lastAction; m.lastActionAt = act.lastActionAt; m.lastActionBy = act.lastActionBy
            m.note = [a.note, b.note].compactMap { $0 }.max { $0.at < $1.at }
            m.log = unionByID(a.log, b.log, [])?.sorted { $0.at > $1.at }.prefix(40).map { $0 }
            let days = Set((a.careDays ?? []) + (b.careDays ?? []))
            m.careDays = days.isEmpty ? nil : Array(days.sorted().suffix(120))
            let wishes = Set((a.wishClaimed ?? []) + (b.wishClaimed ?? []))
            m.wishClaimed = wishes.isEmpty ? nil : Array(wishes.sorted().suffix(60))
            return m
        }
        out.pets = pets.isEmpty ? mine.pets : pets

        for (day, b) in theirs.answers {
            var a = out.answers[day] ?? Answer()
            if (a.me ?? "").isEmpty { a.me = b.me; a.meAt = b.meAt }
            if (a.partner ?? "").isEmpty { a.partner = b.partner; a.partnerAt = b.partnerAt }
            out.answers[day] = a
        }
        return out
    }

    private static func newer<T>(_ a: T, _ b: T, _ ta: Double?, _ tb: Double?) -> T { (tb ?? 0) > (ta ?? 0) ? b : a }

    private static func unionByID<T: Identifiable>(_ a: [T]?, _ b: [T]?, _ tomb: Set<String>) -> [T]? where T.ID == String {
        guard a != nil || b != nil else { return nil }
        var seen = Set<String>()
        let all = ((a ?? []) + (b ?? [])).filter { !tomb.contains($0.id) && seen.insert($0.id).inserted }
        return all.isEmpty ? nil : all
    }

    private static func union<T: Identifiable>(_ a: [T], _ b: [T], _ tomb: Set<String>,
                                                resolve: (T, T) -> T) -> [T] where T.ID == String {
        var result = a.filter { !tomb.contains($0.id) }
        var index = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($1.id, $0) })
        for item in b where !tomb.contains(item.id) {
            if let i = index[item.id] { result[i] = resolve(result[i], item) }
            else { index[item.id] = result.count; result.append(item) }
        }
        return result
    }
}

/// Stamps `updatedAt` on items a local edit changed.
enum EditStamp {
    static func apply(old: SpaceState, new s: inout SpaceState, editor: String, at t: Double) {
        let oldMoments = Dictionary(old.moments.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        // Adding a note is not an edit of the memory itself.
        func core(_ m: Moment?) -> Moment? { m.map { var c = $0; c.notes = nil; return c } }
        for i in s.moments.indices where core(oldMoments[s.moments[i].id]) != core(s.moments[i]) {
            s.moments[i].updatedAt = t
            s.moments[i].editedBy = editor
        }
        stamp(&s.anniversaries, old.anniversaries, t) { $0.updatedAt = $1 }
        stamp(&s.bucket, old.bucket, t) { $0.updatedAt = $1 }
        stamp(&s.decisions, old.decisions, t) { $0.updatedAt = $1 }
        // Pets: only profile edits count (feeding etc. merges by field and must not override a rename).
        if var pets = s.pets {
            let oldPets = Dictionary(old.petList.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for i in pets.indices {
                let p = pets[i], o = oldPets[p.id]
                if o == nil || o!.name != p.name || o!.species != p.species || o!.imageFile != p.imageFile
                    || o!.personality != p.personality || o!.appearance != p.appearance || o!.accessory != p.accessory {
                    pets[i].updatedAt = t
                }
            }
            s.pets = pets
        }
        if old.startDate != s.startDate { s.profileUpdatedAt = t }
    }

    private static func stamp<T: Identifiable & Equatable>(_ items: inout [T], _ old: [T], _ t: Double,
                                                            set: (inout T, Double) -> Void) where T.ID == String {
        let o = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for i in items.indices where o[items[i].id] != items[i] { set(&items[i], t) }
    }
}

/// Something the partner did, found by comparing data before and after a merge.
struct SyncEvent: Equatable {
    enum Kind: Equatable {
        case partnerAnswered(day: String, bothDone: Bool)
        case newMoment(String)
        case momentNote(String)
        case petNote(pet: String, text: String)
        case bucketDone(String)
        case poke(Poke.Kind)
    }
    var kind: Kind

    static func diff(before: SpaceState, after: SpaceState) -> [SyncEvent] {
        var out: [SyncEvent] = []
        for (day, a) in after.answers where !(a.partner ?? "").isEmpty && (before.answers[day]?.partner ?? "").isEmpty {
            out.append(.init(kind: .partnerAnswered(day: day, bothDone: a.bothAnswered)))
        }
        let oldMoments = Dictionary(before.moments.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for m in after.moments {
            if let o = oldMoments[m.id] {
                let oldNotes = Set((o.notes ?? []).map(\.id))
                if let n = (m.notes ?? []).last(where: { $0.by == .partner && !oldNotes.contains($0.id) }) {
                    out.append(.init(kind: .momentNote(n.text)))
                }
            } else if m.by == .partner {
                out.append(.init(kind: .newMoment(m.text.isEmpty ? m.mood : m.text)))
            }
        }
        let oldPets = Dictionary(before.petList.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for p in after.petList {
            if let n = p.note, n.from == after.partner, n != oldPets[p.id]?.note {
                out.append(.init(kind: .petNote(pet: p.name, text: n.text)))
            }
        }
        let oldBucket = Dictionary(before.bucket.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for b in after.bucket where b.done && oldBucket[b.id]?.done == false {
            out.append(.init(kind: .bucketDone(b.text)))
        }
        if let p = after.poke, p.from == after.partner, p != before.poke, Date().timeIntervalSince1970 - p.at < 6 * 3600 {
            out.append(.init(kind: .poke(p.kind)))
        }
        return out
    }
}
