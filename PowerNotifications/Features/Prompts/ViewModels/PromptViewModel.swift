import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PromptViewModel {
    private let modelContext: ModelContext
    private let scheduleManager: ScheduleManager

    init(modelContext: ModelContext, scheduleManager: ScheduleManager) {
        self.modelContext = modelContext
        self.scheduleManager = scheduleManager
    }

    func snapshots() throws -> [PromptSnapshot] {
        do {
            return try PromptStore.snapshots(in: modelContext)
        } catch {
            AppLogger.persistence.error("Prompt fetch failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func create(text: String) async throws {
        let validated = try PromptTextValidator.validate(text)
        modelContext.insert(Prompt(text: validated))
        try await persistAndRefresh(operation: "created")
    }

    func update(_ prompt: Prompt, text: String) async throws {
        try prompt.update(text: text)
        try await persistAndRefresh(operation: "updated")
    }

    func delete(
        _ prompt: Prompt,
        promptCount: Int,
        deliveryEnabled: Bool
    ) async throws {
        guard PromptDeletionPolicy.canDelete(
            promptCount: promptCount,
            deliveryEnabled: deliveryEnabled
        ) else {
            throw PromptOperationError.cannotDeleteLastActivePrompt
        }

        modelContext.delete(prompt)
        try await persistAndRefresh(operation: "deleted")
    }

    private func persistAndRefresh(operation: String) async throws {
        do {
            let current = try PromptStore.snapshots(in: modelContext)
            try modelContext.save()
            await scheduleManager.promptsDidChange(current)
            AppLogger.persistence.info("Prompt \(operation, privacy: .public); count: \(current.count)")
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error("Prompt \(operation, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

enum PromptOperationError: LocalizedError, Equatable {
    case cannotDeleteLastActivePrompt

    var errorDescription: String? {
        switch self {
        case .cannotDeleteLastActivePrompt:
            return "Turn off delivery or add another prompt before deleting the last prompt."
        }
    }
}
