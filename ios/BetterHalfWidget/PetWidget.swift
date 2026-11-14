import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration

struct PetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "宠物"
    static var defaultQuery = PetQuery()
    var id: String
    var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct PetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PetEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [PetEntity] {
        (SharedContainer.load()?.petList ?? []).map { PetEntity(id: $0.id, title: "\($0.species) \($0.name)") }
    }
    func defaultResult() async -> PetEntity? { try? await suggestedEntities().first }
}

struct PetWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "我们的宠物"
    static var description = IntentDescription("选择要放在桌面或锁屏上的宠物。")
    @Parameter(title: "宠物") var pet: PetEntity?
}

// MARK: - Timeline

struct PetEntry: TimelineEntry {
    let date: Date
    let pet: Pet?
    let image: UIImage?
    let pose: Int // alternates between entries so the pet visibly moves
    var me = ""
    var partner = ""
}

struct PetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, pet: Pet(name: "咪咪", species: "🐱"), image: nil, pose: 0)
    }

    func snapshot(for configuration: PetWidgetIntent, in context: Context) async -> PetEntry {
        entries(for: configuration, count: 1).first ?? placeholder(in: context)
    }

    func timeline(for configuration: PetWidgetIntent, in context: Context) async -> Timeline<PetEntry> {
        Timeline(entries: entries(for: configuration, count: 16), policy: .atEnd)
    }

    /// Every 15 min for 4 hours: hunger and mood decay, sleep at night, pose changes.
    private func entries(for config: PetWidgetIntent, count: Int) -> [PetEntry] {
        guard let s = SharedContainer.load() else { return [PetEntry(date: .now, pet: nil, image: nil, pose: 0)] }
        let pets = s.petList
        guard let pet = pets.first(where: { $0.id == config.pet?.id }) ?? pets.first else {
            return [PetEntry(date: .now, pet: nil, image: nil, pose: 0)]
        }
        let image = pet.imageFile.flatMap { Self.loadImage(SharedContainer.mediaURL($0)) }
        var dates: [Date] = [.now]
        // If a reaction bubble is showing, add an entry right when it should disappear.
        if let t = pet.lastActionAt, Date.now.timeIntervalSince1970 - t < 90 {
            dates.append(Date(timeIntervalSince1970: t + 90))
        }
        while dates.count < count { dates.append(dates.last!.addingTimeInterval(15 * 60)) }
        return dates.enumerated().map { i, d in
            PetEntry(date: d, pet: pet, image: image, pose: i % 3, me: s.me, partner: s.partner)
        }
    }

    /// Widgets have a tight memory budget; downsample the sticker.
    static func loadImage(_ url: URL) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                     kCGImageSourceCreateThumbnailWithTransform: true,
                                     kCGImageSourceThumbnailMaxPixelSize: 360]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary).map { UIImage(cgImage: $0) }
    }
}

// MARK: - Views

