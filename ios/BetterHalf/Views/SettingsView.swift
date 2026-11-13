import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SpaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var me = ""
    @State private var partner = ""
    @State private var start = Date()
    @State private var reminders = Reminders.isEnabled
    @State private var exportDoc: BackupDocument?
    @State private var importing = false
    @State private var confirmImport: Data?
    @State private var confirmReset = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("我们的资料") {
                    TextField("你的昵称", text: $me)
                    TextField("TA 的昵称", text: $partner)
                    DatePicker("在一起的日子", selection: $start, in: ...Date(), displayedComponents: .date)
                    Button("保存资料") {
                        let m = me.trimmingCharacters(in: .whitespaces), p = partner.trimmingCharacters(in: .whitespaces)
                        guard !m.isEmpty, !p.isEmpty else { return }
                        store.update { $0.me = String(m.prefix(12)); $0.partner = String(p.prefix(12)); $0.startDate = DateKit.key(start) }
                        message = "已保存 ✓"
                    }
                }

                Section {
                    Toggle("纪念日与每日一问提醒", isOn: $reminders)
                        .onChange(of: reminders) { _, on in
                            if on {
                                Task {
                                    let ok = await Reminders.requestAndEnable(for: store.state)
                                    if !ok { reminders = false; message = "通知权限未开启，可以在系统设置里打开" }
                                }
                            } else { Reminders.disable() }
                        }
                } footer: {
                    Text("纪念日前一天 20:00、当天 9:00 提醒；每晚 21:00 提醒回答今日一问。")
                }

                Section {
                    Button("导出备份") {
                        if let data = try? store.exportData() { exportDoc = BackupDocument(data: data) }
                    }
                    Button("导入备份") { importing = true }
                } header: { Text("数据与隐私") } footer: {
                    Text("所有数据只保存在这台 iPhone 上，不会上传到任何服务器。备份格式与网页版通用，可以在两端互相导入。")
                }

                Section {
                    Button("清空全部数据", role: .destructive) { confirmReset = true }
                }

                if let message { Section { Text(message).foregroundStyle(.secondary) } }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .onAppear {
                guard let s = store.state else { return }
                me = s.me; partner = s.partner; start = DateKit.date(s.startDate)
            }
            .fileExporter(isPresented: Binding(get: { exportDoc != nil }, set: { if !$0 { exportDoc = nil } }),
                          document: exportDoc, contentType: .json,
                          defaultFilename: "betterhalf-备份-\(DateKit.key())") { result in
                if case .success = result { message = "已导出备份 ✓" }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                confirmImport = try? Data(contentsOf: url)
                if confirmImport == nil { message = "无法读取文件" }
            }
            .confirmationDialog("导入会覆盖这台设备上的数据，继续吗？",
                                isPresented: Binding(get: { confirmImport != nil }, set: { if !$0 { confirmImport = nil } }),
                                titleVisibility: .visible) {
                Button("导入并覆盖", role: .destructive) {
                    if let d = confirmImport { message = store.importData(d) ? "导入成功 ✓" : "备份文件无法识别" }
                    if let s = store.state { me = s.me; partner = s.partner; start = DateKit.date(s.startDate) }
                }
            }
            .confirmationDialog("确定清空全部数据？此操作不可恢复（除非你有备份）。", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("清空", role: .destructive) { dismiss(); store.reset() }
            }
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
