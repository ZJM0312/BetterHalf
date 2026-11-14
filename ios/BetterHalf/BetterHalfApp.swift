import SwiftUI

@main
struct BetterHalfApp: App {
    @State private var store = SpaceStore()
    @State private var lock = AppLock()
    @State private var sync = SyncService()
    @State private var ai = AISettings()
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(lock)
                .environment(sync)
                .environment(ai)
                .environment(router)
                .tint(Theme.pink)
                .onAppear { sync.store = store }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: lock.lockIfNeeded()
            case .active: store.reloadFromDisk() // widgets may have fed / petted the pet
            default: break
            }
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
