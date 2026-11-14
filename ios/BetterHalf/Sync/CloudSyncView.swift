import CloudKit
import SwiftUI

/// "异地同步": invite the partner into a private iCloud share; afterwards everything syncs by itself.
struct CloudSyncView: View {
    @Environment(CloudSync.self) private var cloud
    @Environment(SpaceStore.self) private var store
    @State private var share: CKShare?
    @State private var preparing = false
    @State private var confirmStop = false
    @State private var notifyOn = Reminders.isEnabled

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                explainer
                if CloudSync.isEnabled { statusCard } else { unavailableCard }
                howItWorks
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle("异地同步")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cloud.refresh() }
        .sheet(item: Binding(get: { share.map(ShareBox.init) }, set: { if $0 == nil { share = nil } })) { box in
            CloudSharingSheet(share: box.share, container: cloud.cloudContainer) {
                share = nil
                Task { await cloud.refresh() }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("停止异地同步？", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("停止同步", role: .destructive) { Task { await cloud.stopSharing() } }
        } message: {
            Text("两部手机上的数据都会保留，只是之后不再自动同步。")
        }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.and.arrow.up.fill").font(.title).foregroundStyle(Theme.pink)
            VStack(alignment: .leading, spacing: 4) {
                Text("不在身边也能实时同步").font(.headline)
                Text("用你们各自的 iCloud 建一个只属于两个人的私密共享空间。回忆、每日一问、宠物、清单都会自动同步，TA 回答了问题、记录了回忆、让宠物带话，你会马上收到通知。BetterHalf 没有服务器，看不到你们的任何数据。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch cloud.status {
            case .disabled:
                EmptyView()
            case .noAccount:
                Label("这台 iPhone 还没有登录 iCloud", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.subheadline.weight(.semibold))
                Text("打开「设置」→ 顶部登录 Apple 账户，并确认 iCloud 已开启，再回来这里。").font(.footnote).foregroundStyle(.secondary)
            case .notPaired:
                Text("还没有连接").font(.subheadline.weight(.semibold))
                Text("由你们其中一个人发出邀请，另一个人在 iPhone 上点开邀请链接即可加入。").font(.footnote).foregroundStyle(.secondary)
                Button {
                    Task { await invite() }
                } label: {
                    HStack { if preparing { ProgressView().tint(.white) }; Text("邀请 \(store.state?.partner ?? "TA") 加入") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(preparing)
            case .waitingForPartner:
                Label("邀请已发出，等 \(store.state?.partner ?? "TA") 点开链接", systemImage: "hourglass")
                    .font(.subheadline.weight(.semibold))
                Text("TA 需要先在自己的 iPhone 上装好 BetterHalf。可以再发一次，或者在下方管理邀请。").font(.footnote).foregroundStyle(.secondary)
                Button("再次发送 / 管理邀请") { Task { await invite() } }.buttonStyle(PrimaryButtonStyle())
                stopButton
            case .paired:
                Label("已和 \(store.state?.partner ?? "TA") 连接", systemImage: "checkmark.icloud.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                if let t = cloud.lastSyncedAt {
                    Text("上次同步 \(t.formatted(.relative(presentation: .named)))").font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    Task { await cloud.fetch() }
                } label: {
                    HStack { if cloud.busy { ProgressView() }; Text("立即同步") }
                }
                Button("给 TA 发「想你了」💕") { store.sendPoke(.miss) }
                if !notifyOn {
                    Button("开启通知，TA 有更新马上知道") {
                        Task { notifyOn = await Reminders.requestAndEnable(for: store.state) }
                    }
                    .font(.footnote)
                }
                stopButton
            }
            if let e = cloud.lastError { Text(e).font(.footnote).foregroundStyle(.orange) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var stopButton: some View {
        Button("停止异地同步", role: .destructive) { confirmStop = true }.font(.footnote)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("当前安装的版本还不支持异地同步", systemImage: "info.circle").font(.subheadline.weight(.semibold))
            Text("异地同步用到 iCloud 和推送，需要从 App Store / TestFlight 安装的正式版。现在可以先用「面对面同步」：两部手机靠近就能同步。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "两个人同时编辑会怎样？")
            Label("回忆的正文以最后一次修改为准，卡片上会写明谁改的", systemImage: "pencil.line")
            Label("「补充一句」和添加的照片互不覆盖，两人同时加也都会保留", systemImage: "text.bubble")
            Label("删除会同步给对方，不会被另一台手机又同步回来", systemImage: "trash")
            Label("每日一问各写各的，两人都答完才能开宝箱", systemImage: "gift")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func invite() async {
        preparing = true
        defer { preparing = false }
        do {
            share = try await cloud.prepareShare()
        } catch {
            cloud.lastError = "创建邀请失败：\(error.localizedDescription)"
        }
    }
}

private struct ShareBox: Identifiable {
    let share: CKShare
    var id: ObjectIdentifier { ObjectIdentifier(share) }
}

/// System iCloud sharing sheet (invite via Messages / Mail / copy link, manage participants).
private struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let c = UICloudSharingController(share: share, container: container)
        c.availablePermissions = [.allowPrivate, .allowReadWrite]
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func itemTitle(for csc: UICloudSharingController) -> String? { "我们的 BetterHalf" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) { onDone() }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { onDone() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onDone() }
    }
}
