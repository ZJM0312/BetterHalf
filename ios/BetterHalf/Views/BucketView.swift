import SwiftUI

struct BucketView: View {
    @Environment(SpaceStore.self) private var store
    @State private var text = ""

    var body: some View {
        Group {
            if let s = store.state {
                let done = s.bucket.filter(\.done).count
                let items = s.bucket.sorted { !$0.done && $1.done }
                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(text: "我们要一起做的事", trailing: "\(done)/\(s.bucket.count)")
                            if !s.bucket.isEmpty {
                                ProgressView(value: Double(done), total: Double(s.bucket.count)).tint(Theme.pink)
                            }
                            HStack {
                                TextField("一起去看极光…", text: $text)
                                    .padding(12).background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
                                    .onSubmit { add(text); text = "" }
                                Button("添加") { add(text); text = "" }.buttonStyle(PrimaryButtonStyle(fullWidth: false))
                            }
                            if items.isEmpty { EmptyHint(text: "还没有清单，从下面挑几个灵感吧") }
                            ForEach(items) { b in
                                HStack {
                                    Button { toggle(b) } label: {
                                        Image(systemName: b.done ? "checkmark.circle.fill" : "circle")
                                            .font(.title3).foregroundStyle(b.done ? Theme.pink : .secondary)
                                    }
                                    Text(b.text).strikethrough(b.done).foregroundStyle(b.done ? .secondary : .primary)
                                    Spacer()
                                    if let d = b.doneAt { Text(d).font(.caption).foregroundStyle(.secondary) }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture { toggle(b) }
                                .contextMenu {
                                    Button("删除", systemImage: "trash", role: .destructive) {
                                        store.update { $0.bucket.removeAll { $0.id == b.id } }
                                    }
                                }
                            }
                        }
                        .card()

                        let ideas = Catalog.bucketIdeas.filter { i in !s.bucket.contains { $0.text == i } }
                        if !ideas.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle(text: "💡 灵感")
                                FlowLayout(spacing: 8) {
                                    ForEach(ideas, id: \.self) { i in
                                        Button("+ \(i)") { add(i) }
                                            .font(.footnote).foregroundStyle(.primary)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .overlay(Capsule().stroke(Color.secondary.opacity(0.3)))
                                    }
                                }
                            }
                            .card()
                        }
                    }
                    .padding(16)
                    .animation(.default, value: s.bucket)
                }
                .screenBackground()
            }
        }
    }

    private func add(_ t: String) {
        let v = String(t.trimmingCharacters(in: .whitespaces).prefix(40))
        guard !v.isEmpty else { return }
        store.update { $0.bucket.append(BucketItem(text: v)) }
    }

    private func toggle(_ b: BucketItem) {
        if !b.done { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        store.update { s in
            guard let i = s.bucket.firstIndex(where: { $0.id == b.id }) else { return }
            s.bucket[i].done.toggle()
            s.bucket[i].doneAt = s.bucket[i].done ? DateKit.key() : nil
        }
    }
}
