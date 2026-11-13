import Foundation

/// Calendar-day helpers working on "yyyy-MM-dd" keys in the device's local time zone.
enum DateKit {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c
    }()
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar; f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ d: Date = Date()) -> String { formatter.string(from: d) }
    static func date(_ key: String) -> Date { formatter.date(from: key) ?? calendar.startOfDay(for: Date()) }

    static func daysBetween(_ a: String, _ b: String) -> Int {
        calendar.dateComponents([.day], from: date(a), to: date(b)).day ?? 0
    }

    /// Days until the next occurrence (0 = today); nil if a one-off date has passed.
    static func daysUntil(_ a: Anniversary, today: String = key()) -> Int? {
        if !a.yearly { let n = daysBetween(today, a.date); return n >= 0 ? n : nil }
        return nextOccurrence(of: a.date, from: today).map { daysBetween(today, key($0)) }
    }

    static func nextOccurrence(of dateKey: String, from today: String = key()) -> Date? {
        let t = date(today)
        let md = calendar.dateComponents([.month, .day], from: date(dateKey))
        // Feb 29 falls back to the closest valid day via .nextTimePreservingSmallerComponents
        return calendar.nextDate(after: calendar.date(byAdding: .day, value: -1, to: t)!, matching: md,
                                 matchingPolicy: .nextTimePreservingSmallerComponents)
    }

    /// Next day-count milestone (第 100/200/520/1314… 天). Same rule as the web app.
    static func nextMilestone(_ together: Int) -> (day: Int, left: Int) {
        let special = [520, 1314, 3344, 5200].filter { $0 > together }
        let day = min((together / 100 + 1) * 100, special.min() ?? .max)
        return (day, day - together)
    }

    static func shortDate(_ key: String) -> String { key.replacingOccurrences(of: "-", with: ".") }
}
