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

    mutating func apply(_ action: PetAction, at now: Date = Date()) {
        let t = now.timeIntervalSince1970
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

extension SpaceState {
    mutating func applyPet(_ action: PetAction, id: String) {
        guard var list = pets, let i = list.firstIndex(where: { $0.id == id }) else { return }
        list[i].apply(action)
        pets = list
    }
}
