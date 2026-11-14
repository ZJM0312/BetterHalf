import SwiftUI

/// "AI 设置": users bring their own provider + key. Nothing is built in or paid for by the app.
struct AISettingsView: View {
    @Environment(AISettings.self) private var ai

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("用你自己的 AI 账号", systemImage: "key.fill").font(.headline)
                    Text("填写你在 AI 服务商那里申请的 API Key，就能让宠物用 AI 聊天、生成卡通形象。费用由你在服务商那里结算，BetterHalf 不收取任何费用，也不会经手你的数据。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                NavigationLink {
                    AIEndpointEditor(kind: .chat, presets: AIPresets.chat, title: "对话模型")
                } label: {
                    row(title: "对话模型", icon: "bubble.left.and.text.bubble.right", endpoint: ai.chat, ready: ai.chatReady, presets: AIPresets.chat)
                }
                NavigationLink {
                    AIEndpointEditor(kind: .image, presets: AIPresets.image, title: "生图模型")
                } label: {
                    row(title: "生图模型", icon: "paintpalette", endpoint: ai.image, ready: ai.imageReady, presets: AIPresets.image)
                }
            } footer: {
                Text("对话预设了 DeepSeek、豆包 Seed、通义千问、Kimi、智谱、OpenAI、Claude、Gemini 等 20 家，生图预设了 Seedream、硅基流动、CogView、OpenAI、Imagen 等 8 家，也可以填任何兼容接口。DeepSeek 和 Claude 没有生图接口，生图请另选一家。没填也没关系，宠物会用内置的「小脑袋」陪你聊天。")
            }

            Section("隐私") {
                Label("API Key 只保存在这台 iPhone 的钥匙串里，不会同步、不会进备份；每个服务商的 Key 分开保存", systemImage: "lock.shield")
                Label("和宠物的聊天只会发给你选择的服务商，第一次使用前会再问你", systemImage: "hand.raised")
                Label("聊天记录只保存在本机", systemImage: "iphone")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("AI 设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: String, icon: String, endpoint: AIEndpoint?, ready: Bool, presets: [AIPreset]) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if let e = endpoint, ready {
                Text(presets.first { $0.id == e.presetID }?.name ?? e.host).foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Text("未设置").foregroundStyle(.secondary)
            }
        }
    }
}

private struct AIEndpointEditor: View {
    @Environment(AISettings.self) private var ai
    @Environment(\.dismiss) private var dismiss
    let kind: AISettings.Kind
    let presets: [AIPreset]
    let title: String

    @State private var presetID = ""
    @State private var baseURL = ""
    @State private var model = ""
    @State private var key = ""
    @State private var size = ""
    @State private var extra = ""
    @State private var revealKey = false
    @State private var testing = false
    @State private var testResult: (ok: Bool, text: String)?
    @State private var loaded = false

    private var preset: AIPreset? { presets.first { $0.id == presetID } }
    private var endpoint: AIEndpoint {
        var e = AIEndpoint(preset: preset ?? presets[0])
        e.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
        e.model = model.trimmingCharacters(in: .whitespaces)
        e.size = kind == .image ? size.trimmingCharacters(in: .whitespaces) : nil
        e.extra = extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : extra
        return e
    }

    var body: some View {
        Form {
            Section("服务商") {
                Picker("服务商", selection: $presetID) {
                    ForEach(AIPresets.grouped(presets), id: \.0) { group, items in
                        Section(group) {
                            ForEach(items) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: presetID) { old, new in
                    guard loaded, old != new, let p = presets.first(where: { $0.id == new }) else { return }
                    // Restore what was saved for this provider, else its defaults; its own key, never the previous one.
                    let saved = (kind == .chat ? ai.chat : ai.image).flatMap { $0.presetID == new ? $0 : nil }
                    baseURL = saved?.baseURL ?? p.baseURL
                    model = saved?.model ?? p.model
                    size = saved?.size ?? p.size ?? ""
                    extra = saved?.extra ?? ""
                    key = ai.key(kind, presetID: new)
                    testResult = nil
                }
            }

            Section {
                LabeledContent("接口地址") {
                    TextField("https://…", text: $baseURL).multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                }
                LabeledContent("模型") {
                    TextField("模型名", text: $model).multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                if kind == .image && preset.map({ AIImageFormat(rawValue: $0.format) != .minimax }) ?? true {
                    LabeledContent("图片尺寸") {
                        TextField("默认", text: $size).multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                }
                HStack {
                    Text("API Key")
                    Group {
                        if revealKey { TextField("sk-…", text: $key) } else { SecureField("sk-…", text: $key) }
                    }
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button { revealKey.toggle() } label: { Image(systemName: revealKey ? "eye.slash" : "eye") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .accessibilityLabel(revealKey ? "隐藏密钥" : "显示密钥")
                }
            } footer: {
                Text(preset?.keyHint ?? "")
            }

            Section {
                DisclosureGroup("高级：附加参数") {
                    TextField(#"{"temperature": 0.8}"#, text: $extra, axis: .vertical)
                        .font(.footnote.monospaced())
                        .lineLimit(2...6)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            } footer: {
                Text("可选。填一个 JSON 对象，会合并进请求体，用来传服务商特有的参数。不懂可以不填。")
            }

            Section {
                Button {
                    Task { await test() }
                } label: {
                    HStack {
                        Text(kind == .chat ? "测试连接" : "测试生成一张图")
                        Spacer()
                        if testing { ProgressView() }
                    }
                }
                .disabled(testing || !endpoint.isComplete)
                if let r = testResult {
                    Label(r.text, systemImage: r.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(r.ok ? .green : .orange).font(.footnote)
                }
            } footer: {
                if kind == .image { Text("测试会真实生成一张图，服务商可能会收取少量费用。") }
            }

            Section {
                Button("保存") {
                    ai.save(kind, endpoint: endpoint, key: key)
                    dismiss()
                }
                .disabled(!endpoint.isComplete)
                if (kind == .chat ? ai.chat : ai.image) != nil {
                    Button("清除这个设置", role: .destructive) {
                        ai.clear(kind)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            if let e = kind == .chat ? ai.chat : ai.image {
                presetID = e.presetID; baseURL = e.baseURL; model = e.model
                size = e.size ?? ""; extra = e.extra ?? ""
            } else {
                presetID = presets[0].id; baseURL = presets[0].baseURL; model = presets[0].model
                size = presets[0].size ?? ""
            }
            key = ai.key(kind, presetID: presetID)
            DispatchQueue.main.async { loaded = true }
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            if kind == .chat {
                let reply = try await AIClient.chat(system: "用一句很短的中文回复。",
                                                    history: [AIChatMessage(role: "user", content: "你好，测试一下")],
                                                    endpoint: endpoint, key: key.trimmingCharacters(in: .whitespacesAndNewlines))
                testResult = (true, "连接成功：\(reply.prefix(40))")
            } else {
                _ = try await AIClient.image(prompt: "a cute cartoon cat sticker, white background",
                                             endpoint: endpoint, key: key.trimmingCharacters(in: .whitespacesAndNewlines))
                testResult = (true, "生成成功，可以使用了")
            }
        } catch {
            testResult = (false, error.localizedDescription)
        }
    }
}
