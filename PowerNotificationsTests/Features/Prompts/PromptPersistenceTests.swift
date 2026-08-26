import Foundation
import SwiftData
import Testing
@testable import PowerNotifications

@Suite("Prompt persistence")
@MainActor
struct PromptPersistenceTests {
    @Test("A prompt survives a SwiftData save and fetch")
    func savesAndFetchesPrompt() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Prompt.self, configurations: configuration)
        let context = container.mainContext
        let prompt = Prompt(text: try PromptTextValidator.validate("Be present"))

        context.insert(prompt)
        try context.save()

        let snapshots = try PromptStore.snapshots(in: context)
        #expect(snapshots == [PromptSnapshot(id: prompt.id, text: "Be present")])
    }

    @Test("The last prompt cannot be deleted while delivery is enabled")
    func protectsLastActivePrompt() {
        #expect(!PromptDeletionPolicy.canDelete(promptCount: 1, deliveryEnabled: true))
        #expect(PromptDeletionPolicy.canDelete(promptCount: 2, deliveryEnabled: true))
        #expect(PromptDeletionPolicy.canDelete(promptCount: 1, deliveryEnabled: false))
    }
}
