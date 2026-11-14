import SwiftUI

struct DecideView: View {
    @Environment(SpaceStore.self) private var store
    @State private var activeID: String?
    @State private var newOption = ""
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var result: String?

    var body: some View {
        Group {
            if let s = store.state {
                let list = s.decisions.first { $0.id == activeID } ?? s.decisions.first
                ScrollView {
                    VStack(spacing: 14) {
                        presets(s, current: list)
                        if let list { wheelCard(list) }
                    }
                    .padding(16)
                }
                .screenBackground()
            }
        }
    }

    private func presets(_ s: SpaceState, current: DecisionList?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Catalog.decisionPresets, id: \.name) { p in
                    let on = current?.name == p.name
                    Button(p.name) { select(preset: p, in: s) }
                        .font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .foregroundStyle(on ? .white : .primary)
                        .background(on ? Theme.pink : Theme.card, in: Capsule())
                }
            }
        }
    }

    private func wheelCard(_ list: DecisionList) -> some View {
        let n = list.options.count
        return VStack(spacing: 14) {
            Text(list.name).font(.headline)
            ZStack(alignment: .top) {
                Wheel(options: list.options)
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
            FlowChips(items: list.options) { i in
                store.update { s in
                    if let idx = s.decisions.firstIndex(where: { $0.id == list.id }) { s.decisions[idx].options.remove(at: i) }
                }
                result = nil
            }
            HStack {
                TextField("加个选项（最多 12 个）", text: $newOption)
                    .padding(12).background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
                    .onSubmit { add(to: list) }
                Button("添加") { add(to: list) }
                    .disabled(newOption.trimmingCharacters(in: .whitespaces).isEmpty || n >= 12)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func select(preset p: (name: String, options: [String]), in s: SpaceState) {
        result = nil
        if let existing = s.decisions.first(where: { $0.name == p.name }) { activeID = existing.id; return }
        let d = DecisionList(name: p.name, options: p.options)
        store.update { $0.decisions.append(d) }
        activeID = d.id
    }

    private func add(to list: DecisionList) {
        let t = String(newOption.trimmingCharacters(in: .whitespaces).prefix(8))
        guard !t.isEmpty, list.options.count < 12 else { return }
        store.update { s in
            if let idx = s.decisions.firstIndex(where: { $0.id == list.id }) { s.decisions[idx].options.append(t) }
        }
        newOption = ""
    }

    /// Segment i spans [i*seg, (i+1)*seg] clockwise from 12 o'clock; land its center under the pointer.
    private func spin(_ list: DecisionList) {
        let n = list.options.count
        guard n >= 2, !spinning else { return }
        let idx = Int.random(in: 0..<n)
        let seg = 360.0 / Double(n)
        let base = rotation - rotation.truncatingRemainder(dividingBy: 360)
        let target = base + 360 * 6 + (360 - (Double(idx) * seg + seg / 2))
        result = nil
        spinning = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.timingCurve(0.17, 0.67, 0.2, 1, duration: 3.2)) { rotation = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            spinning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring) { result = list.options[idx] }
        }
    }
}

private struct Wheel: View {
    let options: [String]
    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            let n = max(options.count, 1)
            let seg = 360.0 / Double(n)
            ZStack {
                ForEach(options.indices, id: \.self) { i in
                    Slice(start: .degrees(Double(i) * seg - 90), end: .degrees(Double(i + 1) * seg - 90))
                        .fill(Theme.wheel[i % Theme.wheel.count])
                    Text(options[i])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0.19))
                        .offset(y: -r * 0.62)
                        .rotationEffect(.degrees((Double(i) + 0.5) * seg))
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

/// Wrapping row of removable option chips.
struct FlowChips: View {
    let items: [String]
    let onRemove: (Int) -> Void
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    Text(items[i]).font(.footnote)
                    Button { onRemove(i) } label: { Image(systemName: "xmark").font(.caption2.bold()) }
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("删除 \(items[i])")
                }
                .padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 5)
                .background(Theme.pinkSoft, in: Capsule())
            }
        }
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
