import Foundation

enum PetAction: String, CaseIterable {
    case feed, pet, play
    var emoji: String { switch self { case .feed: "🍖"; case .pet: "🤚"; case .play: "🎾" } }
    var title: String { switch self { case .feed: "喂食"; case .pet: "摸摸"; case .play: "玩耍" } }
    var reaction: String { switch self { case .feed: "好吃！😋"; case .pet: "好舒服～❤️"; case .play: "再来一次！✨" } }
}

enum PetMood {
    case happy, hungry, lonely, sleeping

    var emoji: String { switch self { case .happy: "😊"; case .hungry: "🍽️"; case .lonely: "🥺"; case .sleeping: "💤" } }
    var label: String { switch self { case .happy: "开心"; case .hungry: "饿了"; case .lonely: "想你们了"; case .sleeping: "睡着了" } }

    /// Stable within the hour so the bubble doesn't change on every redraw.
    func line(pet: String, me: String, partner: String, at now: Date = Date()) -> String {
        switch self {
        case .happy:
            let lines = ["最喜欢\(me)和\(partner)了！", "今天也要一起玩哦～", "\(pet)今天心情超好！"]
            return lines[Calendar.current.component(.hour, from: now) % lines.count]
        case .hungry: return "肚子咕咕叫了…给\(pet)一点吃的吧"
        case .lonely: return "好久没人摸摸我了 🥺"
        case .sleeping: return "Zzz… 嘘，\(pet)在做梦"
        }
    }
}

extension Pet {
    static let speciesNames: [String: String] = [
        "🐱": "猫咪", "🐶": "狗狗", "🐰": "兔兔", "🐹": "仓鼠", "🐦": "小鸟", "🐢": "乌龟", "🐟": "小鱼", "🦊": "狐狸",
    ]
    static let speciesEnglish: [String: String] = [
        "🐱": "cat", "🐶": "dog", "🐰": "rabbit", "🐹": "hamster", "🐦": "bird", "🐢": "turtle", "🐟": "fish", "🦊": "fox",
    ]
    var speciesName: String { Pet.speciesNames[species] ?? "小宠物" }

    static let hungerHours = 8.0
    static let lonelyHours = 6.0

    /// 1 = just fed, 0 = starving.
    func fullness(at now: Date = Date()) -> Double {
        max(0, min(1, 1 - (now.timeIntervalSince1970 - lastFed) / (Pet.hungerHours * 3600)))
    }
    func happiness(at now: Date = Date()) -> Double {
        max(0, min(1, 1 - (now.timeIntervalSince1970 - lastPetted) / (Pet.lonelyHours * 3600)))
    }
    var level: Int { affection / 10 + 1 }
    var levelProgress: Double { Double(affection % 10) / 10 }

    func mood(at now: Date = Date()) -> PetMood {
        let hour = Calendar.current.component(.hour, from: now)
        if hour >= 23 || hour < 7 { return .sleeping }
        if fullness(at: now) < 0.3 { return .hungry }
        if happiness(at: now) < 0.3 { return .lonely }
        return .happy
    }

    /// Reaction bubble shown for a short while after an interaction.
    func recentReaction(at now: Date = Date(), within seconds: Double = 90) -> String? {
        guard let a = lastAction.flatMap(PetAction.init(rawValue:)), let t = lastActionAt,
              now.timeIntervalSince1970 - t < seconds else { return nil }
        return a.reaction
    }

    mutating func apply(_ action: PetAction, by name: String? = nil, at now: Date = Date()) {
        let t = now.timeIntervalSince1970
        if let name {
            lastActionBy = name
            log = Array(([PetLogEntry(action: action.rawValue, by: name, at: t)] + (log ?? [])).prefix(40))
            let day = DateKit.key(now)
            if !(careDays ?? []).contains(day) { careDays = Array(((careDays ?? []) + [day]).suffix(120)) }
        }
        // Affection grows at most once per 30s so tapping can't farm levels.
        if t - (lastActionAt ?? 0) > 30 { affection += action == .play ? 2 : 1 }
        switch action {
        case .feed: lastFed = t
        case .pet: lastPetted = t
        case .play:
            lastPetted = t
            lastFed = min(lastFed, t) - 1800 // playing makes them a bit hungry
        }
        lastAction = action.rawValue
        lastActionAt = t
    }
}

// MARK: - Shared care, wishes, accessories

/// A small daily goal that needs both partners — the pet nudges you to care for it together.
struct PetWish {
    let text: String
    let isDone: (_ today: [PetLogEntry], _ me: String, _ partner: String) -> Bool
}

