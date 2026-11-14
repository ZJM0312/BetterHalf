import CloudKit
import SwiftUI
import UserNotifications

@main
struct BetterHalfApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var app
    @State private var lock = AppLock()
    @State private var ai = AISettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app.store)
                .environment(lock)
                .environment(app.sync)
                .environment(app.cloud)
                .environment(ai)
                .environment(app.router)
                .tint(Theme.pink)
                .task {
                    // While the app is open, check iCloud now and then as a backup for missed pushes.
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(45))
                        if scenePhase == .active { await app.cloud.fetch() }
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: lock.lockIfNeeded()
            case .active:
                app.store.reloadFromDisk() // widgets may have fed / petted the pet
                Task { await app.cloud.refresh() }
            default: break
            }
        }
    }
}

/// Owns the long-lived models so push notifications and share invites can reach them
/// even when they arrive before any SwiftUI view exists.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private(set) static weak var shared: AppDelegate?
    let store = SpaceStore()
    let sync = SyncService()
    let cloud = CloudSync()
    let router = AppRouter()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Self.shared = self
        if let s = store.state { ChestLedger.migrateIfNeeded(s) }
        UNUserNotificationCenter.current().delegate = self
        sync.store = store
        cloud.store = store
        store.onChange = { [weak self] in self?.cloud.schedulePush() }
        store.onPartnerEvents = { [weak self] events in
            guard let self, let s = self.store.state else { return }
            PartnerNotifier.post(events, state: s)
        }
        if CloudSync.isEnabled {
            application.registerForRemoteNotifications()
            cloud.start()
        }
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    /// Silent push from the CloudKit subscription: the partner changed something.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in completionHandler(await cloud.fetch() ? .newData : .noData) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    // Show partner notifications as banners even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let raw = response.notification.request.content.userInfo["tab"] as? String, let tab = AppTab(rawValue: raw) {
            await MainActor.run { router.tab = tab }
        }
    }
}

/// Receives iCloud share invites (the partner tapped the link) on warm and cold launch.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata { accept(metadata) }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        accept(cloudKitShareMetadata)
    }

    private func accept(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            await AppDelegate.shared?.cloud.accept(metadata)
            AppDelegate.shared?.router.showCloudJoined = true
        }
    }
}

struct RootView: View {
    @Environment(SpaceStore.self) private var store
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if store.state == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
            NudgeOverlay()
            if lock.isEnabled && lock.isLocked && store.state != nil {
                LockScreen().transition(.opacity)
            } else if lock.isEnabled && scenePhase != .active {
                // Hide content in the app switcher.
                Theme.gradient.ignoresSafeArea().overlay(Image(systemName: "heart.fill").font(.largeTitle).foregroundStyle(.white))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
    }
}

enum AppTab: String, Hashable { case home, memories, pet, talk, play }

/// Lets any screen jump to another tab (e.g. the home "今天" card).
@Observable
final class AppRouter {
    var tab: AppTab = .home
    /// Set after accepting the partner's iCloud invite, to show a welcome.
    var showCloudJoined = false
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            TogetherView().tabItem { Label("我们", systemImage: "heart.fill") }.tag(AppTab.home)
            MemoriesView().tabItem { Label("回忆", systemImage: "photo.on.rectangle.angled") }.tag(AppTab.memories)
            PetView().tabItem { Label("宠物", systemImage: "pawprint.fill") }.tag(AppTab.pet)
            TalkView().tabItem { Label("每日一问", systemImage: "bubble.left.and.bubble.right.fill") }.tag(AppTab.talk)
            PlayView().tabItem { Label("一起玩", systemImage: "sparkles") }.tag(AppTab.play)
        }
        .sensoryFeedback(.selection, trigger: router.tab)
        #if DEBUG
        // Screenshot hook: `-BHTab pet` opens a given tab on launch.
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-BHTab"), i + 1 < args.count, let t = AppTab(rawValue: args[i + 1]) { router.tab = t }
        }
        #endif
    }
}

/// 帮我选 + 情侣清单 share one tab (iOS shows at most five).
struct PlayView: View {
    @AppStorage("playTab") private var tab = 0

    var body: some View {
        NavigationStack {
            Group {
                if tab == 0 { DecideView() } else { BucketView() }
            }
            .safeAreaInset(edge: .top) {
                Picker("", selection: $tab) {
                    Text("🎡 帮我选").tag(0)
                    Text("✅ 情侣清单").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.bottom, 4)
                .background(Theme.bg)
            }
            .navigationTitle(tab == 0 ? "帮我选" : "情侣清单")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
