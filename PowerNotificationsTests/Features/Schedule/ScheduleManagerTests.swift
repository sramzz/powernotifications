import Foundation
import Testing
@testable import PowerNotifications

@Suite("ScheduleManager")
@MainActor
struct ScheduleManagerTests {
    @Test("Enabling an authorized schedule creates the daily pattern")
    func enablesAuthorizedSchedule() async {
        let preferences = makePreferences()
        let scheduler = FakeNotificationScheduler()
        scheduler.authorization = .authorized
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)
        let prompts = [PromptSnapshot(id: UUID(), text: "Breathe")]

        await manager.setDeliveryEnabled(true, prompts: prompts)

        #expect(preferences.deliveryEnabled)
        #expect(scheduler.scheduledSlots.count == 3)
        #expect(manager.slots.count == 3)
    }

    @Test("Denied authorization keeps delivery disabled")
    func rejectsDeniedAuthorization() async {
        let preferences = makePreferences()
        let scheduler = FakeNotificationScheduler()
        scheduler.authorization = .denied
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)

        await manager.setDeliveryEnabled(
            true,
            prompts: [PromptSnapshot(id: UUID(), text: "Breathe")]
        )

        #expect(!preferences.deliveryEnabled)
        #expect(scheduler.scheduledSlots.isEmpty)
        #expect(manager.errorMessage != nil)
    }

    @Test("A failed replacement cancels partial work and disables delivery")
    func rollsBackFailedReplacement() async {
        let preferences = makePreferences()
        let scheduler = FakeNotificationScheduler()
        scheduler.authorization = .authorized
        scheduler.replaceError = TestError.failed
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)

        await manager.setDeliveryEnabled(
            true,
            prompts: [PromptSnapshot(id: UUID(), text: "Breathe")]
        )

        #expect(!preferences.deliveryEnabled)
        #expect(scheduler.cancelCount == 1)
        #expect(manager.errorMessage != nil)
    }

    @Test("Reconciliation rebuilds an incomplete enabled pattern")
    func reconcilesMissingRequests() async {
        let preferences = makePreferences()
        preferences.deliveryEnabled = true
        let scheduler = FakeNotificationScheduler()
        scheduler.authorization = .authorized
        scheduler.scheduledSlots = []
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)

        await manager.reconcile(
            prompts: [PromptSnapshot(id: UUID(), text: "Breathe")]
        )

        #expect(preferences.deliveryEnabled)
        #expect(scheduler.scheduledSlots.count == 3)
    }

    @Test("Disabling delivery cancels requests but preserves schedule settings")
    func disablesDelivery() async {
        let preferences = makePreferences()
        preferences.deliveryEnabled = true
        preferences.dailyCount = 7
        let scheduler = FakeNotificationScheduler()
        scheduler.authorization = .authorized
        scheduler.scheduledSlots = [makeSlot()]
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)

        await manager.setDeliveryEnabled(false, prompts: [])

        #expect(!preferences.deliveryEnabled)
        #expect(preferences.dailyCount == 7)
        #expect(scheduler.cancelCount == 1)
        #expect(scheduler.scheduledSlots.isEmpty)
    }

    @Test("Saving an enabled schedule replaces it with the new count")
    func replacesPatternAfterSave() async {
        let preferences = makePreferences()
        preferences.deliveryEnabled = true
        let scheduler = FakeNotificationScheduler()
        scheduler.authorization = .authorized
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)

        await manager.saveSchedule(
            count: 5,
            wakeMinute: 480,
            bedtimeMinute: 1_320,
            prompts: [PromptSnapshot(id: UUID(), text: "Breathe")]
        )

        #expect(preferences.dailyCount == 5)
        #expect(scheduler.scheduledSlots.count == 5)
    }

    @Test("Revoked authorization cancels an enabled pattern")
    func disablesAfterAuthorizationRevocation() async {
        let preferences = makePreferences()
        preferences.deliveryEnabled = true
        let scheduler = FakeNotificationScheduler()
        scheduler.authorization = .denied
        scheduler.scheduledSlots = [makeSlot()]
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)

        await manager.reconcile(
            prompts: [PromptSnapshot(id: UUID(), text: "Breathe")]
        )

        #expect(!preferences.deliveryEnabled)
        #expect(scheduler.cancelCount == 1)
        #expect(manager.errorMessage != nil)
    }

    @Test("Reconciliation replaces same-count slots with stale prompt content")
    func replacesStalePromptContent() async {
        let preferences = makePreferences()
        preferences.deliveryEnabled = true
        let scheduler = FakeNotificationScheduler()
        scheduler.authorization = .authorized
        scheduler.scheduledSlots = (0..<3).map { index in
            ScheduledSlot(
                minuteOffset: index * 60,
                minuteOfDay: 480 + index * 60,
                promptID: UUID(),
                promptText: "Deleted prompt",
                configuration: defaultConfiguration
            )
        }
        let currentID = UUID()
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)

        await manager.reconcile(
            prompts: [PromptSnapshot(id: currentID, text: "Current prompt")]
        )

        #expect(scheduler.replaceCount == 1)
        #expect(scheduler.scheduledSlots.allSatisfy { $0.promptID == currentID })
    }

    private func makePreferences() -> SchedulePreferences {
        let suiteName = "ScheduleManagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SchedulePreferences(defaults: defaults)
    }

    private func makeSlot() -> ScheduledSlot {
        ScheduledSlot(
            minuteOffset: 0,
            minuteOfDay: 480,
            promptID: UUID(),
            promptText: "Breathe",
            configuration: defaultConfiguration
        )
    }

    private var defaultConfiguration: ScheduleConfiguration {
        ScheduleConfiguration(count: 3, wakeMinute: 480, bedtimeMinute: 1_320)
    }
}

@MainActor
private final class FakeNotificationScheduler: NotificationScheduling {
    var authorization: NotificationAuthorizationState = .notDetermined
    var scheduledSlots: [ScheduledSlot] = []
    var replaceError: Error?
    var replaceCount = 0
    var cancelCount = 0

    func authorizationStatus() async -> NotificationAuthorizationState {
        authorization
    }

    func requestAuthorization() async throws {
        authorization = .authorized
    }

    func replaceSchedule(with slots: [ScheduledSlot]) async throws {
        if let replaceError { throw replaceError }
        replaceCount += 1
        scheduledSlots = slots
    }

    func cancelSchedule() async {
        cancelCount += 1
        scheduledSlots = []
    }

    func pendingSlots(wakeMinute: Int) async -> [ScheduledSlot] {
        scheduledSlots
    }
}

private enum TestError: Error {
    case failed
}