struct PetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PetEntry

    var body: some View {
        if let pet = entry.pet {
            switch family {
            case .accessoryCircular: circular(pet)
            case .accessoryRectangular: rectangular(pet)
            case .systemMedium: medium(pet)
            case .systemLarge: large(pet)
            default: small(pet)
            }
        } else {
            VStack(spacing: 6) {
                Text("🐾").font(.largeTitle)
                Text("在 App 里添加\n你们的宠物").font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
        }
    }

    private var poseOffset: CGFloat { [0, -6, -2][entry.pose] }
    private var poseTilt: Double { [0, -5, 5][entry.pose] }

    private func sprite(_ pet: Pet, size: CGFloat) -> some View {
        let mood = pet.mood(at: entry.date)
        return ZStack(alignment: .topTrailing) {
            Group {
                if let img = entry.image {
                    Image(uiImage: img).resizable().scaledToFit()
                } else {
                    Text(pet.species).font(.system(size: size * 0.7))
                }
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(mood == .sleeping ? -6 : poseTilt), anchor: .bottom)
            .offset(y: mood == .sleeping ? 0 : poseOffset)
            .saturation(mood == .sleeping ? 0.6 : 1)
            Text(mood.emoji).font(.system(size: size * 0.22)).offset(x: 6, y: -4)
        }
        .overlay(alignment: .top) {
            if let a = pet.accessory { Text(a).font(.system(size: size * 0.3)).offset(y: (mood == .sleeping ? 0 : poseOffset) - size * 0.08) }
        }
        .transition(.push(from: .bottom))
        .id("\(entry.pose)-\(mood)")
    }

    private func bubble(_ pet: Pet) -> String {
        pet.recentReaction(at: entry.date) ?? (pet.noteFor(me: entry.me, at: entry.date) != nil ? "💌 有话带给你" : pet.mood(at: entry.date).label)
    }

    private func speech(_ pet: Pet) -> String { pet.speech(me: entry.me, partner: entry.partner, at: entry.date) }

    private func actionButton(_ pet: Pet, _ action: PetAction, compact: Bool) -> some View {
        Button(intent: PetActionIntent(petID: pet.id, action: action)) {
            Group {
                if compact { Text(action.emoji) } else { Label { Text(action.title) } icon: { Text(action.emoji) } }
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 5)
        .background(Theme.pink.opacity(0.15), in: Capsule())
    }

    private func small(_ pet: Pet) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(pet.name).font(.caption.bold()).lineLimit(1)
                Spacer()
                Text(bubble(pet)).font(.system(size: 10)).lineLimit(1)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.pinkSoft, in: Capsule())
                    .contentTransition(.opacity)
            }
            sprite(pet, size: 78).frame(maxHeight: .infinity)
            HStack(spacing: 6) {
                actionButton(pet, .feed, compact: true)
                actionButton(pet, .pet, compact: true)
            }
        }
    }

    private func medium(_ pet: Pet) -> some View {
        HStack(spacing: 12) {
            sprite(pet, size: 120)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(pet.species) \(pet.name)").font(.headline).lineLimit(1)
                    Text("Lv.\(pet.level)").font(.caption2.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.pink, in: Capsule())
                }
                Text(speech(pet))
                    .font(.caption).foregroundStyle(pet.noteFor(me: entry.me, at: entry.date) != nil ? Theme.pink : .secondary).lineLimit(2)
                bar("🍖", pet.fullness(at: entry.date), .orange)
                bar("💗", pet.happiness(at: entry.date), Theme.pink)
                HStack(spacing: 6) {
                    ForEach(PetAction.allCases, id: \.self) { actionButton(pet, $0, compact: false) }
                }
            }
        }
    }

    private func large(_ pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(pet.species) \(pet.name)").font(.headline).lineLimit(1)
                Text("Lv.\(pet.level) \(pet.levelTitle)").font(.caption2.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.pink, in: Capsule())
                Spacer()
                if pet.careStreak(entry.date) > 1 { Text("🔥\(pet.careStreak(entry.date))天").font(.caption.bold()).foregroundStyle(.orange) }
            }
            Text(speech(pet))
                .font(.subheadline)
                .lineLimit(2)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
            sprite(pet, size: 150).frame(maxWidth: .infinity, maxHeight: .infinity)
            bar("🍖", pet.fullness(at: entry.date), .orange)
            bar("💗", pet.happiness(at: entry.date), Theme.pink)
            Text("🌟 \(pet.wishClaimedToday(entry.date) ? "今天的心愿完成啦" : pet.wish(entry.date).text)")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack(spacing: 6) {
                ForEach(PetAction.allCases, id: \.self) { actionButton(pet, $0, compact: false) }
            }
        }
    }

    private func bar(_ icon: String, _ v: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(icon).font(.caption2)
            Gauge(value: v) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(color)
        }
    }

    private func circular(_ pet: Pet) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            if let img = entry.image {
                Image(uiImage: img).resizable().scaledToFit().padding(6).widgetAccentable()
            } else {
                Text(pet.species).font(.title)
            }
        }
    }

    private func rectangular(_ pet: Pet) -> some View {
        HStack(spacing: 6) {
            if let img = entry.image {
                Image(uiImage: img).resizable().scaledToFit().frame(width: 44, height: 44).widgetAccentable()
            } else {
                Text(pet.species).font(.title2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pet.name) · \(bubble(pet))").font(.caption.bold()).lineLimit(1)
                if let n = pet.noteFor(me: entry.me, at: entry.date) {
                    Text("\(n.from)：\(n.text)").font(.caption2).lineLimit(2)
                } else {
                    Gauge(value: pet.fullness(at: entry.date)) { Text("🍖") }.gaugeStyle(.accessoryLinearCapacity)
                }
            }
        }
    }
}

struct PetWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PetWidget", intent: PetWidgetIntent.self, provider: PetProvider()) { entry in
            PetWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Theme.pinkSoft, Theme.card], startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("我们的宠物")
        .description("会饿、会睡觉、会撒娇，还会替 TA 带话的小宠物。可以直接在桌面喂食、摸摸、玩耍。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}
