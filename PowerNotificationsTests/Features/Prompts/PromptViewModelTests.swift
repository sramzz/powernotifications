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

    @Test("A prompt batch preserves IDs and duplicate text while refreshing once")
    func createsBatchAndRefreshesOnce() async throws {
        let harness = try makeHarness(deliveryEnabled: true)
        let firstID = UUID()
        let secondID = UUID()

        try await harness.viewModel.createMany([
            PromptDraft(id: firstID, text: "  Breathe  "),
            PromptDraft(id: secondID, text: "Breathe")
        ])

        #expect(try harness.viewModel.snapshots() == [
            PromptSnapshot(id: firstID, text: "Breathe"),
            PromptSnapshot(id: secondID, text: "Breathe")
        ])
        #expect(harness.scheduler.replaceCount == 1)
    }

    @Test("A batch validates fully before inserting anything")
    func rejectsWholeInvalidBatch() async throws {
        let harness = try makeHarness(deliveryEnabled: true)

        await #expect(throws: PromptValidationError.empty) {
            try await harness.viewModel.createMany([
                PromptDraft(text: "Valid"),
                PromptDraft(text: "  ")
            ])
        }

        #expect(try harness.context.fetchCount(FetchDescriptor<Prompt>()) == 0)
        #expect(harness.scheduler.replaceCount == 0)
    }

    @Test("A failed batch save is attempted once and rolled back")
    func rollsBackFailedBatchSave() async throws {
        let saveSpy = SaveSpy()
        let harness = try makeHarness(deliveryEnabled: true) {
            saveSpy.callCount += 1
            throw TestSaveError.failed
        }

        await #expect(throws: TestSaveError.failed) {
            try await harness.viewModel.createMany([PromptDraft(text: "Valid")])
        }

        #expect(saveSpy.callCount == 1)
        #expect(try harness.context.fetchCount(FetchDescriptor<Prompt>()) == 0)
        #expect(harness.scheduler.replaceCount == 0)
    }

    private func makeHarness(
        deliveryEnabled: Bool,
        save: (() throws -> Void)? = nil
    ) throws -> PromptHarness {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Prompt.self, configurations: configuration)
        let preferences = SchedulePreferences(defaults: makeDefaults())
        preferences.deliveryEnabled = deliveryEnabled
        let scheduler = PromptViewModelNotificationScheduler()
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)
        let viewModel = PromptViewModel(
            modelContext: container.mainContext,
            scheduleManager: manager,
            save: save
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
private final class SaveSpy {
    var callCount = 0
}

private enum TestSaveError: Error {
    case failed
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
    var replaceCount = 0

    func authorizationStatus() async -> NotificationAuthorizationState { .authorized }
    func requestAuthorization() async throws {}
    func replaceSchedule(with slots: [ScheduledSlot]) async throws {
        replaceCount += 1
        scheduledSlots = slots
    }
    func cancelSchedule() async { scheduledSlots = [] }
    func pendingSlots(wakeMinute: Int) async -> [ScheduledSlot] { scheduledSlots }
}
