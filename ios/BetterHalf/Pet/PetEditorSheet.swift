import SwiftUI
import PhotosUI

/// Add or edit a pet: photo (auto cut-out) or AI-generated look, name, species, personality.
struct PetEditorSheet: View {
    @Environment(SpaceStore.self) private var store
    @Environment(AISettings.self) private var ai
    @Environment(\.dismiss) private var dismiss
    var pet: Pet? = nil
    var onSaved: (String) -> Void = { _ in }

    @State private var name = ""
    @State private var species = "🐱"
    @State private var traits: Set<String> = []
    @State private var personalityNote = ""
    @State private var appearance = ""
    @State private var style: PetArtStyle = .sticker

    @State private var pickerItem: PhotosPickerItem?
    @AppStorage(PhotoAccess.pickerKey) private var photoPickerOn = true
    @State private var newImage: UIImage?      // chosen this session (nil = keep current)
    @State private var currentImage: UIImage?  // existing pet image when editing
    @State private var rawPhoto: UIImage?
    @State private var useOriginal = false
    @State private var processing = false
    @State private var status: String?
    @State private var showGenerator = false
    @State private var askConsent = false
    @State private var loaded = false

    private let speciesList = ["🐱", "🐶", "🐰", "🐹", "🐦", "🐢", "🐟", "🦊"]
    private let traitList = ["粘人精", "高冷", "话痨", "吃货", "傲娇", "胆小", "好奇宝宝", "睡神"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            Checkerboard().clipShape(RoundedRectangle(cornerRadius: 16))
                            if processing {
                                VStack(spacing: 8) { ProgressView(); Text(status ?? "处理中…").font(.caption) }
                            } else if let img = preview {
                                Image(uiImage: img).resizable().scaledToFit().padding(10)
                            } else {
                                Text(species).font(.system(size: 80))
                            }
                        }
                        .frame(height: 220)
                        HStack(spacing: 10) {
                            if photoPickerOn {
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    Label("上传照片", systemImage: "photo").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            Button { withAnimation { showGenerator.toggle() } } label: {
                                Label("AI 生成", systemImage: "sparkles").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        if let status, !processing { Text(status).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                        if rawPhoto != nil && !processing {
                            Toggle("使用原图（不抠图）", isOn: $useOriginal).font(.subheadline)
                        }
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("上传照片会自动抠出宠物的样子（需要 iPhone 真机）。")
                }

                if showGenerator { generatorSection }

                Section("名字") { TextField("比如：咪咪", text: $name) }

                Section("种类") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(speciesList, id: \.self) { s in
                            Text(s).font(.largeTitle).frame(maxWidth: .infinity).padding(6)
                                .background(s == species ? Theme.pinkSoft : .clear, in: RoundedRectangle(cornerRadius: 12))
                                .onTapGesture { species = s }
                                .accessibilityLabel(Pet.speciesNames[s] ?? s)
                                .accessibilityAddTraits(s == species ? .isSelected : [])
                        }
                    }
                }

                Section {
                    FlowLayout(spacing: 8) {
                        ForEach(traitList, id: \.self) { t in
                            let on = traits.contains(t)
                            Text(t).font(.subheadline)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .foregroundStyle(on ? .white : .primary)
                                .background(on ? Theme.pink : Theme.bg, in: Capsule())
                                .onTapGesture { if on { traits.remove(t) } else { traits.insert(t) } }
                                .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    TextField("还有什么小习惯？比如：最爱趴在键盘上", text: $personalityNote, axis: .vertical)
                } header: { Text("性格") } footer: {
                    Text("性格会影响 TA 聊天时的语气。")
                }
            }
            .navigationTitle(pet == nil ? "添加宠物" : "编辑 \(pet!.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || processing)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await processPhoto(item) }
            }
            .alert("把描述发送给生图服务？", isPresented: $askConsent) {
                Button("同意并生成") {
                    if let h = ai.image?.host { ai.grantConsent(for: h) }
                    Task { await generate() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("宠物的外观描述会发送到 \(ai.image?.host ?? "") 生成图片，按你在那里的账号计费。")
            }
            .onAppear(perform: load)
        }
    }

    private var generatorSection: some View {
        Section {
            if ai.imageReady {
                TextField("描述 TA 的样子：橘色短毛、圆脸、白手套", text: $appearance, axis: .vertical)
                Picker("风格", selection: $style) {
                    ForEach(PetArtStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Button {
                    if let h = ai.image?.host, !ai.hasConsent(for: h) { askConsent = true } else { Task { await generate() } }
                } label: {
                    Label("生成形象", systemImage: "wand.and.stars")
                }
                .disabled(appearance.trimmingCharacters(in: .whitespaces).isEmpty || processing)
            } else {
                NavigationLink { AISettingsView() } label: {
                    Label("先去「AI 设置」填写生图服务", systemImage: "key")
                }
            }
        } header: { Text("AI 生成卡通形象") } footer: {
            Text("用你自己的 AI 账号生成，生成后同样会自动抠图。")
        }
    }

    private var preview: UIImage? {
        if useOriginal, let raw = rawPhoto { return PetCutout.circleCrop(raw) }
        return newImage ?? currentImage
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let pet else { return }
        name = pet.name
        species = pet.species
        appearance = pet.appearance ?? ""
        let parts = (pet.personality ?? "").components(separatedBy: "、")
        traits = Set(parts.filter { traitList.contains($0) })
        personalityNote = parts.filter { !traitList.contains($0) && !$0.isEmpty }.joined(separator: "、")
        if let f = pet.imageFile { currentImage = UIImage(contentsOfFile: SharedContainer.mediaURL(f).path) }
    }

    private func processPhoto(_ item: PhotosPickerItem) async {
        processing = true
        status = "正在抠出 TA 的样子…"
        defer { processing = false }
        guard let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else {
            status = "这张照片读取失败，换一张试试"
            return
        }
        rawPhoto = img
        useOriginal = false
        if let lifted = await PetCutout.lift(img) {
            newImage = lifted
            status = "抠图完成 ✓"
        } else {
            newImage = PetCutout.circleCrop(img)
            status = "没能自动识别出宠物，先用圆形头像"
        }
    }

    private func generate() async {
        guard let endpoint = ai.image else { return }
        processing = true
        status = "AI 正在画 TA…（大约 10～60 秒）"
        defer { processing = false }
        var draftPet = pet ?? Pet(name: name, species: species)
        draftPet.species = species
        let prompt = PetBrain.imagePrompt(pet: draftPet, appearance: appearance, style: style)
        do {
            let img = try await AIClient.image(prompt: prompt, endpoint: endpoint, key: ai.key(.image))
            rawPhoto = nil
            useOriginal = false
            newImage = await PetCutout.lift(img) ?? PetCutout.normalized(img, maxSide: 600)
            status = "生成好了 ✨ 不满意可以再生成一次"
        } catch {
            status = "生成失败：\(error.localizedDescription)"
        }
    }

    private func save() {
        var p = pet ?? Pet(name: "", species: species)
        p.name = String(name.trimmingCharacters(in: .whitespaces).prefix(10))
        p.species = species
        let personality = (traitList.filter { traits.contains($0) } + [personalityNote.trimmingCharacters(in: .whitespaces)])
            .filter { !$0.isEmpty }.joined(separator: "、")
        p.personality = personality.isEmpty ? nil : personality
        p.appearance = appearance.trimmingCharacters(in: .whitespaces).isEmpty ? nil : appearance
        if (newImage != nil || useOriginal), let img = preview, let png = img.pngData() {
            // New file name so cached images (app + widget) refresh.
            let file = "\(p.id)-\(Int(Date().timeIntervalSince1970)).png"
            if (try? png.write(to: SharedContainer.mediaURL(file), options: .atomic)) != nil {
                if let old = p.imageFile { try? FileManager.default.removeItem(at: SharedContainer.mediaURL(old)) }
                p.imageFile = file
            }
        }
        let saved = p
        store.update { s in
            if let i = s.petList.firstIndex(where: { $0.id == saved.id }) { s.petList[i] = saved } else { s.petList.append(saved) }
        }
        onSaved(saved.id)
        dismiss()
    }
}

struct Checkerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 12
            for x in stride(from: 0, to: size.width, by: s) {
                for y in stride(from: 0, to: size.height, by: s) where (Int(x / s) + Int(y / s)) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(.gray.opacity(0.12)))
                }
            }
        }
    }
}
