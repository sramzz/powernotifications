import Foundation
import Observation

@MainActor
@Observable
final class PromptCatalogInstaller {
    private let preferences: PromptCatalogPreferences
    private let promptViewModel: PromptViewModel
    private let catalog: BuiltInPromptCatalog

    private(set) var noticeMessage: String?

    init(
        preferences: PromptCatalogPreferences,
        promptViewModel: PromptViewModel,
        catalog: BuiltInPromptCatalog = .current
    ) {
        self.preferences = preferences
        self.promptViewModel = promptViewModel
        self.catalog = catalog
    }

    func installIfNeeded() async throws {
        guard preferences.appliedVersion < catalog.currentVersion else { return }

        let existingIDs = Set(try promptViewModel.snapshots().map(\.id))
        let additions = catalog.entries.filter {
            $0.introducedInVersion > preferences.appliedVersion && !existingIDs.contains($0.id)
        }

        if !additions.isEmpty {
            try await promptViewModel.createMany(
                additions.map { PromptDraft(id: $0.id, text: $0.text) }
            )
        }

        preferences.appliedVersion = catalog.currentVersion
        if !additions.isEmpty {
            noticeMessage = additions.count == 1
                ? "1 editable starter prompt was added."
                : "\(additions.count) editable starter prompts were added."
        }
        AppLogger.persistence.info("Starter catalog applied; version: \(self.catalog.currentVersion), inserted: \(additions.count)")
    }

    func dismissNotice() {
        noticeMessage = nil
    }
}
