import Foundation
import SwiftData
import Testing
@testable import PowerNotifications

@Suite("Prompt import view model")
@MainActor
struct PromptImportViewModelTests {
    @Test("Confirmation imports valid entries once and reports skipped entries")
    func importsPreview() async throws {
        let harness = try makeHarness(deliveryEnabled: true)
        try harness.importer.prepare(Data("""
        {"schemaVersion":1,"prompts":[
          {"text":"Same"}, {"text":"Same"}, {"text":" "}
        ]}
        """.utf8))

        await harness.importer.importValidPrompts()

        #expect(try harness.promptViewModel.snapshots().map(\.text) == ["Same", "Same"])
        #expect(harness.scheduler.replaceCount == 1)
        #expect(harness.importer.preview == nil)
        #expect(harness.importer.resultMessage == "Imported 2 prompts; skipped 1.")
    }

    @Test("Persistence failure keeps the preview available for retry")
    func keepsPreviewAfterFailure() async throws {
        let harness = try makeHarness(deliveryEnabled: false, save: { throw ImportSaveError.failed })
        try harness.importer.prepare(Data("""
        {"schemaVersion":1,"prompts":[{"text":"Retry me"}]}
        """.utf8))

        await harness.importer.importValidPrompts()

        #expect(harness.importer.preview?.validEntries.map(\.text) == ["Retry me"])
        #expect(harness.importer.errorMessage == "The prompts could not be saved. Please retry.")
        #expect(try harness.context.fetchCount(FetchDescriptor<Prompt>()) == 0)
    }

    @Test("A file-picker failure clears a stale preview")
    func clearsPreviewAfterSelectionFailure() throws {
        let harness = try makeHarness(deliveryEnabled: false)
        try harness.importer.prepare(Data("""
        {"schemaVersion":1,"prompts":[{"text":"Old file"}]}
        """.utf8))

        harness.importer.setFileSelectionError(ImportSelectionError.cancelled)

        #expect(harness.importer.preview == nil)
        #expect(harness.importer.errorMessage == "Selection failed.")
    }

    private func makeHarness(
        deliveryEnabled: Bool,
        save: (() throws -> Void)? = nil
    ) throws -> ImportHarness {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Prompt.self, configurations: configuration)
        let defaults = UserDefaults(suiteName: "PromptImportViewModelTests-\(UUID().uuidString)")!
        let preferences = SchedulePreferences(defaults: defaults)
        preferences.deliveryEnabled = deliveryEnabled
        let scheduler = ImportNotificationScheduler()
        let manager = ScheduleManager(preferences: preferences, scheduler: scheduler)
        let promptViewModel = PromptViewModel(
            modelContext: container.mainContext,
            scheduleManager: manager,
            save: save
        )
        return ImportHarness(
            container: container,
            context: container.mainContext,
            scheduler: scheduler,
            promptViewModel: promptViewModel,
            importer: PromptImportViewModel(promptViewModel: promptViewModel)
        )
    }
}

private enum ImportSaveError: Error {
    case failed
}

private enum ImportSelectionError: LocalizedError {
    case cancelled

    var errorDescription: String? { "Selection failed." }
}

@MainActor
private struct ImportHarness {
    let container: ModelContainer
    let context: ModelContext
    let scheduler: ImportNotificationScheduler
    let promptViewModel: PromptViewModel
    let importer: PromptImportViewModel
}

@MainActor
private final class ImportNotificationScheduler: NotificationScheduling {
    var slots: [ScheduledSlot] = []
    var replaceCount = 0

    func authorizationStatus() async -> NotificationAuthorizationState { .authorized }
    func requestAuthorization() async throws {}
    func replaceSchedule(with slots: [ScheduledSlot]) async throws {
        replaceCount += 1
        self.slots = slots
    }
    func cancelSchedule() async { slots = [] }
    func pendingSlots(wakeMinute: Int) async -> [ScheduledSlot] { slots }
}
