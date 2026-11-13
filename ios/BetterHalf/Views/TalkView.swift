import SwiftUI

struct TalkView: View {
    @Environment(SpaceStore.self) private var store
    @State private var who: Author = .me
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            if let s = store.state {
                let key = DateKit.key()
                let ans = s.answers[key] ?? Answer()
                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("今日一问 · \(key)")
                                if store.answerStreak > 0 { Text("· 🔥 连续 \(store.answerStreak) 天") }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            Text(Catalog.question(for: key)).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                            if ans.bothAnswered { reveal(s, ans) } else { answering(s, ans, key: key) }
                        }
                        .card()
                        history(s, today: key)
                    }
                    .padding(16)
                }
                .screenBackground()
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("每日一问")
                .onAppear { if ans[.me] != nil && ans[.partner] == nil { who = .partner } }
            }
        }
    }

    private func reveal(_ s: SpaceState, _ ans: Answer) -> some View {
        VStack(spacing: 10) {
            bubble(s.me, ans.me ?? "", leading: true)
            bubble(s.partner, ans.partner ?? "", leading: false)
            Text("明天还有新问题哦 💌").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func bubble(_ name: String, _ text: String, leading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(text)
        }
        .padding(12)
        .background(leading ? Theme.pinkSoft : Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }

    @ViewBuilder
    private func answering(_ s: SpaceState, _ ans: Answer, key: String) -> some View {
        HStack(spacing: 10) {
            status(s.me, done: ans.me != nil)
            status(s.partner, done: ans.partner != nil)
        }
        if ans[who] == nil {
            Text("轮到 \(Text(store.name(who)).bold()) 回答，对方先别偷看 🙈 两人都答完才会揭晓。")
                .font(.footnote).foregroundStyle(.secondary)
            TextField("\(store.name(who)) 的回答…", text: $draft, axis: .vertical)
                .lineLimit(4...8).focused($focused)
                .padding(12)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button("提交并藏起来") { submit(key: key) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } else {
            let other: Author = who == .me ? .partner : .me
            HStack {
                Text("\(store.name(who)) 已回答，把手机递给 \(store.name(other)) 吧～").font(.footnote).foregroundStyle(.secondary)
                Button("切换") { who = other }.font(.footnote)
            }
        }
    }

    private func status(_ name: String, done: Bool) -> some View {
        Text("\(name) \(done ? "✓ 已回答" : "未回答")")
            .font(.footnote).foregroundStyle(done ? .green : .secondary)
            .frame(maxWidth: .infinity).padding(8)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func history(_ s: SpaceState, today: String) -> some View {
        let past = s.answers.filter { $0.key != today && $0.value.bothAnswered }.sorted { $0.key > $1.key }.prefix(30)
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(text: "我们聊过的")
                ForEach(Array(past), id: \.key) { k, a in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(Text(s.me).bold())：\(a.me ?? "")")
                            Text("\(Text(s.partner).bold())：\(a.partner ?? "")")
                        }
                        .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(k).font(.caption).foregroundStyle(.secondary)
                            Text(Catalog.question(for: k)).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        }
                    }
                    .tint(.secondary)
                    .padding(.vertical, 6)
                    Divider()
                }
            }
            .card()
        }
    }

    private func submit(key: String) {
        let t = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !t.isEmpty else { return }
        let current = who
        withAnimation(.spring) {
            store.update { s in
                var a = s.answers[key] ?? Answer()
                a[current] = t
                s.answers[key] = a
            }
        }
        draft = ""; focused = false
        who = current == .me ? .partner : .me
    }
}
