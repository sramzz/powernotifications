import Foundation
import SwiftData

@MainActor
enum PromptStore {
    static func snapshots(in context: ModelContext) throws -> [PromptSnapshot] {
        let descriptor = FetchDescriptor<Prompt>(
            sortBy: [SortDescriptor(\Prompt.createdAt)]
        )
        return try context.fetch(descriptor).map(\.snapshot)
    }
}

enum PromptDeletionPolicy {
    static func canDelete(promptCount: Int, deliveryEnabled: Bool) -> Bool {
        !deliveryEnabled || promptCount > 1
    }
}
