import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Environment(ScheduleManager.self) private var scheduleManager
    @Environment(PromptViewModel.self) private var promptViewModel
    @Environment(PromptCatalogInstaller.self) private var catalogInstaller
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
            await installCatalogAndReconcile()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await reconcileCurrentPrompts()
            }
        }
        .alert(
            "Starter Prompts Added",
            isPresented: Binding(
                get: { catalogInstaller.noticeMessage != nil },
                set: { if !$0 { catalogInstaller.dismissNotice() } }
            )
        ) {
            Button("OK") { catalogInstaller.dismissNotice() }
        } message: {
            Text(catalogInstaller.noticeMessage ?? "")
        }
    }

    private func installCatalogAndReconcile() async {
        do {
            try await catalogInstaller.installIfNeeded()
        } catch {
            AppLogger.lifecycle.error("Starter catalog installation failed: \(error.localizedDescription, privacy: .public)")
        }
        await reconcileCurrentPrompts()
    }

    private func reconcileCurrentPrompts() async {
        let currentPrompts = (try? promptViewModel.snapshots()) ?? prompts.map(\.snapshot)
        await scheduleManager.reconcile(prompts: currentPrompts)
    }
}
