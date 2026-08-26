import Foundation
import SwiftData
import Testing
@testable import PowerNotifications

@Suite("PromptViewModel")
@MainActor
struct PromptViewModelTests {
    @Test("Creating a prompt persists trimmed text and refreshes an enabled schedule")
    func createsAndRefreshesSchedule() async throws {
        let harness = try makeHarness(deliveryEnabled: true)

        try await harness.viewModel.create(text: "  Breathe deeply  ")

        let prompts = try harness.context.fetch(FetchDescriptor<Prompt>())
        #expect(prompts.map(\.text) == ["Breathe deeply"])
        #expect(harness.scheduler.scheduledSlots.count == 3)
        #expect(harness.scheduler.scheduledSlots.allSatisfy { $0.promptText == "Breathe deeply" })
    }

    @Test("An invalid prompt is rejected without persistence")
    func rejectsInvalidPrompt() async throws {
        let harness = try makeHarness(deliveryEnabled: false)

        await #expect(throws: PromptValidationError.empty) {
            try await harness.viewModel.create(text: "  \n  ")
        }

        #expect(try harness.context.fetchCount(FetchDescriptor<Prompt>()) == 0)
        #expect(harness.scheduler.scheduledSlots.isEmpty)
    }

    private func makeHarness(deliveryEnabled: Bool) throws -> PromptHarness {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Prompt.self, configurations: configuration)
        let preferences = SchedulePreferences(defaults: makeDefaults())
        preferences.deliveryEnabled = deliveryEnabled
        let scheduler = PromptViewModelNotificationScheduler()
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)
        let viewModel = PromptViewModel(
            modelContext: container.mainContext,
            scheduleManager: manager
        )
        return PromptHarness(
            container: container,
            context: container.mainContext,
            scheduler: scheduler,
            viewModel: viewModel
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "PromptViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private struct PromptHarness {
    let container: ModelContainer
    let context: ModelContext
    let scheduler: PromptViewModelNotificationScheduler
    let viewModel: PromptViewModel
}

@MainActor
private final class PromptViewModelNotificationScheduler: NotificationScheduling {
    var scheduledSlots: [ScheduledSlot] = []

    func authorizationStatus() async -> NotificationAuthorizationState { .authorized }
    func requestAuthorization() async throws {}
    func replaceSchedule(with slots: [ScheduledSlot]) async throws { scheduledSlots = slots }
    func cancelSchedule() async { scheduledSlots = [] }
    func pendingSlots(wakeMinute: Int) async -> [ScheduledSlot] { scheduledSlots }
}
