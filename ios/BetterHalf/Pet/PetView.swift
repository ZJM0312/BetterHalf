import SwiftUI

struct PetView: View {
    @Environment(SpaceStore.self) private var store
    @State private var selectedID: String?
    @State private var editor: EditorTarget?
    @State private var chatPetID: String?
    @State private var toDelete: Pet?
    @AppStorage("petWidgetTipDismissed") private var tipDismissed = false

    private enum EditorTarget: Identifiable {
        case add, edit(Pet)
        var id: String { if case .edit(let p) = self { return p.id }; return "add" }
    }

    var body: some View {
        NavigationStack {
            if let s = store.state {
                let pets = s.petList
                let pet = pets.first { $0.id == selectedID } ?? pets.first
                ScrollView {
                    VStack(spacing: 14) {
                        if pets.count > 1 { picker(pets, current: pet) }
                        if let pet {
                            PetCard(pet: pet, me: s.me, partner: s.partner,
                                    onAction: { action in store.update { $0.applyPet(action, id: pet.id) } },
                                    onChat: { chatPetID = pet.id })
                            PetWishCard(pet: pet, me: s.me, partner: s.partner) {
                                updatePet(pet.id) { p in
                                    p.affection += 3
                                    p.wishClaimed = ((p.wishClaimed ?? []) + [DateKit.key()]).suffix(60).map { $0 }
                                }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                            PetNoteCard(pet: pet, me: s.me, partner: s.partner) { text in
                                updatePet(pet.id) { $0.note = PetNote(text: text, from: s.me) }
                            }
                            PetCareLogCard(pet: pet, me: s.me, partner: s.partner)
                            PetWardrobeCard(pet: pet) { a in updatePet(pet.id) { $0.accessory = a } }
                            if pet.personality == nil { personalityHint(pet) }
                            if !tipDismissed { widgetTip }
                        } else {
                            emptyState
                        }
                    }
                    .padding(16)
                }
                .screenBackground()
                .navigationTitle("我们的宠物")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { editor = .add } label: { Image(systemName: "plus") }.accessibilityLabel("添加宠物")
                    }
                    if let pet {
                        ToolbarItem(placement: .topBarLeading) {
                            Menu {
                                Button("编辑 \(pet.name)", systemImage: "pencil") { editor = .edit(pet) }
                                NavigationLink { AISettingsView() } label: { Label("AI 设置", systemImage: "key") }
                                Button("删除 \(pet.name)", systemImage: "trash", role: .destructive) { toDelete = pet }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
                }
                .sheet(item: $editor) { target in
                    switch target {
                    case .add: PetEditorSheet { selectedID = $0 }
                    case .edit(let p): PetEditorSheet(pet: p)
                    }
                }
                .sheet(item: Binding(get: { chatPetID.map(ChatTarget.init) }, set: { chatPetID = $0?.id })) { t in
                    PetChatView(petID: t.id)
                }
                .confirmationDialog("删除这只宠物？", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                    titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        if let p = toDelete { PetChatStore.delete(p.id); store.deletePet(p); selectedID = nil }
                    }
                } message: { Text("TA 的形象、亲密度和聊天记录都会被删除。") }
            }
        }
    }

    private struct ChatTarget: Identifiable { let id: String }

    private func updatePet(_ id: String, _ body: @escaping (inout Pet) -> Void) {
        store.update { s in
            guard var list = s.pets, let i = list.firstIndex(where: { $0.id == id }) else { return }
            body(&list[i])
            s.pets = list
        }
    }

    private func picker(_ pets: [Pet], current: Pet?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pets) { p in
                    let on = p.id == current?.id
                    Button { withAnimation(.spring) { selectedID = p.id } } label: {
                        Text("\(p.species) \(p.name)").font(.subheadline)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .foregroundStyle(on ? .white : .primary)
                            .background(on ? Theme.pink : Theme.card, in: Capsule())
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🐾").font(.system(size: 64))
            Text("把你们的毛孩子带进来").font(.title3.bold())
            Text("上传一张照片，自动抠出 TA 的样子，变成会动、会撒娇、会饿肚子的小宠物。\n还可以和 TA 聊天，放到桌面和锁屏上随时摸摸。")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("添加宠物") { editor = .add }.buttonStyle(PrimaryButtonStyle())
            Text("还没有养宠物？也可以用 AI 生成一只「云宠物」").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
        .card()
    }

    private func personalityHint(_ pet: Pet) -> some View {
        Button { editor = .edit(pet) } label: {
            HStack(spacing: 10) {
                Text("💡").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("给 \(pet.name) 设置性格").font(.subheadline.bold()).foregroundStyle(.primary)
                    Text("粘人、高冷还是吃货？TA 聊天时会更像 TA 自己").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .card()
        }
    }

    private var widgetTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("📱").font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text("把 TA 放到桌面和锁屏").font(.subheadline.bold())
                Text("长按桌面空白处 → 左上角「编辑」→「添加小组件」→ 搜索 BetterHalf → 选择「我们的宠物」。小组件上也能直接喂食、摸摸。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { tipDismissed = true } label: { Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary) }
                .accessibilityLabel("不再提示")
        }
        .card(Theme.pinkSoft)
    }
}

/// The animated stage + stats + action buttons.
private struct PetCard: View {
    let pet: Pet
    let me: String
    let partner: String
    let onAction: (PetAction) -> Void
    let onChat: () -> Void

    @State private var hop: CGFloat = 0
    @State private var spin: Double = 0
    @State private var particles: [Particle] = []
    @State private var bubble: String?
    @State private var food = false
    @State private var levelUp: Int?
    @State private var shownLevel: Int?

    var body: some View {
        let now = Date()
        let mood = pet.mood(at: now)
        VStack(spacing: 16) {
            ZStack {
                PetStageBackground(date: now)
                Ellipse().fill(.black.opacity(0.10)).frame(width: 140, height: 18).offset(y: 112)
                PetSprite(pet: pet, sleeping: mood == .sleeping, idleMoves: true)
                    .frame(height: 210)
                    .offset(y: hop)
                    .rotationEffect(.degrees(spin))
                    .onTapGesture { perform(.pet) }
                    .onLongPressGesture(minimumDuration: 0.5) { cuddle() }
                    .accessibilityLabel("\(pet.name)，\(mood.label)。点一下摸摸")
                    .accessibilityAddTraits(.isButton)
                if food {
                    Text("🍖").font(.system(size: 44)).transition(.move(edge: .top).combined(with: .opacity)).offset(y: -40)
                }
                ForEach(particles) { p in FloatingParticle(p: p) }
                VStack {
                    SpeechBubble(text: bubble ?? pet.speech(me: me, partner: partner, at: now))
                        .id(bubble ?? pet.speech(me: me, partner: partner, at: now))
                        .transition(.scale.combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 12)
                if let lv = levelUp {
                    VStack(spacing: 4) {
                        Text("🎉").font(.system(size: 44))
                        Text("亲密度升到 Lv.\(lv) 啦！").font(.headline)
                        Text("\(pet.name)更喜欢你们了").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 300)
            .clipped()

            HStack {
                Text("\(pet.species) \(pet.name)").font(.title2.bold())
                Text("Lv.\(pet.level)").font(.caption.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.pink, in: Capsule())
                Spacer()
                Text("\(mood.label) \(mood.emoji)").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text("「\(pet.levelTitle)」").font(.caption.weight(.semibold)).foregroundStyle(Theme.pink)
                if let p = pet.personality { Text("性格：\(p)").font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                Spacer()
            }
            VStack(spacing: 8) {
                StatBar(icon: "🍖", title: "饱腹", value: pet.fullness(at: now), color: .orange)
                StatBar(icon: "💗", title: "心情", value: pet.happiness(at: now), color: Theme.pink)
                StatBar(icon: "✨", title: "亲密度", value: pet.levelProgress, color: .purple, trailing: "\(pet.affection)")
            }
            HStack(spacing: 10) {
                ForEach(PetAction.allCases, id: \.self) { a in
                    Button { perform(a) } label: {
                        VStack(spacing: 4) {
                            Text(a.emoji).font(.title2)
                            Text(a.title).font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .foregroundStyle(.primary)
                }
            }
            Button(action: onChat) {
                Label("和 \(pet.name) 聊天", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .card()
        .onAppear { shownLevel = pet.level }
        .onChange(of: pet.id) { _, _ in shownLevel = pet.level }
        .onChange(of: pet.level) { old, new in
            guard let shown = shownLevel, new > shown else { shownLevel = new; return }
            shownLevel = new
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            burst(["🎉", "✨", "💖", "⭐️"], count: 12)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { levelUp = new }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { withAnimation { levelUp = nil } }
        }
    }

    private func perform(_ action: PetAction) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        onAction(action)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { bubble = action.reaction }
        switch action {
        case .pet:
            burst(["❤️", "💕", "💗"], count: 6)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) { hop = -28 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { hop = 0 } }
        case .feed:
            withAnimation(.easeIn(duration: 0.35)) { food = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.2)) { food = false }
                burst(["😋", "✨"], count: 4)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.3).repeatCount(3, autoreverses: true)) { hop = -10 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation(.spring) { hop = 0 } }
            }
        case .play:
            burst(["⭐️", "🎾", "✨"], count: 6)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { hop = -60 }
            withAnimation(.easeInOut(duration: 0.7)) { spin += 360 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { hop = 0 } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { bubble = nil } }
    }

    /// Long-press: a slow cuddle with a gentle haptic heartbeat.
    private func cuddle() {
        let gen = UIImpactFeedbackGenerator(style: .soft)
        for i in 0..<4 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) { gen.impactOccurred(intensity: 0.6) } }
        onAction(.pet)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { bubble = "蹭蹭～最喜欢你了 🥰" }
        burst(["💞", "🥰", "💗"], count: 10)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { bubble = nil } }
    }

    private func burst(_ emojis: [String], count: Int) {
        let new = (0..<count).map { _ in Particle(emoji: emojis.randomElement()!, dx: .random(in: -110...110), delay: .random(in: 0...0.25)) }
        particles.append(contentsOf: new)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            particles.removeAll { p in new.contains { $0.id == p.id } }
        }
    }
}

/// Idle animation: breathing, bobbing, and (on the main stage) small random behaviours —
/// an occasional happy hop and turning to look the other way.
struct PetSprite: View {
    let pet: Pet
    var sleeping = false
    var idleMoves = false
    @State private var seed = Double.random(in: 0...100)

    var body: some View {
        SwiftUI.TimelineView(.animation) { ctx in
            let raw = ctx.date.timeIntervalSinceReferenceDate + seed
            let t = raw * (sleeping ? 0.5 : 1)
            let breathe = 1 + sin(t * 2.4) * (sleeping ? 0.025 : 0.018)
            let bob = sleeping ? 0 : sin(t * 1.6) * 5
            let tilt = sleeping ? -4 : sin(t * 0.9) * 3
            // Every ~11s a quick double hop; every ~17s turn around smoothly.
            let hopPhase = raw.truncatingRemainder(dividingBy: 11)
            let hop = (idleMoves && !sleeping && hopPhase < 0.8) ? -abs(sin(hopPhase / 0.8 * .pi * 2)) * 16 : 0
            let facing = (idleMoves && !sleeping) ? CGFloat(tanh(sin(raw * 2 * .pi / 34) * 6)) : 1
            ZStack(alignment: .topTrailing) {
                image
                    .scaleEffect(x: (2 - breathe) * (abs(facing) < 0.15 ? 0.15 * (facing < 0 ? -1 : 1) : facing), y: breathe, anchor: .bottom)
                    .rotationEffect(.degrees(tilt), anchor: .bottom)
                    .offset(y: bob + hop)
                    .saturation(sleeping ? 0.6 : 1)
                if sleeping {
                    Text("💤").font(.title).offset(x: 10, y: -10 + sin(t * 2) * 6).opacity(0.6 + sin(t * 2) * 0.4)
                }
            }
            .overlay(alignment: .top) {
                if let a = pet.accessory {
                    Text(a).font(.system(size: 44)).offset(y: bob + hop - 6).rotationEffect(.degrees(tilt))
                }
            }
        }
    }

    @ViewBuilder
    private var image: some View {
        if let f = pet.imageFile, let img = UIImage(contentsOfFile: SharedContainer.mediaURL(f).path) {
            Image(uiImage: img).resizable().scaledToFit().shadow(color: .black.opacity(0.15), radius: 8, y: 6)
        } else {
            Text(pet.species).font(.system(size: 130)).minimumScaleFactor(0.2)
        }
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let emoji: String
    let dx: CGFloat
    let delay: Double
}

private struct FloatingParticle: View {
    let p: Particle
    @State private var go = false
    var body: some View {
        Text(p.emoji).font(.title)
            .offset(x: go ? p.dx : p.dx * 0.2, y: go ? -150 : 0)
            .opacity(go ? 0 : 1)
            .scaleEffect(go ? 1.3 : 0.6)
            .onAppear { withAnimation(.easeOut(duration: 1.3).delay(p.delay)) { go = true } }
    }
}

private struct SpeechBubble: View {
    let text: String
    var body: some View {
        Text(text).font(.subheadline)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.card, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            .padding(.horizontal, 16)
    }
}

private struct StatBar: View {
    let icon: String
    let title: String
    let value: Double
    let color: Color
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 42, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: max(6, g.size.width * value))
                }
            }
            .frame(height: 8)
            Text(trailing ?? "\(Int(value * 100))%").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
        .animation(.spring, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(trailing ?? "\(Int(value * 100))%")")
    }
}
