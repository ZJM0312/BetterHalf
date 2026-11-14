import SwiftUI

/// Entry animation: two hearts drift in from either side, meet in the middle and become one,
/// beat twice, then the app opens up behind them. Personalised with your names and day count,
/// with a little extra celebration on milestone days and anniversaries. Tap anywhere to skip.
struct SplashView: View {
    let state: SpaceState?
    var onLeaving: () -> Void = {}
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.start
    @State private var beat: CGFloat = 1
    @State private var ripple = false
    @State private var shownDays = 0
    @State private var leaving = false
    @State private var finished = false

    private enum Phase: Int, Comparable {
        case start, approach, merged, titled
        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    private var days: Int {
        guard let s = state else { return 0 }
        return DateKit.daysBetween(s.startDate, DateKit.key()) + 1
    }

    /// Something special about today, if anything.
    private var occasion: String? {
        guard let s = state else { return nil }
        if [100, 200, 300, 365, 500, 520, 666, 730, 999, 1000, 1314, 1500, 2000].contains(days) || (days > 0 && days % 1000 == 0) {
            return "今天是我们的第 \(days) 天 🎉"
        }
        let today = DateKit.key()
        let all = s.anniversaries + [Anniversary(id: "_start", name: "在一起纪念日", date: s.startDate, yearly: true)]
        if let a = all.first(where: { DateKit.daysUntil($0, today: today) == 0 && $0.date != today }) {
            return "今天是\(a.name) 💝"
        }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Theme.gradient.ignoresSafeArea()
                FloatingHearts().opacity(phase >= .approach ? 0.9 : 0)

                // Expanding rings when the hearts meet
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(.white.opacity(0.55), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ripple ? 3.2 + CGFloat(i) : 0.6)
                        .opacity(phase < .merged ? 0 : (ripple ? 0 : 0.8))
                        .animation(.easeOut(duration: 1.2).delay(Double(i) * 0.18), value: ripple)
                }
                .offset(y: -40)

                VStack(spacing: 26) {
                    ZStack {
                        // Two hearts approaching…
                        if phase < .merged {
                            heart(size: 54, color: .white.opacity(0.95))
                                .offset(x: phase >= .approach ? -14 : -w * 0.42, y: phase >= .approach ? 0 : -30)
                                .rotationEffect(.degrees(phase >= .approach ? -8 : -30))
                            heart(size: 46, color: Color(red: 1, green: 0.88, blue: 0.92))
                                .offset(x: phase >= .approach ? 14 : w * 0.42, y: phase >= .approach ? 4 : 30)
                                .rotationEffect(.degrees(phase >= .approach ? 8 : 30))
                        }
                        // …become one.
                        if phase >= .merged {
                            ZStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 112))
                                    .foregroundStyle(.white)
                                    .shadow(color: Color(red: 0.6, green: 0.2, blue: 0.45).opacity(0.35), radius: 24, y: 10)
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 112))
                                    .foregroundStyle(Theme.gradient)
                                    .mask(LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                            }
                            .scaleEffect(beat)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                            Sparkles(active: phase >= .merged)
                        }
                    }
                    .frame(height: 140)
                    .offset(y: -40)

                    if phase >= .titled { titles.transition(.move(edge: .bottom).combined(with: .opacity)) }
                }
            }
            .scaleEffect(leaving ? 1.25 : 1)
            .opacity(leaving ? 0 : 1)
            .blur(radius: leaving ? 12 : 0)
        }
        .contentShape(Rectangle())
        .statusBarHidden(true)
        .onTapGesture { finish() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("BetterHalf")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("轻点跳过")
        .task { await run() }
    }

    private func heart(size: CGFloat, color: Color) -> some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private var titles: some View {
        VStack(spacing: 10) {
            Text("BetterHalf")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            if let s = state {
                Text("\(s.me)  ♥  \(s.partner)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("在一起第").font(.subheadline)
                    Text("\(shownDays)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(shownDays)))
                    Text("天").font(.subheadline)
                }
                .foregroundStyle(.white)
                if let o = occasion {
                    Text(o)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(.white.opacity(0.22), in: Capsule())
                        .foregroundStyle(.white)
                }
            } else {
                Text("两个人的小宇宙").font(.headline).foregroundStyle(.white.opacity(0.95))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    // MARK: timeline

    private func run() async {
        if reduceMotion {
            phase = .merged
            phase = .titled
            shownDays = days
            try? await Task.sleep(for: .seconds(1.2))
            finish()
            return
        }
        let soft = UIImpactFeedbackGenerator(style: .soft)
        soft.prepare()
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { phase = .approach }
        try? await Task.sleep(for: .seconds(0.65))

        withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { phase = .merged }
        try? await Task.sleep(for: .seconds(0.04))
        ripple = true
        soft.impactOccurred(intensity: 0.9)
        // Heartbeat: lub-dub
        for (scale, wait) in [(1.16, 0.12), (1.0, 0.12), (1.1, 0.10), (1.0, 0.2)] as [(CGFloat, Double)] {
            withAnimation(.easeInOut(duration: wait)) { beat = scale }
            if scale > 1 { soft.impactOccurred(intensity: scale > 1.12 ? 0.8 : 0.5) }
            try? await Task.sleep(for: .seconds(wait))
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = .titled }
        await countUp()
        try? await Task.sleep(for: .seconds(occasion == nil ? 0.7 : 1.3))
        finish()
    }

    /// Rolls the day counter up to today's number (eases out at the end).
    private func countUp() async {
        let target = days
        guard target > 0 else { return }
        let steps = min(target, 18)
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let eased = 1 - pow(1 - t, 3)
            withAnimation(.snappy(duration: 0.08)) { shownDays = max(1, Int(Double(target) * eased)) }
            try? await Task.sleep(for: .seconds(0.035))
        }
        shownDays = target
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onLeaving()
        withAnimation(.easeIn(duration: 0.45)) { leaving = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onFinish() }
    }
}

/// Little white sparkles bursting from the merged heart.
private struct Sparkles: View {
    let active: Bool
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let angle = Double(i) / 10 * 2 * .pi + 0.3
                Image(systemName: i % 3 == 0 ? "heart.fill" : "sparkle")
                    .font(.system(size: i % 2 == 0 ? 14 : 10, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: go ? cos(angle) * 110 : 0, y: go ? sin(angle) * 95 : 0)
                    .scaleEffect(go ? 1 : 0.2)
                    .opacity(go ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
    }
}

/// Soft hearts drifting upward in the background.
private struct FloatingHearts: View {
    @State private var seeds: [(x: CGFloat, size: CGFloat, speed: Double, offset: Double)] =
        (0..<14).map { _ in (CGFloat.random(in: 0...1), CGFloat.random(in: 8...22), Double.random(in: 0.06...0.14), Double.random(in: 0...1)) }

    var body: some View {
        GeometryReader { geo in
            SwiftUI.TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(seeds.indices, id: \.self) { i in
                        let s = seeds[i]
                        let p = (t * s.speed + s.offset).truncatingRemainder(dividingBy: 1)
                        Image(systemName: "heart.fill")
                            .font(.system(size: s.size))
                            .foregroundStyle(.white.opacity(0.18 + 0.12 * sin(p * .pi)))
                            .position(x: s.x * geo.size.width + sin(t + Double(i)) * 10,
                                      y: geo.size.height * (1.05 - p * 1.15))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
