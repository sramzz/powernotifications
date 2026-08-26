import Foundation
import SwiftData
import Testing
@testable import PowerNotifications

@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {
    @Test("First-run onboarding validates a prompt and enables a persisted schedule")
    func completesFirstRun() async throws {
        let harness = try makeHarness()

        harness.viewModel.continueFromWelcome(hasPrompts: false)
        #expect(harness.viewModel.step == .prompt)

        harness.viewModel.promptText = "   "
        await harness.viewModel.saveFirstPrompt()
        #expect(harness.viewModel.promptError == "Enter a prompt.")
        #expect(harness.viewModel.step == .prompt)

        harness.viewModel.promptText = "Notice what is good"
        await harness.viewModel.saveFirstPrompt()
        #expect(harness.viewModel.step == .schedule)

        await harness.viewModel.finishSetup()

        #expect(harness.preferences.onboardingCompleted)
        #expect(harness.preferences.deliveryEnabled)
        #expect(harness.scheduler.scheduledSlots.count == 3)
        #expect(try harness.context.fetchCount(FetchDescriptor<Prompt>()) == 1)
    }

    @Test("A returning user skips prompt creation")
    func skipsPromptForExistingUser() throws {
        let harness = try makeHarness()

        harness.viewModel.continueFromWelcome(hasPrompts: true)

        #expect(harness.viewModel.step == .schedule)
    }

    private func makeHarness() throws -> OnboardingHarness {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Prompt.self, configurations: configuration)
        let preferences = SchedulePreferences(defaults: makeDefaults())
        let scheduler = OnboardingNotificationScheduler()
        let scheduleManager = ScheduleManager(preferences: preferences, scheduler: scheduler)
        let promptViewModel = PromptViewModel(
            modelContext: container.mainContext,
            scheduleManager: scheduleManager
        )
        let viewModel = OnboardingViewModel(
            preferences: preferences,
            promptViewModel: promptViewModel,
            scheduleManager: scheduleManager
        )
        return OnboardingHarness(
            container: container,
            context: container.mainContext,
            preferences: preferences,
            scheduler: scheduler,
            viewModel: viewModel
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OnboardingViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private struct OnboardingHarness {
    let container: ModelContainer
    let context: ModelContext
    let preferences: SchedulePreferences
    let scheduler: OnboardingNotificationScheduler
    let viewModel: OnboardingViewModel
}

@MainActor
private final class OnboardingNotificationScheduler: NotificationScheduling {
    var scheduledSlots: [ScheduledSlot] = []

    func authorizationStatus() async -> NotificationAuthorizationState { .authorized }
    func requestAuthorization() async throws {}
    func replaceSchedule(with slots: [ScheduledSlot]) async throws { scheduledSlots = slots }
    func cancelSchedule() async { scheduledSlots = [] }
    func pendingSlots(wakeMinute: Int) async -> [ScheduledSlot] { scheduledSlots }
}
