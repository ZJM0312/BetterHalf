import SwiftUI
import PhotosUI

struct MemoriesView: View {
    @Environment(SpaceStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var text = ""
    @State private var date = Date()
    @State private var mood = Catalog.moods[0]
    @State private var by: Author = .me
    @State private var pending: [PendingMedia] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var loadingMedia = false
    @State private var recorder = VoiceRecorder()
    @State private var newAssets: [PHAsset] = []
    @State private var toDelete: Moment?
    @State private var editing: Moment?
    @AppStorage(PhotoAccess.pickerKey) private var photoPickerOn = true
    @State private var noteFor: Moment?
    @State private var noteText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            if let s = store.state {
                ScrollView {
                    VStack(spacing: 14) {
                        if !newAssets.isEmpty { NewPhotosCard(assets: newAssets, onAdd: importNewAssets, onDismiss: dismissNewAssets) }
                        onThisDay(s)
                        composer(s)
                        list(s)
                    }
                    .padding(16)
                }
                .screenBackground()
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("回忆")
                .onChange(of: pickerItems) { _, items in
                    guard !items.isEmpty else { return }
                    loadingMedia = true
                    Task {
                        for item in items {
                            if let p = await MediaImporter.load(item), pending.count < 9 { pending.append(p) }
                        }
                        pickerItems = []
                        loadingMedia = false
                    }
                }
                .onAppear(perform: refreshNewAssets)
                .onChange(of: scenePhase) { _, p in if p == .active { refreshNewAssets() } }
                .sheet(item: $editing) { m in EditMomentSheet(moment: m) }
                .alert("补充一句", isPresented: Binding(get: { noteFor != nil }, set: { if !$0 { noteFor = nil } })) {
                    TextField("那天我还记得…", text: $noteText)
                    Button("添加") { addNote() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("你和 TA 的补充会分别保留，同时写也不会互相覆盖")
                }
                .confirmationDialog("删除这条回忆？", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                    titleVisibility: .visible) {
                    Button("删除", role: .destructive) { if let m = toDelete { store.deleteMoment(m) } }
                }
            }
        }
    }

    // MARK: sections

