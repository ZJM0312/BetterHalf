import Foundation
import UserNotifications

/// Local notifications: anniversary reminders (day before + on the day) and a nightly daily-question nudge.
enum Reminders {
    static let enabledKey = "remindersEnabled"
    private static let prefix = "bh."

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static func requestAndEnable(for state: SpaceState?) async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        UserDefaults.standard.set(granted, forKey: enabledKey)
        if granted, let state { reschedule(for: state) }
        return granted
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        cancelAll()
    }

    static func cancelAll() {
        let c = UNUserNotificationCenter.current()
        c.getPendingNotificationRequests { reqs in
            c.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix(prefix) })
        }
    }

    static func reschedule(for s: SpaceState) {
        guard isEnabled else { return }
        let c = UNUserNotificationCenter.current()
        c.getPendingNotificationRequests { reqs in
            c.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix(prefix) })

            var events = s.anniversaries
            events.append(Anniversary(id: "start", name: "在一起纪念日", date: s.startDate, yearly: true))
            for a in events {
                guard let next = a.yearly ? DateKit.nextOccurrence(of: a.date) : DateKit.date(a.date) else { continue }
                add(c, id: "\(prefix)\(a.id).eve", at: DateKit.calendar.date(byAdding: .day, value: -1, to: next)!, hour: 20,
                    title: "明天是「\(a.name)」", body: "别忘了给 \(s.partner) 准备一点小惊喜 💝")
                add(c, id: "\(prefix)\(a.id).day", at: next, hour: 9,
                    title: "今天是「\(a.name)」🎉", body: "\(s.me) ♥ \(s.partner)，节日快乐！")
            }
            // Day-count milestone (第 N 天)
            let days = DateKit.daysBetween(s.startDate, DateKit.key()) + 1
            let ms = DateKit.nextMilestone(days)
            if let d = DateKit.calendar.date(byAdding: .day, value: ms.left, to: DateKit.date(DateKit.key())) {
                add(c, id: "\(prefix)milestone", at: d, hour: 9,
                    title: "我们在一起第 \(ms.day) 天啦 ✨", body: "打开 BetterHalf 生成一张纪念卡片吧")
            }
            // No memory recorded for 3 days → gentle nudge at 20:00.
            let latest = s.moments.map(\.date).max().map(DateKit.date) ?? DateKit.date(s.startDate)
            let due = DateKit.calendar.date(byAdding: .day, value: 3, to: latest)!
            let fireDay = max(due, DateKit.calendar.date(byAdding: .day, value: 1, to: DateKit.calendar.startOfDay(for: Date()))!)
            add(c, id: "\(prefix)memory", at: fireDay, hour: 20,
                title: "好几天没有记录回忆啦 📸", body: "最近和 \(s.partner) 有什么值得留念的瞬间吗？")
            // Pets get hungry 8h after their last meal (skip the middle of the night).
            for pet in s.petList {
                let hungry = Date(timeIntervalSince1970: pet.lastFed + Pet.hungerHours * 3600)
                let hour = DateKit.calendar.component(.hour, from: hungry)
                guard hungry > Date(), (8..<22).contains(hour) else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(pet.species) \(pet.name)饿了"
                content.body = "快去喂喂 TA 吧，桌面小组件上也能直接喂食"
                content.sound = .default
                c.add(UNNotificationRequest(identifier: "\(prefix)pet.\(pet.id)", content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: hungry.timeIntervalSinceNow, repeats: false)))
            }
            // Daily question nudge, 21:00 every day
            let content = UNMutableNotificationContent()
            content.title = "今日一问已更新 💬"; content.body = "和 \(s.partner) 聊聊今天的问题吧"
            c.add(UNNotificationRequest(identifier: "\(prefix)daily", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 21), repeats: true)))
        }
    }

    private static func add(_ c: UNUserNotificationCenter, id: String, at day: Date, hour: Int, title: String, body: String) {
        var comps = DateKit.calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        guard let fire = DateKit.calendar.date(from: comps), fire > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        c.add(UNNotificationRequest(identifier: id, content: content,
                                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
}
