import Foundation

/// Offline "小脑袋": a small rule-based personality used when no AI is configured (or AI fails).
enum PetBrain {
    static func reply(to text: String, pet: Pet, me: String, partner: String, turn: Int) -> String {
        let t = text.lowercased()
        let mood = pet.mood()
        let p = pet.personality ?? ""
        func pick(_ options: [String]) -> String { options[abs(turn) % options.count] }

        if mood == .sleeping {
            return pick(["Zzz…（\(pet.name)翻了个身，嘟囔着说梦话）", "呼…呼…（睡得正香，明天再聊嘛）", "唔…\(me)…晚安…Zzz"])
        }
        if t.containsAny(["饿", "吃", "饭", "零食", "喂", "food"]) {
            return pet.fullness() < 0.5
                ? pick(["肚子咕咕叫了！快点「喂食」嘛 🍖", "饿饿…想吃小鱼干…", "你终于想起我还没吃饭啦 🥺"])
                : pick(["刚吃饱～再吃要变成小胖子啦 😋", "我现在饱饱的，摸摸肚子嘛～", "下一顿想吃好吃的！"])
        }
        if t.containsAny(["爱", "喜欢", "想你", "亲", "抱", "love"]) {
            return pick(["我也最喜欢你啦！❤️", "蹭蹭你～今天也要抱抱 🫶", "\(me)和\(partner)都是我最爱的人！"])
        }
        if t.containsAny(["晚安", "睡觉", "困"]) {
            return pick(["晚安～做个好梦 🌙", "要早点睡哦，\(partner)也是！", "我也困了…一起睡吧 💤"])
        }
        if t.containsAny(["早", "起床", "早安"]) {
            return pick(["早呀！今天也要元气满满 ☀️", "早安～先摸摸我再去刷牙！", "伸个懒腰…早上好呀"])
        }
        if t.containsAny(["累", "难过", "伤心", "烦", "哭", "不开心", "压力"]) {
            return pick(["抱抱你 🫂 我会一直陪着你", "不开心的话就摸摸我吧，摸摸会变好的", "要不要去找\(me == partner ? "TA" : partner)聊聊？我陪你一起"])
        }
        if t.containsAny(["玩", "出去", "散步"]) {
            return pick(["好耶！快点「玩耍」陪我玩 🎾", "去哪里玩？带上我带上我！", "我准备好啦，冲鸭！"])
        }
        if t.containsAny(["你是谁", "名字", "叫什么"]) {
            return "我是\(pet.name)呀，\(me)和\(partner)的\(pet.speciesName)！"
        }

        if p.contains("高冷") { return pick(["哼，勉强陪你聊一会儿。", "嗯。（尾巴悄悄摇了一下）", "知道了知道了…"]) }
        if p.contains("傲娇") { return pick(["才、才不是想你了呢！", "哼～那我就听你说说吧", "你今天来晚了！…不过算了"]) }
        if p.contains("吃货") { return pick(["说到这个…你有带零食吗？", "嗯嗯！聊完可以吃东西吗 😋", "我觉得这件事和吃饭一样重要！"]) }
        if p.contains("粘人") { return pick(["多陪我一会儿嘛～", "不要走不要走，再聊五分钟！", "你一来我就开心！"]) }

        switch mood {
        case .hungry: return pick(["先喂我嘛…饿得没力气聊天了 🍽️", "咕噜…（肚子在抗议）"])
        case .lonely: return pick(["你终于来找我啦 🥺 好想你", "好久没人理我了…多陪陪我嘛"])
        default: return pick(["真的吗？再多说一点！", "嘿嘿，我在认真听哦 👂", "今天\(partner)有没有来看我？", "和你聊天最开心了 ✨", "嗯嗯！然后呢？"])
        }
    }

    /// System prompt for an AI provider, describing who the pet is and how it feels right now.
    static func systemPrompt(pet: Pet, me: String, partner: String) -> String {
        let mood = pet.mood()
        return """
        你是「\(pet.name)」，一只\(pet.speciesName)，是情侣\(me)和\(partner)一起养的宠物。现在和你聊天的是\(me)。
        性格：\(pet.personality?.isEmpty == false ? pet.personality! : "可爱、亲人")。
        当前状态：\(mood.label)，饱腹 \(Int(pet.fullness() * 100))%，心情 \(Int(pet.happiness() * 100))%，亲密度 Lv.\(pet.level)。
        规则：用宠物的口吻说中文，简短可爱（1～3 句），可以偶尔带一个 emoji；饿了或想念时可以撒娇；\
        不要说自己是 AI、模型或程序；不要给出医疗、法律、金钱方面的专业建议；如果对方情绪低落，温柔地安慰并鼓励TA和\(partner)聊聊。
        """
    }

    static func imagePrompt(pet: Pet, appearance: String, style: PetArtStyle) -> String {
        let animal = Pet.speciesEnglish[pet.species] ?? "pet"
        return "A cute \(style.prompt) of a \(animal) pet, \(appearance), full body, centered, facing slightly to the side, single character, plain pure white background, no text, no watermark"
    }
}

enum PetArtStyle: String, CaseIterable, Identifiable {
    case sticker = "卡通贴纸", clay = "3D 手办", pixel = "像素风", watercolor = "水彩", anime = "日系插画"
    var id: String { rawValue }
    var prompt: String {
        switch self {
        case .sticker: return "kawaii cartoon sticker illustration with thick outline"
        case .clay: return "3D clay figurine render, soft lighting"
        case .pixel: return "pixel art sprite"
        case .watercolor: return "soft watercolor illustration"
        case .anime: return "anime style illustration"
        }
    }
}

private extension String {
    func containsAny(_ words: [String]) -> Bool { words.contains { contains($0) } }
}
