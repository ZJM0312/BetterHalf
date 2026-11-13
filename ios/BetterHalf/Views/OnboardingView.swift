import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Environment(SpaceStore.self) private var store
    @State private var me = ""
    @State private var partner = ""
    @State private var start = Date()
    @State private var error: String?
    @State private var importing = false

    private let features: [(String, String, String)] = [
        ("💞", "在一起天数", "纪念日自动倒数，提前一天提醒你"),
        ("📸", "回忆时间线", "记下每个瞬间，“那年今天”自动回顾"),
        ("🎡", "选择困难终结者", "今天吃什么？转一下就决定"),
        ("💬", "每日一问", "两人都答完才揭晓，聊出说不出口的话"),
        ("✅", "情侣清单", "一起想做的 100 件事"),
        ("🔒", "数据只属于你们", "无需注册，数据只存在这台手机上"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("BetterHalf").font(.title3.weight(.heavy)) + Text(" ♥").font(.title3).foregroundColor(Theme.pink)
                    Text("两个人的小宇宙")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.gradient)
                    Text("记录在一起的每一天，告别“吃什么都行”，\n把想说的话好好说给 TA 听。")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 14) {
                    field("你的昵称", text: $me, placeholder: "比如：小明")
                    field("TA 的昵称", text: $partner, placeholder: "比如：小红")
                    DatePicker("在一起的日子", selection: $start, in: ...Date(), displayedComponents: .date)
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                    Button("开启我们的空间 →", action: create).buttonStyle(PrimaryButtonStyle())
                    Button("已有备份？导入数据") { importing = true }
                        .font(.footnote).frame(maxWidth: .infinity)
                }
                .card()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(features, id: \.1) { icon, title, desc in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(icon).font(.title2)
                            Text(title).font(.subheadline.weight(.semibold))
                            Text(desc).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                Text("无需注册 · 30 秒开始 · 永久免费").font(.footnote).foregroundStyle(.secondary).padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), store.importData(data) { return }
            error = "备份文件无法识别"
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .padding(12)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: text.wrappedValue) { _, v in if v.count > 12 { text.wrappedValue = String(v.prefix(12)) } }
        }
    }

    private func create() {
        let m = me.trimmingCharacters(in: .whitespaces), p = partner.trimmingCharacters(in: .whitespaces)
        guard !m.isEmpty, !p.isEmpty else { error = "写下你们两个人的名字吧"; return }
        store.create(me: m, partner: p, startDate: DateKit.key(start))
    }
}
