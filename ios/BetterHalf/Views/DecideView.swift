import SwiftUI

struct DecideView: View {
    @Environment(SpaceStore.self) private var store
    @State private var activeID: String?
    @State private var newOption = ""
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var result: String?
    @State private var editingList: DecisionList?
    @State private var creating = false
    @State private var editingOption: OptionRef?
    @State private var toDelete: DecisionList?

    var body: some View {
        Group {
            if let s = store.state {
                let list = s.decisions.first { $0.id == activeID } ?? s.decisions.first
                ScrollView {
                    VStack(spacing: 14) {
                        listPicker(s, current: list)
                        if let list { wheelCard(list) } else { EmptyHint(text: "点上面的「＋」建一个转盘吧") }
                        presetSuggestions(s)
                    }
                    .padding(16)
                }
                .screenBackground()
                .sheet(isPresented: $creating) {
                    DecisionListEditor(list: nil) { new in
                        store.update { $0.decisions.append(new) }
                        activeID = new.id; result = nil
                    }
                }
                .sheet(item: $editingList) { l in
                    DecisionListEditor(list: l) { updated in
                        store.update { s in if let i = s.decisions.firstIndex(where: { $0.id == l.id }) { s.decisions[i] = updated } }
                    }
                }
                .sheet(item: $editingOption) { ref in
                    OptionEditor(ref: ref) { newText, weight in
                        updateList(ref.listID) { l in
                            guard let i = l.options.firstIndex(of: ref.text) else { return }
                            let t = String(newText.prefix(12))
                            if t.isEmpty || (t != ref.text && l.options.contains(t)) { return }
                            l.options[i] = t
                            var w = l.weights ?? [:]
                            w[ref.text] = nil
                            w[t] = weight == 1 ? nil : weight
                            l.weights = w.isEmpty ? nil : w
                            l.drawn = l.drawn?.map { $0 == ref.text ? t : $0 }
                        }
                    }
                    .presentationDetents([.height(300)])
                }
                .confirmationDialog("删除「\(toDelete?.name ?? "")」？", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                    titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        if let l = toDelete {
                            store.update { s in s.decisions.removeAll { $0.id == l.id }; s.markDeleted(l.id) }
                            activeID = nil; result = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: lists

    private func listPicker(_ s: SpaceState, current: DecisionList?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(s.decisions) { d in
                    let on = d.id == current?.id
                    Button {
                        activeID = d.id; result = nil
                    } label: {
                        Text("\(d.emoji ?? "🎡") \(d.name)").font(.subheadline)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .foregroundStyle(on ? .white : .primary)
                            .background(on ? Theme.pink : Theme.card, in: Capsule())
                    }
                    .contextMenu {
                        Button("编辑", systemImage: "pencil") { editingList = d }
                        Button("删除", systemImage: "trash", role: .destructive) { toDelete = d }
                    }
                }
                Button { creating = true } label: {
                    Label("新建", systemImage: "plus").font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Theme.card, in: Capsule())
                }
                .accessibilityLabel("新建转盘")
            }
        }
    }

    @ViewBuilder
    private func presetSuggestions(_ s: SpaceState) -> some View {
        let missing = Catalog.decisionPresets.filter { p in !s.decisions.contains { $0.name == p.name } }
        if !missing.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "灵感转盘")
                FlowLayout(spacing: 6) {
                    ForEach(missing, id: \.name) { p in
                        Button("+ \(p.name)") {
                            let d = DecisionList(name: p.name, options: p.options, emoji: Catalog.decisionEmojis.randomElement())
                            store.update { $0.decisions.append(d) }
                            activeID = d.id; result = nil
                        }
                        .font(.footnote)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.bg, in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    // MARK: wheel

    private func wheelCard(_ list: DecisionList) -> some View {
        let n = list.options.count
        let pool = list.available
        return VStack(spacing: 14) {
            HStack {
                Text("\(list.emoji ?? "🎡") \(list.name)").font(.headline)
                Spacer()
                Menu {
                    Button("编辑转盘", systemImage: "pencil") { editingList = list }
                    Button("删除转盘", systemImage: "trash", role: .destructive) { toDelete = list }
                } label: { Image(systemName: "ellipsis.circle").font(.title3) }
            }
            ZStack(alignment: .top) {
                Wheel(options: list.options, weights: list.options.map(list.weight), dimmed: Set(list.options).subtracting(pool))
                    .rotationEffect(.degrees(rotation))
                    .frame(width: 290, height: 290)
                    .padding(.top, 10)
                Image(systemName: "arrowtriangle.down.fill").font(.title).foregroundStyle(Theme.pink)
                    .shadow(radius: 2, y: 1)
            }
            Button(spinning ? "转呀转…" : n < 2 ? "至少添加 2 个选项" : "就听它的！") { spin(list) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(spinning || n < 2)
            if let result {
                (Text("🎉 决定了：") + Text(result).font(.title2.bold()).foregroundColor(Theme.pink))
                    .transition(.scale.combined(with: .opacity))
            }

            Toggle(isOn: Binding(get: { list.noRepeat == true }, set: { on in
                updateList(list.id) { $0.noRepeat = on; $0.drawn = nil }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("不重复模式").font(.subheadline)
                    Text(list.noRepeat == true ? "已抽过 \((list.drawn ?? []).count)/\(n)，抽完一轮自动重来" : "抽过的选项先跳过，适合轮流做家务")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(Theme.pink)
            if list.noRepeat == true, !(list.drawn ?? []).isEmpty {
                Button("重新开始一轮") { updateList(list.id) { $0.drawn = nil } }.font(.footnote)
            }

            FlowLayout(spacing: 6) {
                ForEach(list.options, id: \.self) { o in
                    OptionChip(text: o, weight: list.weight(o), drawn: list.noRepeat == true && (list.drawn ?? []).contains(o)) {
                        editingOption = OptionRef(listID: list.id, text: o, weight: list.weight(o))
                    } onRemove: {
                        updateList(list.id) { l in
                            l.options.removeAll { $0 == o }
                            l.weights?[o] = nil
                            l.drawn?.removeAll { $0 == o }
                        }
                        result = nil
                    }
                }
            }
            Text("点选项可以改名字、调权重（权重越高，扇区越大、越容易抽中）").font(.caption2).foregroundStyle(.tertiary)
            HStack {
                TextField("加选项，可用空格或逗号一次加多个", text: $newOption)
                    .padding(12).background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
                    .onSubmit { add(to: list) }
                Button("添加") { add(to: list) }
                    .disabled(newOption.trimmingCharacters(in: .whitespaces).isEmpty || n >= 16)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func updateList(_ id: String, _ body: (inout DecisionList) -> Void) {
        store.update { s in
            if let i = s.decisions.firstIndex(where: { $0.id == id }) { body(&s.decisions[i]) }
        }
    }

    private func add(to list: DecisionList) {
        let parts = newOption.split(whereSeparator: { " ,，、\n".contains($0) })
            .map { String($0.prefix(12)) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return }
        updateList(list.id) { l in
            for p in parts where !l.options.contains(p) && l.options.count < 16 { l.options.append(p) }
        }
        newOption = ""
    }

    /// Weighted pick among the options still in play; land the chosen slice's center under the pointer.
    private func spin(_ list: DecisionList) {
        let n = list.options.count
        guard n >= 2, !spinning else { return }
        let pool = list.available
        let total = pool.map(list.weight).reduce(0, +)
        var r = Int.random(in: 0..<max(total, 1))
        var pick = pool[0]
        for o in pool { r -= list.weight(o); if r < 0 { pick = o; break } }

        let weights = list.options.map { Double(list.weight($0)) }
        let sum = weights.reduce(0, +)
        let idx = list.options.firstIndex(of: pick) ?? 0
        let startDeg = weights[..<idx].reduce(0, +) / sum * 360
        let center = startDeg + weights[idx] / sum * 180
        let jitter = Double.random(in: -0.3...0.3) * weights[idx] / sum * 360
        let base = rotation - rotation.truncatingRemainder(dividingBy: 360)
        let target = base + 360 * 6 + (360 - center + jitter)
        result = nil
        spinning = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.timingCurve(0.17, 0.67, 0.2, 1, duration: 3.2)) { rotation = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            spinning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring) { result = pick }
            if list.noRepeat == true {
                updateList(list.id) { l in
                    var d = (l.drawn ?? []).filter(l.options.contains)
                    if !d.contains(pick) { d.append(pick) }
                    l.drawn = Set(d).isSuperset(of: l.options) ? nil : d // round complete → start over

                }
            }
        }
    }
}

struct OptionRef: Identifiable {
    let listID: String
    let text: String
    let weight: Int
    var id: String { listID + "|" + text }
}

private struct OptionChip: View {
    let text: String
    let weight: Int
    let drawn: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTap) {
                HStack(spacing: 3) {
                    Text(text).font(.footnote).strikethrough(drawn)
                    if weight > 1 { Text("×\(weight)").font(.caption2.bold()).foregroundStyle(Theme.pink) }
                }
            }
            .foregroundStyle(drawn ? .secondary : .primary)
            Button(action: onRemove) { Image(systemName: "xmark").font(.caption2.bold()) }
                .foregroundStyle(.secondary)
                .accessibilityLabel("删除 \(text)")
        }
        .padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 5)
        .background(Theme.pinkSoft, in: Capsule())
    }
}

private struct OptionEditor: View {
    let ref: OptionRef
    let onSave: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var weight = 1

    var body: some View {
        NavigationStack {
            Form {
                TextField("选项", text: $text)
                Stepper("权重 ×\(weight)", value: $weight, in: 1...5)
                Text("权重 2 = 被抽中的机会是普通选项的 2 倍").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("编辑选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(text.trimmingCharacters(in: .whitespaces), weight); dismiss() }
                }
            }
            .onAppear { text = ref.text; weight = ref.weight }
        }
    }
}

/// Create or edit a wheel: name, icon and options in one place.
private struct DecisionListEditor: View {
    let list: DecisionList?
    let onSave: (DecisionList) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🎡"
    @State private var optionsText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("名字") { TextField("比如：周末早餐吃什么", text: $name) }
                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(Catalog.decisionEmojis, id: \.self) { e in
                            Text(e).font(.title2).frame(width: 40, height: 40)
                                .background(e == emoji ? Theme.pinkSoft : .clear, in: RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { emoji = e }
                        }
                    }
                }
                Section {
                    TextField("每行一个选项", text: $optionsText, axis: .vertical).lineLimit(5...12)
                } header: { Text("选项") } footer: { Text("每行一个，最多 16 个，每个最多 12 个字。") }
            }
            .navigationTitle(list == nil ? "新建转盘" : "编辑转盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var seen = Set<String>()
                        let opts = optionsText.split(whereSeparator: \.isNewline)
                            .map { String($0.trimmingCharacters(in: .whitespaces).prefix(12)) }
                            .filter { !$0.isEmpty && seen.insert($0).inserted }
                            .prefix(16)
                        var l = list ?? DecisionList(name: "", options: [])
                        l.name = String(name.trimmingCharacters(in: .whitespaces).prefix(16))
                        l.emoji = emoji
                        l.options = Array(opts)
                        l.weights = l.weights?.filter { opts.contains($0.key) }
                        l.drawn = l.drawn?.filter { opts.contains($0) }
                        onSave(l)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let list {
                    name = list.name; emoji = list.emoji ?? "🎡"; optionsText = list.options.joined(separator: "\n")
                }
            }
        }
    }
}

private struct Wheel: View {
    let options: [String]
    let weights: [Int]
    var dimmed: Set<String> = []
    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            let total = Double(max(weights.reduce(0, +), 1))
            let starts = weights.indices.map { i in Double(weights[..<i].reduce(0, +)) / total * 360 }
            ZStack {
                ForEach(options.indices, id: \.self) { i in
                    let seg = Double(weights[i]) / total * 360
                    Slice(start: .degrees(starts[i] - 90), end: .degrees(starts[i] + seg - 90))
                        .fill(Theme.wheel[i % Theme.wheel.count].opacity(dimmed.contains(options[i]) ? 0.35 : 1))
                    Text(options[i])
                        .font(.system(size: options.count > 10 ? 11 : 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0.19).opacity(dimmed.contains(options[i]) ? 0.4 : 1))
                        .offset(y: -r * 0.62)
                        .rotationEffect(.degrees(starts[i] + seg / 2))
                }
            }
            .frame(width: r * 2, height: r * 2)
            .overlay(Circle().stroke(Theme.card, lineWidth: 6))
            .clipShape(Circle())
            .shadow(color: Theme.pink.opacity(0.15), radius: 10, y: 4)
        }
    }
}

private struct Slice: Shape {
    let start: Angle, end: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0)))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2 // centered rows
            for i in row.indices {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var cur: [Int] = [], w: CGFloat = 0, h: CGFloat = 0
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let add = cur.isEmpty ? s.width : w + spacing + s.width
            if add > width, !cur.isEmpty { rows.append((cur, w, h)); cur = [i]; w = s.width; h = s.height }
            else { cur.append(i); w = add; h = max(h, s.height) }
        }
        if !cur.isEmpty { rows.append((cur, w, h)) }
        return rows
    }
}
