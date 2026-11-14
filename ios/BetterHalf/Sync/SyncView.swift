import SwiftUI

/// "和 TA 的手机同步" — nearby discovery, pairing, sync status and the 想你了 nudge.
struct SyncView: View {
    @Environment(SpaceStore.self) private var store
    @Environment(SyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss
    var joinName: String? = nil // set when joining from onboarding (no local space yet)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    explainer
                    statusCard
                    if case .connected = sync.phase { connectedActions } else { peerList }
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("和 TA 的手机同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .onAppear { sync.start(displayName: store.state?.me ?? joinName ?? "TA") }
            .onDisappear { sync.stop() }
            .onChange(of: store.state != nil) { _, has in
                // Joined the partner's space from onboarding.
                if has && joinName != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() } }
            }
            .alert("「\(sync.pendingInvite?.peerName ?? "")」想和你同步",
                   isPresented: Binding(get: { sync.pendingInvite != nil }, set: { if !$0 { sync.pendingInvite = nil } }),
                   presenting: sync.pendingInvite) { invite in
                Button("接受") { invite.respond(true) }
                Button("拒绝", role: .cancel) { invite.respond(false) }
            } message: { _ in
                Text("同步后你们的回忆、纪念日、清单和宠物会合并在一起。只接受你的另一半。")
            }
        }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill").font(.title).foregroundStyle(Theme.pink)
            VStack(alignment: .leading, spacing: 4) {
                Text("点对点 · 只属于你们").font(.headline)
                Text("两部手机打开这个页面并靠近（同一 Wi-Fi 或蓝牙），数据直接加密传输，不经过任何服务器，也不需要注册账号。照片、视频、语音会一起同步。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            statusIcon.font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText).font(.subheadline.weight(.semibold))
                if let t = sync.lastSyncedAt {
                    Label("已同步 · \(t.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                if sync.filesExpected > 0 {
                    ProgressView(value: Double(sync.filesReceived), total: Double(sync.filesExpected)) {
                        Text("正在接收照片/视频 \(sync.filesReceived)/\(sync.filesExpected)").font(.caption)
                    }
                    .tint(Theme.pink)
                }
            }
            Spacer()
        }
        .card()
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch sync.phase {
        case .idle: Image(systemName: "antenna.radiowaves.left.and.right.slash").foregroundStyle(.secondary)
        case .searching: ProgressView()
        case .connecting: ProgressView()
        case .connected: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    private var statusText: String {
        switch sync.phase {
        case .idle: return "未开启"
        case .searching: return sync.isPaired ? "正在寻找 TA 的手机…" : "正在寻找附近的 BetterHalf…"
        case .connecting(let n): return "正在连接 \(n)…"
        case .connected(let n): return "已与 \(n) 同步 ✓"
        case .failed(let msg): return msg
        }
    }

    private var peerList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "附近的设备")
            if sync.peers.isEmpty {
                Text("让 TA 也打开「设置 → 和 TA 的手机同步」").font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
            ForEach(sync.peers, id: \.self) { peer in
                HStack {
                    Image(systemName: "iphone").foregroundStyle(Theme.pink)
                    Text(peer.displayName)
                    Spacer()
                    Button("连接") { sync.connect(to: peer) }.buttonStyle(PrimaryButtonStyle(fullWidth: false))
                }
            }
        }
        .card()
    }

    private var connectedActions: some View {
        VStack(spacing: 12) {
            Button {
                sync.sendNudge()
            } label: {
                Label("发送「想你了」", systemImage: "heart.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("重新同步") { sync.syncAgain() }
            Text("连接期间可以随时互相发送「想你了」，TA 的手机会收到爱心动画和震动。")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .card()
    }
}

/// Full-screen heart burst when the partner sends 想你了.
struct NudgeOverlay: View {
    @Environment(SyncService.self) private var sync
    @State private var visible = false
    @State private var lastSeen = 0

    var body: some View {
        ZStack {
            if visible {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("💕").font(.system(size: 120)).symbolEffect(.bounce, value: sync.nudgeCount)
                    Text("\(sync.nudgeFrom) 想你了").font(.title.bold()).foregroundStyle(.white).shadow(radius: 6)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .allowsHitTesting(visible)
        .onTapGesture { withAnimation { visible = false } }
        .onChange(of: sync.nudgeCount) { _, n in
            guard n != lastSeen else { return }
            lastSeen = n
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { visible = false } }
        }
    }
}
