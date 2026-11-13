import SwiftUI

struct TogetherView: View {
    @Environment(SpaceStore.self) private var store
    @State private var showAdd = false
    @State private var showSettings = false
    @State private var poster: UIImage?

    var body: some View {
        NavigationStack {
            if let s = store.state {
                ScrollView {
                    VStack(spacing: 14) {
                        hero(s)
                        anniversaries(s)
                    }
                    .padding(16)
                }
                .screenBackground()
                .navigationTitle("BetterHalf")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("设置")
                    }
                }
                .sheet(isPresented: $showAdd) { AddAnniversarySheet() }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .sheet(item: Binding(get: { poster.map(IdentifiedImage.init) }, set: { poster = $0?.image })) { item in
                    PosterSheet(image: item.image, days: store.daysTogether)
                }
            }
        }
    }

    private func hero(_ s: SpaceState) -> some View {
        let days = store.daysTogether
        let ms = DateKit.nextMilestone(days)
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(s.me)
                Image(systemName: "heart.fill").symbolEffect(.pulse)
                Text(s.partner)
            }
            .font(.headline)
            Text("我们已经在一起").opacity(0.9).padding(.top, 6)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(days)").font(.system(size: 76, weight: .heavy, design: .rounded)).contentTransition(.numericText())
                Text("天").font(.title3)
            }
            Text("距离第 \(ms.day) 天还有 \(ms.left) 天")
                .font(.footnote).padding(.horizontal, 14).padding(.vertical, 5)
                .background(.white.opacity(0.22), in: Capsule())
            Button {
                poster = PosterView.render(me: s.me, partner: s.partner, days: days, startDate: s.startDate)
            } label: {
                Label("生成分享卡片", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .overlay(Capsule().stroke(.white.opacity(0.6)))
            }
            .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func anniversaries(_ s: SpaceState) -> some View {
        let today = DateKit.key()
        let all = s.anniversaries + [Anniversary(id: "_start", name: "在一起纪念日", date: s.startDate, yearly: true)]
        let rows = all.compactMap { a in DateKit.daysUntil(a, today: today).map { (a, $0) } }.sorted { $0.1 < $1.1 }
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionTitle(text: "纪念日倒数")
                Button { showAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("添加纪念日")
            }
            .padding(.bottom, 6)
            ForEach(rows, id: \.0.id) { a, left in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.name).font(.body.weight(.semibold))
                        Text(a.date + (a.yearly ? " · 每年" : "")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if left == 0 {
                        Text("就是今天 🎉").foregroundStyle(Theme.pink).bold()
                    } else {
                        (Text("还有 ") + Text("\(left)").font(.title3.bold()).foregroundColor(Theme.pink) + Text(" 天"))
                    }
                }
                .padding(.vertical, 10)
                .contextMenu {
                    if a.id != "_start" {
                        Button("删除", systemImage: "trash", role: .destructive) {
                            store.update { $0.anniversaries.removeAll { $0.id == a.id } }
                        }
                    }
                }
                if a.id != rows.last?.0.id { Divider() }
            }
            Text("长按可删除").font(.caption2).foregroundStyle(.tertiary).padding(.top, 6)
        }
        .card()
    }
}

private struct IdentifiedImage: Identifiable {
    let image: UIImage
    var id: ObjectIdentifier { ObjectIdentifier(image) }
}

struct AddAnniversarySheet: View {
    @Environment(SpaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Date()
    @State private var yearly = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("TA 的生日 / 第一次旅行…", text: $name)
                DatePicker("日期", selection: $date, displayedComponents: .date)
                Toggle("每年重复", isOn: $yearly)
            }
            .navigationTitle("添加纪念日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let n = name.trimmingCharacters(in: .whitespaces)
                        store.update { $0.anniversaries.append(Anniversary(name: String(n.prefix(20)), date: DateKit.key(date), yearly: yearly)) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
