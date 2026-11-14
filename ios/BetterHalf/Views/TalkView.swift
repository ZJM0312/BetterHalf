import SwiftUI

/// Which answered days this person has already opened. Per phone (each partner opens their own chest).
enum ChestLedger {
    private static let key = "openedChests"

    static var opened: Set<String> { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
    static func isOpened(_ day: String) -> Bool { opened.contains(day) }
    static func markOpened(_ day: String) {
        var s = opened
        s.insert(day)
        UserDefaults.standard.set(Array(s), forKey: key)
    }

    /// First run after this feature shipped: don't greet people with a pile of old chests.
    static func migrateIfNeeded(_ state: SpaceState) {
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        let today = DateKit.key()
        UserDefaults.standard.set(state.answers.filter { $0.key != today && $0.value.bothAnswered }.map(\.key), forKey: key)
    }

    /// Both answered, not opened yet, newest first.
    static func unopened(_ s: SpaceState) -> [String] {
        let o = opened
        return s.answers.filter { $0.value.bothAnswered && !o.contains($0.key) }.map(\.key).sorted(by: >)
    }

    /// The partner answered in the last week but I haven't — I can still answer to unlock it.
    static func waitingForMe(_ s: SpaceState) -> [String] {
        let today = DateKit.key()
        return s.answers.filter { day, a in
            day != today && (a.me ?? "").isEmpty && !(a.partner ?? "").isEmpty && DateKit.daysBetween(day, today) <= 7
        }.map(\.key).sorted(by: >)
    }
}

struct TalkView: View {
    @Environment(SpaceStore.self) private var store
    @Environment(SyncService.self) private var sync
    @Environment(CloudSync.self) private var cloud
    @State private var who: Author = .me
    @State private var draft = ""
    @State private var openedVersion = 0 // bumps when a chest is opened, to refresh lists
    @State private var sheetDay: SheetDay?
    @FocusState private var focused: Bool

    /// With sync each phone answers only for its owner; on one shared phone the two take turns.
    private var paired: Bool { sync.isPaired || cloud.isActive }

    var body: some View {
        NavigationStack {
            if let s = store.state {
                let key = DateKit.key()
                let ans = s.answers[key] ?? Answer()
                let _ = openedVersion
                ScrollView {
                    VStack(spacing: 14) {
                        pendingBanner(s)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("今日一问 · \(key)")
                                if store.answerStreak > 0 { Text("· 🔥 连续 \(store.answerStreak) 天") }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            Text(Catalog.question(for: key)).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                            if ans.bothAnswered {
                                ChestReveal(day: key, state: s) { openedVersion += 1 }
                            } else if paired {
                                pairedAnswering(s, ans, key: key)
                            } else {
                                sharedPhoneAnswering(s, ans, key: key)
                            }
                        }
                        .card()
                        history(s, today: key)
                    }
                    .padding(16)
                }
                .screenBackground()
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("每日一问")
                .onAppear {
                    if !paired, ans[.me] != nil, ans[.partner] == nil { who = .partner }
                }
                .sheet(item: $sheetDay, onDismiss: { openedVersion += 1 }) { d in
                    PastQuestionSheet(day: d.id, paired: paired)
                }
            }
        }
    }

    // MARK: pending chests

    @ViewBuilder
    private func pendingBanner(_ s: SpaceState) -> some View {
        let today = DateKit.key()
        let chests = ChestLedger.unopened(s).filter { $0 != today }
        let mine = ChestLedger.waitingForMe(s)
        if !chests.isEmpty || !mine.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if !chests.isEmpty {
                    Text("🎁 你有 \(chests.count) 个宝箱还没打开").font(.subheadline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(chests, id: \.self) { d in
                                Button { sheetDay = SheetDay(id: d) } label: { chip(d, icon: "gift.fill") }
                            }
                        }
                    }
                }
                if !mine.isEmpty {
                    Text("✍️ \(s.partner) 答了 \(mine.count) 道你还没答的题，补答就能开宝箱").font(.subheadline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(mine, id: \.self) { d in
                                Button { sheetDay = SheetDay(id: d) } label: { chip(d, icon: "pencil") }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(Theme.pinkSoft)
        }
    }

    private func chip(_ day: String, icon: String) -> some View {
        Label(DateKit.friendly(day), systemImage: icon)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.card, in: Capsule())
            .foregroundStyle(Theme.pink)
    }

    // MARK: answering

