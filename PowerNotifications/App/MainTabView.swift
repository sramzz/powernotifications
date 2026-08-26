import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Environment(ScheduleManager.self) private var scheduleManager
    @Query(sort: \Prompt.createdAt) private var prompts: [Prompt]

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.promptPath) {
                PromptListView()
                    .navigationDestination(for: PromptRoute.self) { route in
                        switch route {
                        case let .detail(promptID, fallbackText):
                            PromptDetailView(
                                promptID: promptID,
                                fallbackText: fallbackText
                            )
                        }
                    }
            }
            .tabItem { Label("Prompts", systemImage: "text.bubble") }
            .tag(AppTab.prompts)

            NavigationStack {
                ScheduleView()
            }
            .tabItem { Label("Schedule", systemImage: "clock") }
            .tag(AppTab.schedule)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .task {
            await scheduleManager.reconcile(prompts: prompts.map(\.snapshot))
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await scheduleManager.reconcile(prompts: prompts.map(\.snapshot))
            }
        }
    }
}
