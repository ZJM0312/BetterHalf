import SwiftUI

struct TogetherView: View {
    @Environment(SpaceStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showAdd = false
    @State private var showSettings = false
    @State private var showSync = false
    @AppStorage("coupleWidgetTipDismissed") private var widgetTipDismissed = false
    @State private var poster: UIImage?

    var body: some View {
        NavigationStack {
            if let s = store.state {
                ScrollView {
                    VStack(spacing: 14) {
                        greeting(s)
                        hero(s)
                        todayCard(s)
                        anniversaries(s)
                        if !widgetTipDismissed { widgetTip }
                    }
                    .padding(16)
                }
                .screenBackground()
                .navigationTitle("BetterHalf")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSync = true } label: { Image(systemName: "arrow.triangle.2.circlepath.circle") }
                            .accessibilityLabel("和 TA 的手机同步")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("设置")
                    }
                }
                .sheet(isPresented: $showAdd) { AddAnniversarySheet() }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .sheet(isPresented: $showSync) { SyncView() }
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

extension TogetherView {
    func greeting(_ s: SpaceState) -> some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let (hello, emoji): (String, String) = switch hour {
        case 5..<11: ("早上好", "☀️")
        case 11..<13: ("中午好", "🍱")
        case 13..<18: ("下午好", "☕️")
        case 18..<23: ("晚上好", "🌙")
        default: ("夜深了，早点休息", "💤")
        }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(hello)，\(s.me) \(emoji)").font(.title3.bold())
                Text(DateKit.calendar.isDate(Date(), equalTo: DateKit.date(s.startDate), toGranularity: .day) ? "今天是你们在一起的第一天 💕" : "今天也要好好爱 \(s.partner) 哦")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    /// Small, actionable reminders for today. Each row jumps to the relevant tab.
    func todayCard(_ s: SpaceState) -> some View {
        let items = todayItems(s)
        return VStack(alignment: .leading, spacing: 4) {
            SectionTitle(text: "今天").padding(.bottom, 4)
            ForEach(items, id: \.text) { item in
                Button {
                    if let tab = item.tab { router.tab = tab }
                } label: {
                    HStack(spacing: 10) {
                        Text(item.emoji).font(.title3).frame(width: 30)
                        Text(item.text).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Spacer()
                        if item.tab != nil { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(item.tab == nil)
            }
        }
        .card()
    }

    private struct TodayItem { let emoji: String; let text: String; let tab: AppTab? }

    private func todayItems(_ s: SpaceState) -> [TodayItem] {
        var out: [TodayItem] = []
        let today = DateKit.key()
        let ans = s.answers[today] ?? Answer()
        if ans.bothAnswered {
            out.append(TodayItem(emoji: "✅", text: "今日一问你们都答完啦，去看看彼此的回答", tab: .talk))
        } else if ans.me != nil {
            out.append(TodayItem(emoji: "💬", text: "你答完了，等 \(s.partner) 回答今日一问", tab: .talk))
        } else {
            out.append(TodayItem(emoji: "💬", text: "今日一问还没回答：\(Catalog.question(for: today))", tab: .talk))
        }
        if let pet = s.petList.first {
            switch pet.mood() {
            case .hungry: out.append(TodayItem(emoji: "🍖", text: "\(pet.name)饿了，去喂喂 TA", tab: .pet))
            case .lonely: out.append(TodayItem(emoji: "🥺", text: "\(pet.name)想你们了，去陪 TA 聊聊天", tab: .pet))
            case .sleeping: out.append(TodayItem(emoji: "💤", text: "\(pet.name)睡着了，明天再一起玩", tab: .pet))
            case .happy: out.append(TodayItem(emoji: pet.species, text: "\(pet.name)今天心情不错", tab: .pet))
            }
        } else {
            out.append(TodayItem(emoji: "🐾", text: "添加你们的宠物，让 TA 陪你们", tab: .pet))
        }
        let all = s.anniversaries + [Anniversary(id: "_start", name: "在一起纪念日", date: s.startDate, yearly: true)]
        if let next = all.compactMap({ a in DateKit.daysUntil(a, today: today).map { (a, $0) } }).min(by: { $0.1 < $1.1 }), next.1 <= 30 {
            out.append(TodayItem(emoji: next.1 == 0 ? "🎉" : "🎁",
                                 text: next.1 == 0 ? "今天就是\(next.0.name)！记得说一句我爱你" : "\(next.1) 天后是\(next.0.name)，可以开始准备惊喜了",
                                 tab: nil))
        }
        let latest = s.moments.map(\.date).max()
        let gap = latest.map { DateKit.daysBetween($0, today) } ?? 99
        if gap >= 3 {
            out.append(TodayItem(emoji: "📸", text: latest == nil ? "记录你们的第一条回忆吧" : "已经 \(gap) 天没记录回忆了", tab: .memories))
        }
        return out
    }

    var widgetTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("📱").font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text("把天数放到桌面和锁屏").font(.subheadline.bold())
                Text("长按桌面空白处 → 左上角「编辑」→「添加小组件」→ 搜索 BetterHalf。长按小组件 →「编辑小组件」可以选择显示在一起天数、里程碑或某个纪念日。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { widgetTipDismissed = true } label: { Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary) }
                .accessibilityLabel("不再提示")
        }
        .card(Theme.pinkSoft)
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