    @ViewBuilder
    private func pairedAnswering(_ s: SpaceState, _ ans: Answer, key: String) -> some View {
        let partnerDone = !(ans.partner ?? "").isEmpty
        if (ans.me ?? "").isEmpty {
            Label(partnerDone ? "\(s.partner) 已经答好了，藏在宝箱里。你答完就能一起打开 🎁" : "\(s.partner) 还没回答。你先写，答案会先藏起来 🙈",
                  systemImage: partnerDone ? "gift.fill" : "hourglass")
                .font(.footnote).foregroundStyle(partnerDone ? Theme.pink : .secondary)
            answerField(placeholder: "写下你的回答…")
            Button(partnerDone ? "答好了，打开宝箱" : "答好了，藏进宝箱") { submit(key: key, as: .me) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else {
            VStack(spacing: 12) {
                TreasureChest(open: false, locked: true).frame(height: 130)
                Text("你的回答已经藏好啦").font(.subheadline.weight(.semibold))
                Text("\(s.partner) 回答后你会马上收到通知，到时一起开宝箱").font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                pokeButton(s)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func pokeButton(_ s: SpaceState) -> some View {
        let recent = s.poke.map { $0.from == s.me && $0.kind == .answer && Date().timeIntervalSince1970 - $0.at < 3600 } ?? false
        if cloud.isPaired {
            Button(recent ? "已提醒 TA ✓" : "戳一下 \(s.partner) 来回答") { store.sendPoke(.answer) }
                .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                .disabled(recent)
        } else if sync.isPaired {
            Text("你们在一起时打开「面对面同步」就能交换答案").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func sharedPhoneAnswering(_ s: SpaceState, _ ans: Answer, key: String) -> some View {
        HStack(spacing: 10) {
            status(s.me, done: ans.me != nil)
            status(s.partner, done: ans.partner != nil)
        }
        if ans[who] == nil {
            Text("轮到 \(Text(store.name(who)).bold()) 回答，对方先别偷看 🙈 两人都答完就能开宝箱。")
                .font(.footnote).foregroundStyle(.secondary)
            answerField(placeholder: "\(store.name(who)) 的回答…")
            Button("提交并藏起来") { submit(key: key, as: who) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else {
            let other = who.other
            HStack {
                Text("\(store.name(who)) 已回答，把手机递给 \(store.name(other)) 吧～").font(.footnote).foregroundStyle(.secondary)
                Button("切换") { who = other }.font(.footnote)
            }
        }
        Text("两个人各用自己的手机？在「设置 → 异地同步」连接后，各答各的，TA 答完会通知你。")
            .font(.caption2).foregroundStyle(.tertiary)
    }

    private func answerField(placeholder: String) -> some View {
        TextField(placeholder, text: $draft, axis: .vertical)
            .lineLimit(4...8).focused($focused)
            .padding(12)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func status(_ name: String, done: Bool) -> some View {
        Text("\(name) \(done ? "✓ 已回答" : "未回答")")
            .font(.footnote).foregroundStyle(done ? .green : .secondary)
            .frame(maxWidth: .infinity).padding(8)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: history

    @ViewBuilder
    private func history(_ s: SpaceState, today: String) -> some View {
        let past = s.answers.filter { $0.key != today && $0.value.bothAnswered }.sorted { $0.key > $1.key }.prefix(30)
        if !past.isEmpty {
            let opened = ChestLedger.opened
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(text: "我们聊过的")
                ForEach(Array(past), id: \.key) { k, a in
                    if opened.contains(k) {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(Text(s.me).bold())：\(a.me ?? "")")
                                Text("\(Text(s.partner).bold())：\(a.partner ?? "")")
                            }
                            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                        } label: { historyLabel(k) }
                        .tint(.secondary)
                        .padding(.vertical, 6)
                    } else {
                        Button { sheetDay = SheetDay(id: k) } label: {
                            HStack {
                                historyLabel(k)
                                Spacer()
                                Label("开宝箱", systemImage: "gift.fill").font(.caption.weight(.semibold)).foregroundStyle(Theme.pink)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                    }
                    Divider()
                }
            }
            .card()
        }
    }

    private func historyLabel(_ k: String) -> some View {
        VStack(alignment: .leading) {
            Text(k).font(.caption).foregroundStyle(.secondary)
            Text(Catalog.question(for: k)).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
        }
    }

    private func submit(key: String, as current: Author) {
        let t = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !t.isEmpty else { return }
        withAnimation(.spring) {
            store.update { s in
                var a = s.answers[key] ?? Answer()
                a[current] = t
                if current == .me { a.meAt = Date().timeIntervalSince1970 } else { a.partnerAt = Date().timeIntervalSince1970 }
                s.answers[key] = a
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        draft = ""; focused = false
        if !paired { who = current.other }
    }
}

private struct SheetDay: Identifiable { let id: String }

/// A past day: open its chest, or answer it late to unlock it.
private struct PastQuestionSheet: View {
    let day: String
    let paired: Bool
    @Environment(SpaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            if let s = store.state {
                let ans = s.answers[day] ?? Answer()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(DateKit.friendly(day)).font(.caption).foregroundStyle(.secondary)
                        Text(Catalog.question(for: day)).font(.title3.weight(.bold))
                        if ans.bothAnswered {
                            ChestReveal(day: day, state: s) {}
                        } else {
                            Text("\(s.partner) 已经答好了。写下你的回答，就能打开宝箱 🎁").font(.footnote).foregroundStyle(Theme.pink)
                            TextField("你的回答…", text: $draft, axis: .vertical)
                                .lineLimit(4...8)
                                .padding(12)
                                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Button("补答并打开宝箱") {
                                let t = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
                                guard !t.isEmpty else { return }
                                withAnimation(.spring) {
                                    store.update { s in
                                        var a = s.answers[day] ?? Answer()
                                        a.me = t
                                        a.meAt = Date().timeIntervalSince1970
                                        s.answers[day] = a
                                    }
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .card()
                    .padding(16)
                }
                .screenBackground()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            }
        }
        .presentationDetents([.large])
    }
}

/// Closed chest → tap → lid flies open with sparkles → both answers appear.
struct ChestReveal: View {
    let day: String
    let state: SpaceState
    var onOpened: () -> Void
    @State private var open = false
    @State private var showAnswers = false
    @State private var wiggle = false

    var body: some View {
        let ans = state.answers[day] ?? Answer()
        VStack(spacing: 12) {
            if !showAnswers {
                Button(action: reveal) {
                    VStack(spacing: 10) {
                        TreasureChest(open: open, locked: false)
                            .frame(height: 140)
                            .rotationEffect(.degrees(wiggle ? 3 : -3))
                            .animation(open ? .default : .easeInOut(duration: 0.12).repeatCount(5, autoreverses: true).delay(1.2)
                                .repeatForever(autoreverses: true), value: wiggle)
                        Text(open ? "✨" : "你们都答完啦！点开宝箱").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.pink)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开宝箱，查看两个人的回答")
            } else {
                bubble(state.me, ans.me ?? "", leading: true)
                bubble(state.partner, ans.partner ?? "", leading: false)
                Text(day == DateKit.key() ? "明天还有新问题哦 💌" : "💌").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if ChestLedger.isOpened(day) { showAnswers = true } else { wiggle = true }
        }
    }

    private func reveal() {
        guard !open else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { open = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            ChestLedger.markOpened(day)
            withAnimation(.spring) { showAnswers = true }
            onOpened()
        }
    }

    private func bubble(_ name: String, _ text: String, leading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(text)
        }
        .padding(12)
        .background(leading ? Theme.pinkSoft : Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
        .transition(.move(edge: leading ? .leading : .trailing).combined(with: .opacity))
    }
}

/// Hand-drawn treasure chest. `locked` shows a padlock (waiting for the partner).
struct TreasureChest: View {
    var open: Bool
    var locked: Bool

    private let gold = LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.4), Color(red: 0.95, green: 0.65, blue: 0.2)],
                                      startPoint: .top, endPoint: .bottom)

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width, geo.size.height * 1.3) * 0.8
            ZStack {
                // Glow + sparkles when open
                Circle()
                    .fill(RadialGradient(colors: [Color.yellow.opacity(0.55), .clear], center: .center, startRadius: 4, endRadius: w * 0.7))
                    .frame(width: w * 1.5, height: w * 1.5)
                    .scaleEffect(open ? 1 : 0.3)
                    .opacity(open ? 1 : 0)
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) / 12 * 2 * .pi
                    Text(i % 3 == 0 ? "💕" : "✨")
                        .font(.system(size: w * 0.11))
                        .offset(x: open ? cos(angle) * w * 0.75 : 0, y: open ? sin(angle) * w * 0.55 - w * 0.2 : 0)
                        .opacity(open ? 1 : 0)
                        .scaleEffect(open ? 1 : 0.2)
                }
                VStack(spacing: -2) {
                    // Lid
                    ZStack {
                        UnevenRoundedRectangle(topLeadingRadius: w * 0.22, topTrailingRadius: w * 0.22, style: .continuous)
                            .fill(Theme.gradient)
                        Rectangle().fill(gold).frame(width: w * 0.14)
                    }
                    .frame(width: w, height: w * 0.32)
                    .rotation3DEffect(.degrees(open ? -125 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.4)
                    .zIndex(1)
                    // Body
                    ZStack {
                        RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                            .fill(LinearGradient(colors: [Color(red: 0.93, green: 0.42, blue: 0.55), Color(red: 0.7, green: 0.3, blue: 0.62)],
                                                 startPoint: .top, endPoint: .bottom))
                        Rectangle().fill(gold).frame(width: w * 0.14)
                        Rectangle().fill(gold).frame(height: w * 0.05).offset(y: -w * 0.1)
                        Circle().fill(gold).frame(width: w * 0.2, height: w * 0.2)
                            .overlay(Image(systemName: locked ? "lock.fill" : "heart.fill")
                                .font(.system(size: w * 0.09, weight: .bold)).foregroundStyle(.white))
                            .offset(y: -w * 0.1)
                    }
                    .frame(width: w, height: w * 0.42)
                }
                .shadow(color: Theme.pink.opacity(0.25), radius: 10, y: 6)
                .saturation(locked ? 0.45 : 1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
