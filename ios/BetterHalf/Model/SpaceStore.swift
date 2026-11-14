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
        if disk != state { state = disk }
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

    /// Mutate state and persist. No-op before onboarding.
    func update(_ body: (inout SpaceState) -> Void) {
        guard var s = state else { return }
        body(&s)
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
        guard let s = try? JSONDecoder().decode(SpaceState.self, from: data), s.v == 1,
              !s.me.isEmpty, !s.startDate.isEmpty else { return false }
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let blobs = dict["blobs"] as? [String: String] {
            for (name, b64) in blobs where !name.contains("/") {
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
        let theirs = incoming.flippedPerspective()
        guard let mine = state else {
            state = theirs // joining the partner's space on a fresh phone
            save()
            return
        }
        state = SyncMerge.merge(mine: mine, theirs: theirs, partnerOwnName: incoming.me)
        save()
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

/// Conflict-free-ish merge of two phones' data: union by id, tombstones win, per-field answers.
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

        out.moments = union(mine.moments, theirs.moments, tomb) { a, _ in a }
            .sorted { $0.date > $1.date }
        out.anniversaries = union(mine.anniversaries, theirs.anniversaries, tomb) { a, _ in a }
        out.bucket = union(mine.bucket, theirs.bucket, tomb) { a, b in
            var m = a
            m.done = a.done || b.done
            m.doneAt = [a.doneAt, b.doneAt].compactMap { $0 }.max()
            return m
        }
        out.decisions = union(mine.decisions, theirs.decisions, tomb) { a, b in
            var m = a
            for o in b.options where !m.options.contains(o) && m.options.count < 12 { m.options.append(o) }
            return m
        }
        let pets = union(mine.petList, theirs.petList, tomb) { a, b in
            var m = a
            m.lastFed = max(a.lastFed, b.lastFed)
            m.lastPetted = max(a.lastPetted, b.lastPetted)
            m.affection = max(a.affection, b.affection)
            if m.imageFile == nil { m.imageFile = b.imageFile }
            return m
        }
        out.pets = pets.isEmpty ? mine.pets : pets

        for (day, b) in theirs.answers {
            var a = out.answers[day] ?? Answer()
            if (a.me ?? "").isEmpty { a.me = b.me }
            if (a.partner ?? "").isEmpty { a.partner = b.partner }
            out.answers[day] = a
        }
        return out
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
