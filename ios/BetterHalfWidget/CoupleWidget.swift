import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration: pick what the widget shows

struct CoupleDisplayEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "显示内容"
    static var defaultQuery = CoupleDisplayQuery()

    static let together = CoupleDisplayEntity(id: "together", title: "在一起天数")
    static let milestone = CoupleDisplayEntity(id: "milestone", title: "下一个里程碑（第 N 天）")

    var id: String
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct CoupleDisplayQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CoupleDisplayEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CoupleDisplayEntity] {
        var out: [CoupleDisplayEntity] = [.together, .milestone]
        if let s = SharedContainer.load() {
            out.append(CoupleDisplayEntity(id: "_start", title: "倒数：在一起纪念日"))
            out += s.anniversaries.map { CoupleDisplayEntity(id: $0.id, title: "倒数：\($0.name)") }
        }
        return out
    }

    func defaultResult() async -> CoupleDisplayEntity? { .together }
}

struct CoupleWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "我们的天数"
    static var description = IntentDescription("选择在桌面或锁屏显示在一起的天数、里程碑或某个纪念日倒数。")

    @Parameter(title: "显示内容")
    var display: CoupleDisplayEntity?
}

// MARK: - Timeline

struct CoupleEntry: TimelineEntry {
    let date: Date
    let content: CoupleContent?
}

struct CoupleContent {
    var names: String
    var label: String
    var number: Int
    var unit: String
    var footnote: String
    var isToday = false
    var upcoming: [(name: String, left: Int)] = []
}

struct CoupleProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CoupleEntry {
        CoupleEntry(date: .now, content: CoupleContent(names: "我 ♥ TA", label: "我们已经在一起", number: 520, unit: "天", footnote: "since 2025.01.01"))
    }

    func snapshot(for configuration: CoupleWidgetIntent, in context: Context) async -> CoupleEntry {
        CoupleEntry(date: .now, content: Self.content(for: configuration.display, on: .now) ?? placeholder(in: context).content)
    }

    func timeline(for configuration: CoupleWidgetIntent, in context: Context) async -> Timeline<CoupleEntry> {
        // One entry per day so the count ticks over at midnight.
        let start = DateKit.calendar.startOfDay(for: .now)
        let entries = (0..<7).map { i -> CoupleEntry in
            let day = i == 0 ? Date.now : DateKit.calendar.date(byAdding: .day, value: i, to: start)!
            return CoupleEntry(date: day, content: Self.content(for: configuration.display, on: day))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    static func content(for display: CoupleDisplayEntity?, on date: Date) -> CoupleContent? {
        guard let s = SharedContainer.load() else { return nil }
        let today = DateKit.key(date)
        let names = "\(s.me) ♥ \(s.partner)"
        let together = DateKit.daysBetween(s.startDate, today) + 1
        let all = s.anniversaries + [Anniversary(id: "_start", name: "在一起纪念日", date: s.startDate, yearly: true)]
        let upcoming = all.compactMap { a in DateKit.daysUntil(a, today: today).map { (a.name, $0) } }
            .sorted { $0.1 < $1.1 }.prefix(3).map { (name: $0.0, left: $0.1) }

        switch display?.id ?? "together" {
        case "together":
            return CoupleContent(names: names, label: "我们已经在一起", number: together, unit: "天",
                                 footnote: "since \(DateKit.shortDate(s.startDate))", upcoming: upcoming)
        case "milestone":
            let ms = DateKit.nextMilestone(together)
            return CoupleContent(names: names, label: "距离第 \(ms.day) 天", number: ms.left, unit: "天",
                                 footnote: "今天是第 \(together) 天", upcoming: upcoming)
        default:
            guard let a = all.first(where: { $0.id == display?.id }), let left = DateKit.daysUntil(a, today: today) else {
                return CoupleContent(names: names, label: "纪念日已删除", number: together, unit: "天",
                                     footnote: "长按小组件重新选择", upcoming: upcoming)
            }
            return CoupleContent(names: names, label: left == 0 ? "今天是" : "距离\(a.name)", number: left, unit: "天",
                                 footnote: a.date + (a.yearly ? " · 每年" : ""), isToday: left == 0, upcoming: upcoming)
        }
    }
}

// MARK: - Views

struct CoupleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CoupleEntry

    var body: some View {
        if let c = entry.content {
            switch family {
            case .accessoryCircular: circular(c)
            case .accessoryRectangular: rectangular(c)
            case .accessoryInline: Text("♥ \(c.label) \(c.number) \(c.unit)")
            case .systemMedium: medium(c)
            default: small(c)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "heart.fill").font(.title)
                Text("打开 BetterHalf\n开启你们的空间").font(.caption).multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
        }
    }

    private func bigNumber(_ c: CoupleContent, size: CGFloat) -> some View {
        Group {
            if c.isToday {
                Text("🎉").font(.system(size: size * 0.8))
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(c.number)").font(.system(size: size, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText())
                    Text(c.unit).font(.system(size: size * 0.3, weight: .semibold))
                }
            }
        }
    }

    private func small(_ c: CoupleContent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(c.names).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text(c.isToday ? "\(c.label)纪念日" : c.label).font(.caption2).opacity(0.9).lineLimit(1)
            bigNumber(c, size: 46)
            Text(c.footnote).font(.system(size: 10)).opacity(0.75).lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ c: CoupleContent) -> some View {
        HStack(spacing: 14) {
            small(c)
            VStack(alignment: .leading, spacing: 6) {
                Text("纪念日倒数").font(.caption.weight(.semibold)).opacity(0.9)
                ForEach(Array(c.upcoming.enumerated()), id: \.offset) { _, u in
                    HStack {
                        Text(u.name).font(.caption).lineLimit(1)
                        Spacer()
                        Text(u.left == 0 ? "今天" : "\(u.left) 天").font(.caption.bold()).monospacedDigit()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
    }

    private func circular(_ c: CoupleContent) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Image(systemName: "heart.fill").font(.system(size: 10))
                Text("\(c.number)").font(.system(size: 20, weight: .bold, design: .rounded)).minimumScaleFactor(0.5)
                Text(c.unit).font(.system(size: 9))
            }
        }
        .widgetAccentable()
    }

    private func rectangular(_ c: CoupleContent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("♥ \(c.names)").font(.caption2).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(c.label).font(.caption).lineLimit(1)
                Text("\(c.number)").font(.title3.bold()).widgetAccentable()
                Text(c.unit).font(.caption)
            }
            Text(c.footnote).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CoupleWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CoupleWidget", intent: CoupleWidgetIntent.self, provider: CoupleProvider()) { entry in
            CoupleWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.gradient }
        }
        .configurationDisplayName("我们的天数")
        .description("在一起天数、里程碑或纪念日倒数，长按小组件可选择显示内容。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
