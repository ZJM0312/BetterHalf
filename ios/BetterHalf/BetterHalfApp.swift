import SwiftUI

@main
struct BetterHalfApp: App {
    @State private var store = SpaceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.pink)
        }
    }
}

struct RootView: View {
    @Environment(SpaceStore.self) private var store

    var body: some View {
        if store.state == nil {
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TogetherView().tabItem { Label("我们", systemImage: "heart.fill") }
            TimelineView().tabItem { Label("回忆", systemImage: "photo.on.rectangle.angled") }
            TalkView().tabItem { Label("每日一问", systemImage: "bubble.left.and.bubble.right.fill") }
            DecideView().tabItem { Label("帮我选", systemImage: "dial.medium.fill") }
            BucketView().tabItem { Label("清单", systemImage: "checklist") }
        }
    }
}
