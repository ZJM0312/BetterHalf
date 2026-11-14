import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SpaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLock.self) private var lock
    @Environment(CloudSync.self) private var cloud
    @State private var lockOn = false
    @State private var photoHints = PhotoMonitor.isEnabled
    @State private var photoPicker = PhotoAccess.pickerEnabled
    @State private var showSync = false
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
                    NavigationLink { CloudSyncView() } label: {
                        HStack {
                            Label("异地同步（iCloud）", systemImage: "icloud")
                            Spacer()
                            Text(cloud.isPaired ? "已连接" : cloud.status == .waitingForPartner ? "等 TA 加入" : "").foregroundStyle(.secondary)
                        }
                    }
                    Button { showSync = true } label: {
                        Label("面对面同步（不用网络）", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Toggle(isOn: $lockOn) { Label("\(lock.biometryName)锁", systemImage: "lock.fill") }
                        .onChange(of: lockOn) { _, on in
                            guard on != lock.isEnabled else { return }
                            Task {
                                let ok = await lock.setEnabled(on)
                                if !ok { lockOn = lock.isEnabled; message = lock.error ?? "验证没有通过" }
                            }
                        }
                } header: { Text("私密与同步") } footer: {
                    Text("异地同步通过你们自己的 iCloud 私密共享，TA 一有更新就会通知你；面对面同步是两部手机直接加密传输，不经过任何服务器。开启锁后，每次回到 App 都需要验证。")
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
                    Text("纪念日前一天 20:00、当天 9:00 提醒；每晚 21:00 提醒回答今日一问；3 天没记录回忆、宠物饿了也会提醒你。")
                }

                Section {
                    Toggle(isOn: $photoPicker) {
                        Label("允许从相册选择照片", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: photoPicker) { _, on in
                        PhotoAccess.setPickerEnabled(on)
                        if !on { photoHints = false }
                    }
                    Toggle(isOn: $photoHints) {
                        Label("读取最新照片并提醒记录", systemImage: "sparkle.magnifyingglass")
                    }
                    .disabled(!photoPicker)
                    .onChange(of: photoHints) { _, on in
                        guard on != PhotoMonitor.isEnabled else { return }
                        if on {
                            Task {
                                if !(await PhotoMonitor.enable()) { photoHints = false; message = "相册权限未开启，可以在系统设置里打开" }
                            }
                        } else { PhotoMonitor.disable() }
                    }
                    Button("在系统设置里管理相册权限") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .font(.footnote)
                } header: { Text("相册授权") } footer: {
                    Text("「从相册选择」关闭后，回忆和宠物里不再显示相册入口。「读取最新照片」默认关闭，开启后只在打开「回忆」时在本机查看新拍的照片，提示你一键记录。照片只在你的手机上读取，除非你自己把它加进回忆，否则不会同步给任何人。")
                }

                Section {
                    Label("只同步你们在 App 里写下的内容：回忆、每日一问、清单、纪念日、宠物，以及你亲手加进回忆的照片 / 视频 / 语音", systemImage: "checkmark.shield")
                    Label("无法读取对方手机的相册、通讯录、位置、短信、文件或其他 App 的任何信息，代码里也没有这样的入口", systemImage: "hand.raised")
                    Label("对方发来的数据会先校验，只接受 App 自己生成的内容", systemImage: "lock.doc")
                } header: { Text("你们之间共享什么") }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Section {
                    Button("导出备份") {
                        if let data = try? store.exportData() { exportDoc = BackupDocument(data: data) }
                    }
                    Button("导入备份") { importing = true }
                } header: { Text("数据与隐私") } footer: {
                    Text("数据保存在这台 iPhone 上（开启异地同步时也存在你们自己的 iCloud），不会上传到开发者的任何服务器。备份文件包含照片、视频和语音，格式与网页版通用（网页版只显示文字和旧版照片）。")
                }

                Section {
                    NavigationLink { AISettingsView() } label: { Label("AI 设置（自带 API Key）", systemImage: "sparkles") }
                } footer: {
                    Text("填写你自己的 DeepSeek / OpenAI / Claude 等 API Key，让宠物会聊天、能生成卡通形象。")
                }

                Section("关于") {
                    NavigationLink { PrivacyPolicyView() } label: { Label("隐私政策", systemImage: "hand.raised") }
                    LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                }

                Section {
                    Button("清空全部数据", role: .destructive) { confirmReset = true }
                }

                if let message { Section { Text(message).foregroundStyle(.secondary) } }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showSync) { SyncView() }
            .onAppear {
                lockOn = lock.isEnabled
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
