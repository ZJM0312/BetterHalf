import SwiftUI

/// Chat history is per pet, per device. It is never synced or exported.
enum PetChatStore {
    private static var dir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("pet-chats", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func load(_ petID: String) -> [AIChatMessage] {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("\(petID).json")) else { return [] }
        return (try? JSONDecoder().decode([AIChatMessage].self, from: data)) ?? []
    }
    static func save(_ petID: String, _ messages: [AIChatMessage]) {
        let trimmed = Array(messages.suffix(200))
        try? JSONEncoder().encode(trimmed).write(to: dir.appendingPathComponent("\(petID).json"), options: [.atomic, .completeFileProtection])
    }
    static func delete(_ petID: String) { try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(petID).json")) }
}

struct PetChatView: View {
    let petID: String
    @Environment(SpaceStore.self) private var store
    @Environment(AISettings.self) private var ai
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [AIChatMessage] = []
    @State private var draft = ""
    @State private var thinking = false
    @State private var notice: String?
    @State private var pendingConsent: String? // host waiting for user consent
    @FocusState private var focused: Bool

    private let suggestions = ["今天开心吗？", "想吃什么？", "我好想你", "晚安～"]

    var body: some View {
        NavigationStack {
            if let s = store.state, let pet = s.petList.first(where: { $0.id == petID }) {
                VStack(spacing: 0) {
                    header(pet)
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                if messages.isEmpty {
                                    Text("和 \(pet.name) 打个招呼吧 👋").font(.subheadline).foregroundStyle(.secondary).padding(.top, 40)
                                }
                                ForEach(messages) { m in bubble(m, pet: pet).id(m.id) }
                                if thinking { typing.id("typing") }
                                if let notice { Text(notice).font(.caption).foregroundStyle(.secondary).padding(.horizontal) }
                            }
                            .padding(16)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: messages.count) { _, _ in scrollToEnd(proxy) }
                        .onChange(of: thinking) { _, _ in scrollToEnd(proxy) }
                        .onAppear { scrollToEnd(proxy) }
                    }
                    inputBar(pet: pet, state: s)
                }
                .screenBackground()
                .navigationTitle("和 \(pet.name) 聊天")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            NavigationLink { AISettingsView() } label: { Label("AI 设置", systemImage: "key") }
                            Button("清空聊天记录", systemImage: "trash", role: .destructive) {
                                messages = []; PetChatStore.delete(petID)
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                .alert("把聊天内容发送给 AI 服务？", isPresented: Binding(get: { pendingConsent != nil }, set: { if !$0 { pendingConsent = nil } })) {
                    Button("同意并继续") {
                        if let h = pendingConsent { ai.grantConsent(for: h) }
                        pendingConsent = nil
                        respond(pet: pet, state: s)
                    }
                    Button("这次用小脑袋", role: .cancel) {
                        pendingConsent = nil
                        offlineReply(pet: pet, state: s)
                    }
                } message: {
                    Text("你的消息和宠物的名字、性格、状态会发送到你设置的服务商（\(pendingConsent ?? "")）生成回复，按你在那里的账号计费。BetterHalf 不会保存或查看这些内容。")
                }
                .onAppear { if messages.isEmpty { messages = PetChatStore.load(petID) } }
            }
        }
    }

    // MARK: pieces

    private func header(_ pet: Pet) -> some View {
        HStack(spacing: 10) {
            PetSprite(pet: pet, sleeping: pet.mood() == .sleeping).frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pet.name) · \(pet.mood().label) \(pet.mood().emoji)").font(.subheadline.bold())
                if ai.chatReady, let e = ai.chat {
                    Label("AI · \(AIPresets.chat.first { $0.id == e.presetID }?.name ?? e.host)", systemImage: "sparkles")
                        .font(.caption).foregroundStyle(Theme.pink)
                } else {
                    NavigationLink { AISettingsView() } label: {
                        Label("离线小脑袋 · 设置 AI 让 TA 更聪明", systemImage: "brain")
                            .font(.caption)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.card)
    }

    private func bubble(_ m: AIChatMessage, pet: Pet) -> some View {
        let mine = m.role == "user"
        return HStack(alignment: .bottom, spacing: 6) {
            if mine { Spacer(minLength: 40) } else { Text(pet.species).font(.title3) }
            Text(m.content)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .foregroundStyle(mine ? .white : .primary)
                .background(mine ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.card),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .textSelection(.enabled)
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var typing: some View {
        HStack {
            SwiftUI.TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                HStack(spacing: 4) {
                    ForEach(0..<3) { i in
                        Circle().fill(Color.secondary).frame(width: 7, height: 7)
                            .opacity(0.3 + 0.7 * max(0, sin(t * 5 - Double(i) * 0.8)))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Theme.card, in: Capsule())
            Spacer()
        }
        .padding(.leading, 30)
    }

    private func inputBar(pet: Pet, state: SpaceState) -> some View {
        VStack(spacing: 8) {
            if messages.count < 2 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) { draft = s; send(pet: pet, state: state) }
                                .font(.footnote).padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Theme.pinkSoft, in: Capsule()).foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            HStack(spacing: 8) {
                TextField("说点什么…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onSubmit { send(pet: pet, state: state) }
                Button { send(pet: pet, state: state) } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thinking)
                .accessibilityLabel("发送")
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(Theme.card)
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if thinking { proxy.scrollTo("typing", anchor: .bottom) } else if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    // MARK: actions

    private func send(pet: Pet, state: SpaceState) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return }
        draft = ""
        notice = nil
        messages.append(AIChatMessage(role: "user", content: String(text.prefix(500))))
        PetChatStore.save(petID, messages)
        store.update { $0.applyPet(.pet, id: petID) } // chatting counts as attention
        if ai.chatReady, let e = ai.chat, !ai.hasConsent(for: e.host) {
            pendingConsent = e.host
            return
        }
        respond(pet: pet, state: state)
    }

    private func respond(pet: Pet, state: SpaceState) {
        guard ai.chatReady, let endpoint = ai.chat else { offlineReply(pet: pet, state: state); return }
        thinking = true
        let history = messages
        Task {
            do {
                let reply = try await AIClient.chat(system: PetBrain.systemPrompt(pet: pet, me: state.me, partner: state.partner),
                                                    history: history, endpoint: endpoint, key: ai.key(.chat))
                append(AIChatMessage(role: "assistant", content: reply, fromAI: true))
            } catch {
                notice = "AI 暂时连不上（\(error.localizedDescription)），先用小脑袋回复你"
                append(AIChatMessage(role: "assistant", content: PetBrain.reply(to: history.last?.content ?? "", pet: pet,
                                                                                 me: state.me, partner: state.partner, turn: history.count)))
            }
            thinking = false
        }
    }

    private func offlineReply(pet: Pet, state: SpaceState) {
        thinking = true
        let last = messages.last?.content ?? ""
        let turn = messages.count
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 0.5...1.1)) {
            append(AIChatMessage(role: "assistant", content: PetBrain.reply(to: last, pet: pet, me: state.me, partner: state.partner, turn: turn)))
            thinking = false
        }
    }

    private func append(_ m: AIChatMessage) {
        withAnimation(.spring(response: 0.3)) { messages.append(m) }
        PetChatStore.save(petID, messages)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