extension Pet {
    static let levelTitles = ["初次见面", "熟悉起来", "好朋友", "形影不离", "家人", "心有灵犀", "灵魂伴侣"]
    var levelTitle: String { Pet.levelTitles[min(level - 1, Pet.levelTitles.count - 1)] }

    /// Accessories unlock with the affection level.
    static let accessories: [(emoji: String, name: String, level: Int)] = [
        ("🎀", "蝴蝶结", 1), ("🌸", "小花", 2), ("🎩", "小礼帽", 3), ("🕶️", "墨镜", 4),
        ("🧣", "围巾", 5), ("👑", "小皇冠", 6), ("😇", "光环", 8),
    ]

    func todayLog(_ now: Date = Date()) -> [PetLogEntry] {
        let start = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        return (log ?? []).filter { $0.at >= start }
    }

    /// Consecutive days (ending today, or yesterday if nobody has come by yet today) with any care.
    func careStreak(_ now: Date = Date()) -> Int {
        let days = Set(careDays ?? [])
        var d = now
        if !days.contains(DateKit.key(d)) { d = DateKit.calendar.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while days.contains(DateKit.key(d)) {
            n += 1
            d = DateKit.calendar.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }

    static let wishes: [PetWish] = [
        PetWish(text: "今天想让你们两个人都摸摸我") { log, me, p in
            log.contains { $0.by == me && $0.action == "pet" } && log.contains { $0.by == p && $0.action == "pet" }
        },
        PetWish(text: "今天想吃到你们两个人喂的饭") { log, me, p in
            log.contains { $0.by == me && $0.action == "feed" } && log.contains { $0.by == p && $0.action == "feed" }
        },
        PetWish(text: "今天想和你们一起玩 3 次") { log, _, _ in log.filter { $0.action == "play" }.count >= 3 },
        PetWish(text: "今天你们俩都来看看我就好") { log, me, p in
            log.contains { $0.by == me } && log.contains { $0.by == p }
        },
    ]

    /// Today's wish, stable for the day and different per pet.
    func wish(_ now: Date = Date()) -> PetWish {
        let day = DateKit.calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let salt = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Pet.wishes[(day + salt) % Pet.wishes.count]
    }

    func wishClaimedToday(_ now: Date = Date()) -> Bool { (wishClaimed ?? []).contains(DateKit.key(now)) }

    /// The partner's message, shown for a day.
    func noteFor(me: String, at now: Date = Date()) -> PetNote? {
        guard let n = note, n.from != me, now.timeIntervalSince1970 - n.at < 24 * 3600 else { return nil }
        return n
    }

    /// "小红 刚刚喂过我" — so the other partner knows (and doesn't double-feed).
    func recentCareLine(me: String, at now: Date = Date()) -> String? {
        guard let by = lastActionBy, by != me, let t = lastActionAt, let a = lastAction.flatMap(PetAction.init(rawValue:)),
              now.timeIntervalSince1970 - t < 2 * 3600 else { return nil }
        switch a {
        case .feed: return "\(by) 刚刚喂过我啦，肚子饱饱的～"
        case .pet: return "\(by) 刚刚摸过我，好开心"
        case .play: return "刚和 \(by) 玩得好累呀"
        }
    }

    /// When one partner hasn't come by for 2 days, the pet says it misses them.
    func missingLine(me: String, partner: String, at now: Date = Date()) -> String? {
        guard (log ?? []).count >= 3 else { return nil }
        let cutoff = now.timeIntervalSince1970 - 2 * 86400
        let recent = (log ?? []).filter { $0.at >= cutoff }
        if !recent.contains(where: { $0.by == partner }) && recent.contains(where: { $0.by == me }) {
            return "好想 \(partner) 呀，TA 好久没来看我了"
        }
        return nil
    }

    /// What the pet says right now, most specific first.
    func speech(me: String, partner: String, at now: Date = Date()) -> String {
        if let r = recentReaction(at: now) { return r }
        let mood = mood(at: now)
        // A message from the partner matters more than anything — even half asleep.
        if let n = noteFor(me: me, at: now) { return "\(mood == .sleeping ? "（迷迷糊糊）" : "")\(n.from) 让我告诉你：\(n.text)" }
        if mood == .sleeping { return mood.line(pet: name, me: me, partner: partner, at: now) }
        if let c = recentCareLine(me: me, at: now) { return c }
        if mood == .happy, let m = missingLine(me: me, partner: partner, at: now) { return m }
        return mood.line(pet: name, me: me, partner: partner, at: now)
    }
}

extension SpaceState {
    /// `by` = who did it (this phone's owner); widget and app both pass `me`.
    mutating func applyPet(_ action: PetAction, id: String) {
        guard var list = pets, let i = list.firstIndex(where: { $0.id == id }) else { return }
        list[i].apply(action, by: me)
        pets = list
    }
}
