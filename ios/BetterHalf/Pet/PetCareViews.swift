import SwiftUI

/// Today's wish — a small goal both partners complete together, with a reward.
struct PetWishCard: View {
    let pet: Pet
    let me: String
    let partner: String
    let onClaim: () -> Void

    var body: some View {
        let wish = pet.wish()
        let today = pet.todayLog()
        let done = wish.isDone(today, me, partner)
        let claimed = pet.wishClaimedToday()
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: "🌟 \(pet.name)今天的心愿")
                Spacer()
                if pet.careStreak() > 1 {
                    Text("🔥 连续照顾 \(pet.careStreak()) 天").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }
            Text("「\(wish.text)」").font(.subheadline)
            HStack(spacing: 8) {
                who(me, cared: today.contains { $0.by == me })
                who(partner, cared: today.contains { $0.by == partner })
                Spacer()
                if claimed {
                    Label("已完成", systemImage: "checkmark.seal.fill").font(.footnote.weight(.semibold)).foregroundStyle(.green)
                } else if done {
                    Button("领取 +3 亲密度", action: onClaim).buttonStyle(PrimaryButtonStyle(fullWidth: false))
                } else {
                    Text("完成后亲密度 +3").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func who(_ name: String, cared: Bool) -> some View {
        Label(name, systemImage: cared ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(.medium))
            .foregroundStyle(cared ? Theme.pink : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Theme.bg, in: Capsule())
    }
}

/// "让宠物带句话": leave a message for the partner; it shows in their app, notification and widget.
struct PetNoteCard: View {
    let pet: Pet
    let me: String
    let partner: String
    let onSend: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "💌 让\(pet.name)带句话")
            if let n = pet.noteFor(me: me) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(n.from) 留给你的话 · \(Date(timeIntervalSince1970: n.at).formatted(.relative(presentation: .named)))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(n.text).font(.subheadline)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.pinkSoft, in: RoundedRectangle(cornerRadius: 12))
            } else if let n = pet.note, n.from == me, Date().timeIntervalSince1970 - n.at < 24 * 3600 {
                Text("已托\(pet.name)转告：「\(n.text)」").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                TextField("早点回家，给你留了好吃的…", text: $text)
                    .focused($focused)
                    .padding(10)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
                    .onSubmit(send)
                Button("带话", action: send)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("\(partner) 打开 App 或看桌面小组件时，\(pet.name)会替你说出来；连了异地同步还会推送通知。")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func send() {
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !t.isEmpty else { return }
        onSend(t)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        text = ""; focused = false
    }
}

/// Who cared for the pet today + a short care diary.
struct PetCareLogCard: View {
    let pet: Pet
    let me: String
    let partner: String

    var body: some View {
        let today = pet.todayLog()
        let entries = Array((pet.log ?? []).prefix(6))
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "📒 照顾日记")
                HStack(spacing: 12) {
                    count(me, today.filter { $0.by == me }.count)
                    count(partner, today.filter { $0.by == partner }.count)
                }
                ForEach(entries) { e in
                    HStack {
                        Text(PetAction(rawValue: e.action)?.emoji ?? "🐾")
                        Text("\(e.by) \(PetAction(rawValue: e.action)?.title ?? "陪伴")了\(pet.name)").font(.subheadline)
                        Spacer()
                        Text(Date(timeIntervalSince1970: e.at).formatted(.relative(presentation: .named)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func count(_ name: String, _ n: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.title3.bold()).foregroundStyle(Theme.pink)
            Text("\(name) 今天").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Accessories unlocked by level.
struct PetWardrobeCard: View {
    let pet: Pet
    let onPick: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "🎀 装扮")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    item(label: "无", emoji: "🚫", on: pet.accessory == nil, locked: false) { onPick(nil) }
                    ForEach(Pet.accessories, id: \.emoji) { a in
                        let locked = pet.level < a.level
                        item(label: locked ? "Lv.\(a.level)" : a.name, emoji: a.emoji, on: pet.accessory == a.emoji, locked: locked) {
                            if !locked { onPick(a.emoji) }
                        }
                    }
                }
            }
            Text("亲密度越高，解锁的装扮越多。桌面小组件上也会戴着哦。").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func item(label: String, emoji: String, on: Bool, locked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji).font(.title2).opacity(locked ? 0.3 : 1)
                    .overlay(alignment: .bottomTrailing) { if locked { Image(systemName: "lock.fill").font(.caption2) } }
                Text(label).font(.caption2)
            }
            .frame(width: 58, height: 62)
            .background(on ? Theme.pinkSoft : Theme.bg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Theme.pink : .clear, lineWidth: 2))
        }
        .foregroundStyle(.primary)
        .disabled(locked)
    }
}

/// Sky behind the pet that follows the real time of day.
struct PetStageBackground: View {
    var date = Date()
    var body: some View {
        let h = Calendar.current.component(.hour, from: date)
        let (colors, deco): ([Color], String) = switch h {
        case 5..<9: ([Color(red: 1, green: 0.85, blue: 0.75), Theme.card], "🌤️")
        case 9..<17: ([Color(red: 0.8, green: 0.92, blue: 1), Theme.card], "☀️")
        case 17..<20: ([Color(red: 1, green: 0.72, blue: 0.62), Color(red: 0.95, green: 0.78, blue: 0.9)], "🌇")
        default: ([Color(red: 0.2, green: 0.22, blue: 0.42), Color(red: 0.38, green: 0.32, blue: 0.55)], "🌙")
        }
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            Text(deco).font(.system(size: 30)).padding(16).opacity(0.9)
            if !(6..<20).contains(h) {
                ForEach(0..<8, id: \.self) { i in
                    Text("✦").font(.system(size: CGFloat(6 + i % 3 * 3))).foregroundStyle(.white.opacity(0.7))
                        .position(x: CGFloat(30 + i * 41 % 300), y: CGFloat(20 + i * 29 % 110))
                }
            }
            // ground
            VStack { Spacer(); Ellipse().fill(.white.opacity(0.35)).frame(height: 70).offset(y: 30) }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
