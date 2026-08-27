import Foundation
import SwiftData
import Testing
@testable import PowerNotifications

@Suite("Built-in prompt catalog")
@MainActor
struct BuiltInPromptCatalogTests {
    @Test("Version one installs once and exposes a one-time notice")
    func installsVersionOneOnce() async throws {
        let harness = try makeHarness()

        try await harness.installer.installIfNeeded()

        #expect(harness.preferences.appliedVersion == 1)
        #expect(try harness.promptViewModel.snapshots().map(\.text) == BuiltInPromptCatalog.current.entries.map(\.text))
        #expect(harness.installer.noticeMessage == "4 editable starter prompts were added.")
        harness.installer.dismissNotice()
        #expect(harness.installer.noticeMessage == nil)

        try await harness.installer.installIfNeeded()
        #expect(try harness.context.fetchCount(FetchDescriptor<Prompt>()) == 4)
    }

    @Test("Stable IDs recover a save-before-preference crash without duplicates")
    func recoversFromInterruptedInstall() async throws {
        let harness = try makeHarness()
        let first = BuiltInPromptCatalog.current.entries[0]
        harness.context.insert(Prompt(id: first.id, text: first.text))
        try harness.context.save()

        try await harness.installer.installIfNeeded()
        #expect(try harness.context.fetchCount(FetchDescriptor<Prompt>()) == 4)
        #expect(harness.preferences.appliedVersion == 1)
    }

    @Test("Deleting a seeded prompt does not restore it")
    func deletionIsPermanent() async throws {
        let harness = try makeHarness()
        try await harness.installer.installIfNeeded()
        let prompt = try #require(harness.context.fetch(FetchDescriptor<Prompt>()).first)
        harness.context.delete(prompt)
        try harness.context.save()

        try await harness.installer.installIfNeeded()
        #expect(try harness.context.fetchCount(FetchDescriptor<Prompt>()) == 3)
    }

    @Test("A later catalog installs only its version delta")
    func installsVersionDelta() async throws {
        let added = BuiltInPromptEntry(
            id: UUID(uuidString: "9F75EA96-643E-4455-B25E-D27A2237278E")!,
            text: "Look outside.",
            introducedInVersion: 2
        )
        let catalog = BuiltInPromptCatalog(
            currentVersion: 2,
            entries: BuiltInPromptCatalog.current.entries + [added]
        )
        let harness = try makeHarness(catalog: catalog, appliedVersion: 1)

        try await harness.installer.installIfNeeded()
        #expect(try harness.promptViewModel.snapshots().map(\.text) == ["Look outside."])
        #expect(harness.preferences.appliedVersion == 2)
    }

    private func makeHarness(
        catalog: BuiltInPromptCatalog = .current,
        appliedVersion: Int = 0
    ) throws -> CatalogHarness {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Prompt.self, configurations: configuration)
        let defaults = makeDefaults()
        let schedulePreferences = SchedulePreferences(defaults: defaults)
        let scheduler = CatalogNotificationScheduler()
        let manager = ScheduleManager(preferences: schedulePreferences, scheduler: scheduler)
        let promptViewModel = PromptViewModel(modelContext: container.mainContext, scheduleManager: manager)
        let preferences = PromptCatalogPreferences(defaults: defaults)
        preferences.appliedVersion = appliedVersion
        let installer = PromptCatalogInstaller(
            preferences: preferences,
            promptViewModel: promptViewModel,
            catalog: catalog
        )
        return CatalogHarness(
            container: container,
            context: container.mainContext,
            preferences: preferences,
            promptViewModel: promptViewModel,
            installer: installer
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "BuiltInPromptCatalogTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private struct CatalogHarness {
    let container: ModelContainer
    let context: ModelContext
    let preferences: PromptCatalogPreferences
    let promptViewModel: PromptViewModel
    let installer: PromptCatalogInstaller
}

@MainActor
private final class CatalogNotificationScheduler: NotificationScheduling {
    func authorizationStatus() async -> NotificationAuthorizationState { .authorized }
    func requestAuthorization() async throws {}
    func replaceSchedule(with slots: [ScheduledSlot]) async throws {}
    func cancelSchedule() async {}
    func pendingSlots(wakeMinute: Int) async -> [ScheduledSlot] { [] }
}
