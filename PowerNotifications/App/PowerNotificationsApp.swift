import SwiftUI
import SwiftData

@main
struct PowerNotificationsApp: App {
    private let modelContainer: ModelContainer
    @State private var preferences: SchedulePreferences
    @State private var router: AppRouter
    @State private var scheduleManager: ScheduleManager
    @State private var promptViewModel: PromptViewModel
    @State private var onboardingViewModel: OnboardingViewModel

    init() {
        let preferences = SchedulePreferences()
        let router = AppRouter()
        let scheduler = SystemNotificationScheduler()
        scheduler.onNotificationResponse = { [weak router] payload in
            router?.openNotification(payload)
        }

        let container: ModelContainer
        do {
            container = try ModelContainer(for: Prompt.self)
        } catch {
            fatalError("Unable to create prompt store: \(error.localizedDescription)")
        }
        modelContainer = container

        let scheduleManager = ScheduleManager(
            preferences: preferences,
            scheduler: scheduler
        )

        _preferences = State(initialValue: preferences)
        _router = State(initialValue: router)
        _scheduleManager = State(initialValue: scheduleManager)
        let promptViewModel = PromptViewModel(
            modelContext: container.mainContext,
            scheduleManager: scheduleManager
        )
        _promptViewModel = State(initialValue: promptViewModel)
        _onboardingViewModel = State(
            initialValue: OnboardingViewModel(
                preferences: preferences,
                promptViewModel: promptViewModel,
                scheduleManager: scheduleManager
            )
        )
        AppLogger.lifecycle.info("PowerNotifications launched")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(preferences)
                .environment(router)
                .environment(scheduleManager)
                .environment(promptViewModel)
                .environment(onboardingViewModel)
        }
        .modelContainer(modelContainer)
    }
}