    @ViewBuilder
    private func onThisDay(_ s: SpaceState) -> some View {
        let today = DateKit.key()
        let hits = s.moments.filter { $0.date.suffix(5) == today.suffix(5) && $0.date != today }
        if !hits.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "📅 那年今天")
                ForEach(hits) { m in
                    Text("\(Text(m.date.prefix(4)).bold())  \(m.mood) \(m.text)")
                }
            }
            .card(Theme.pinkSoft)
        }
    }

    private func composer(_ s: SpaceState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "记录一个瞬间")
            TextField("今天一起去吃了那家排队很久的店…", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .focused($focused)
                .padding(12)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !pending.isEmpty || loadingMedia { pendingStrip }
            if recorder.isRecording { recordingBar }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Catalog.moods, id: \.self) { m in
                        Text(m).font(.title2).padding(4)
                            .background(m == mood ? Theme.pinkSoft : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(m == mood ? Theme.pink : .clear, lineWidth: 2))
                            .onTapGesture { mood = m }
                    }
                }
            }
            HStack {
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date).labelsHidden()
                Picker("记录人", selection: $by) {
                    Text(s.me).tag(Author.me)
                    Text(s.partner).tag(Author.partner)
                }
                .pickerStyle(.segmented)
            }
            HStack(spacing: 8) {
                if photoPickerOn {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: max(1, 9 - pending.count),
                                 matching: .any(of: [.images, .videos])) {
                        toolLabel("photo.on.rectangle", "照片/视频")
                    }
                    .disabled(pending.count >= 9)
                }
                Button {
                    if recorder.isRecording {
                        if let p = recorder.stop() { pending.append(p) }
                    } else {
                        Task { await recorder.start() }
                    }
                } label: {
                    toolLabel(recorder.isRecording ? "stop.circle.fill" : "mic", recorder.isRecording ? "停止" : "语音")
                }
                Spacer(minLength: 0)
                Button("保存", action: save).buttonStyle(PrimaryButtonStyle(fullWidth: false))
                    .disabled(!canSave)
            }
            if recorder.denied { Text("麦克风权限未开启，可以在系统设置里打开").font(.footnote).foregroundStyle(.red) }
            if let err = store.lastError { Text(err).font(.footnote).foregroundStyle(.red) }
        }
        .card()
    }

    private func toolLabel(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon).font(.subheadline)
            .padding(.vertical, 11).padding(.horizontal, 12)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
    }

    private var pendingStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pending) { p in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if p.kind == .audio {
                                VStack(spacing: 4) {
                                    Image(systemName: "waveform").font(.title2)
                                    Text(formatDuration(p.duration)).font(.caption2).monospacedDigit()
                                }
                                .foregroundStyle(Theme.pink)
                                .frame(width: 80, height: 80)
                                .background(Theme.pinkSoft)
                            } else if let t = p.thumbnail {
                                Image(uiImage: t).resizable().scaledToFill().frame(width: 80, height: 80).clipped()
                                    .overlay {
                                        if p.kind == .video { Image(systemName: "play.fill").foregroundStyle(.white).shadow(radius: 3) }
                                    }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button { pending.removeAll { $0.id == p.id } } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .padding(3)
                        .accessibilityLabel("移除附件")
                    }
                }
                if loadingMedia { ProgressView().frame(width: 80, height: 80) }
            }
        }
    }

    private var recordingBar: some View {
        HStack {
            Circle().fill(.red).frame(width: 10, height: 10).opacity(Int(recorder.elapsed * 2) % 2 == 0 ? 1 : 0.3)
            Text("正在录音 \(formatDuration(recorder.elapsed))").font(.subheadline).monospacedDigit()
            Spacer()
            Text("最长 5 分钟").font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Theme.pinkSoft, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func list(_ s: SpaceState) -> some View {
        let sorted = s.moments.sorted { $0.date > $1.date }
        if sorted.isEmpty {
            EmptyHint(text: "还没有回忆，从今天开始记录吧 ✍️")
        } else {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(sorted) { m in
                    HStack(alignment: .top, spacing: 10) {
                        Text(m.mood).font(.title3).frame(width: 34, height: 34)
                            .background(Theme.card, in: Circle()).shadow(color: .black.opacity(0.06), radius: 4)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(m.date); Text(m.by == .me ? s.me : s.partner)
                                Spacer()
                                Menu {
                                    Button("补充一句", systemImage: "text.bubble") { noteText = ""; noteFor = m }
                                    Button("编辑文字", systemImage: "pencil") { editing = m }
                                    Button("删除", systemImage: "trash", role: .destructive) { toDelete = m }
                                } label: { Image(systemName: "ellipsis").padding(6) }
                                .foregroundStyle(.secondary)
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if !m.text.isEmpty { Text(m.text) }
                            if let p = m.photo, let img = PhotoCodec.image(from: p) {
                                Image(uiImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            if let media = m.media, !media.isEmpty { MediaGrid(items: media) }
                            if let notes = m.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(notes) { n in
                                        (Text("\(n.by == .me ? s.me : s.partner)：").bold() + Text(n.text))
                                            .font(.subheadline)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 10))
                            }
                            HStack {
                                if let who = m.editedBy, m.updatedAt != nil, who != s.me || (m.updatedAt ?? 0) > Date().timeIntervalSince1970 - 86400 {
                                    Text("\(who) 编辑于 \(Date(timeIntervalSince1970: m.updatedAt!).formatted(.relative(presentation: .named)))")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Button { noteText = ""; noteFor = m } label: {
                                    Label("补充一句", systemImage: "text.bubble").font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .card()
                    }
                }
            }
        }
    }

    // MARK: actions

    private var canSave: Bool {
        !recorder.isRecording && !loadingMedia &&
            (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pending.isEmpty)
    }

    private func save() {
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard canSave else { return }
        let items: [MediaItem] = pending.compactMap { p in
            if let d = p.data { return store.storeMedia(data: d, kind: p.kind, ext: p.ext, duration: p.duration) }
            if let u = p.fileURL { return store.storeMedia(fileAt: u, kind: p.kind, duration: p.duration) }
            return nil
        }
        let moment = Moment(date: DateKit.key(date), text: t, mood: mood, by: by, media: items.isEmpty ? nil : items)
        store.update { $0.moments.insert(moment, at: 0) }
        text = ""; pending = []; focused = false
    }

    private func addNote() {
        let t = String(noteText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        guard let m = noteFor, !t.isEmpty else { return }
        store.update { s in
            guard let i = s.moments.firstIndex(where: { $0.id == m.id }) else { return }
            s.moments[i].notes = (s.moments[i].notes ?? []) + [MomentNote(by: .me, text: t)]
        }
        noteFor = nil
    }

    private func refreshNewAssets() {
        newAssets = PhotoMonitor.newAssets()
    }

    private func importNewAssets() {
        let assets = Array(newAssets.prefix(9 - pending.count))
        dismissNewAssets()
        loadingMedia = true
        Task {
            for a in assets { if let p = await PhotoMonitor.pending(from: a) { pending.append(p) } }
            loadingMedia = false
        }
    }

    private func dismissNewAssets() {
        PhotoMonitor.markChecked()
        withAnimation { newAssets = [] }
    }
}

private struct EditMomentSheet: View {
    let moment: Moment
    @Environment(SpaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var mood = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("写点什么…", text: $text, axis: .vertical).lineLimit(4...12) }
                Section {
                    DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                    Picker("心情", selection: $mood) { ForEach(Catalog.moods, id: \.self) { Text($0).tag($0) } }
                }
            }
            .navigationTitle("编辑回忆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.update { s in
                            guard let i = s.moments.firstIndex(where: { $0.id == moment.id }) else { return }
                            s.moments[i].text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
                            s.moments[i].mood = mood
                            s.moments[i].date = DateKit.key(date)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { text = moment.text; mood = moment.mood; date = DateKit.date(moment.date) }
        }
        .presentationDetents([.medium, .large])
    }
}

/// "你们最近拍了 N 张新照片" suggestion card.
private struct NewPhotosCard: View {
    let assets: [PHAsset]
    let onAdd: () -> Void
    let onDismiss: () -> Void
    @State private var thumbs: [String: UIImage] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: "📷 发现 \(assets.count) 张新照片/视频")
                Button { onDismiss() } label: { Image(systemName: "xmark").foregroundStyle(.secondary) }
                    .accessibilityLabel("忽略")
            }
            Text("要把它们记录成今天的回忆吗？").font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(assets, id: \.localIdentifier) { a in
                        Group {
                            if let img = thumbs[a.localIdentifier] {
                                Image(uiImage: img).resizable().scaledToFill()
                            } else {
                                Theme.bg
                            }
                        }
                        .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
                        .task { thumbs[a.localIdentifier] = await PhotoMonitor.thumbnail(a, side: 64) }
                    }
                }
            }
            Button("添加到回忆", action: onAdd).buttonStyle(PrimaryButtonStyle())
        }
        .card(Theme.pinkSoft)
    }
}
