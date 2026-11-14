import Foundation
import UserNotifications

/// Turns what the partner did (found while merging synced data) into notifications.
/// When the app is open they show as a banner (see AppDelegate's notification delegate).
enum PartnerNotifier {
    static func post(_ events: [SyncEvent], state: SpaceState) {
        let who = state.partner
        for e in events.prefix(4) {
            let c = UNMutableNotificationContent()
            c.sound = .default
            var tab = AppTab.home
            switch e.kind {
            case let .partnerAnswered(day, bothDone):
                tab = .talk
                let today = day == DateKit.key()
                if bothDone {
                    c.title = "🎁 宝箱可以开啦"
                    c.body = "\(who) 也回答了\(today ? "今日一问" : "那天的问题")，快来看看 TA 写了什么"
                } else {
                    c.title = "\(who) 回答了\(today ? "今日一问" : "一道问题") 💬"
                    c.body = "TA 的答案藏在宝箱里，你答完就能一起打开"
                }
            case let .newMoment(text):
                tab = .memories
                c.title = "\(who) 记录了新回忆 📸"
                c.body = String(text.prefix(60))
            case let .momentNote(text):
                tab = .memories
                c.title = "\(who) 在回忆里补充了一句"
                c.body = String(text.prefix(60))
            case let .petNote(pet, text):
                tab = .pet
                c.title = "\(pet) 带来了 \(who) 的话 🐾"
                c.body = String(text.prefix(80))
            case let .bucketDone(text):
                tab = .play
                c.title = "清单完成一项 ✅"
                c.body = "\(who) 打勾了「\(text)」"
            case let .poke(kind):
                switch kind {
                case .answer:
                    tab = .talk
                    c.title = "\(who) 在等你回答今日一问"
                    c.body = "答完就能一起开宝箱 🎁"
                case .miss:
                    c.title = "\(who) 想你了 💕"
                    c.body = "点开看看 TA"
                }
            }
            c.userInfo = ["tab": tab.rawValue]
            c.threadIdentifier = "partner"
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "partner.\(UUID().uuidString)", content: c, trigger: nil))
        }
    }
}
