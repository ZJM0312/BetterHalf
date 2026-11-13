import Foundation
import Observation

/// Single source of truth. Persists to Documents/betterhalf.json on every change.
@Observable
final class SpaceStore {
    private(set) var state: SpaceState?
    var lastError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("betterhalf.json")
        if let data = try? Data(contentsOf: self.fileURL) {
            state = try? JSONDecoder().decode(SpaceState.self, from: data)
        }
    }

    // MARK: lifecycle
    func create(me: String, partner: String, startDate: String) {
        state = SpaceState(me: me, partner: partner, startDate: startDate,
                           decisions: [DecisionList(name: Catalog.decisionPresets[0].name,
                                                    options: Catalog.decisionPresets[0].options)])
        save()
    }

    func reset() {
        state = nil
        try? FileManager.default.removeItem(at: fileURL)
        Reminders.cancelAll()
    }

    func exportData() throws -> Data {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        return try enc.encode(state)
    }

    @discardableResult
    func importData(_ data: Data) -> Bool {
        guard let s = try? JSONDecoder().decode(SpaceState.self, from: data), s.v == 1,
              !s.me.isEmpty, !s.startDate.isEmpty else { return false }
        state = s; save(); return true
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
            try JSONEncoder().encode(state).write(to: fileURL, options: [.atomic, .completeFileProtection])
            lastError = nil
        } catch {
            lastError = "保存失败：\(error.localizedDescription)"
        }
        Reminders.reschedule(for: state)
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
