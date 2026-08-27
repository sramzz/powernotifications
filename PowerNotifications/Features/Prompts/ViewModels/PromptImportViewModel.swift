import Foundation
import Observation

@MainActor
@Observable
final class PromptImportViewModel {
    private let promptViewModel: PromptViewModel

    private(set) var preview: PromptImportPreview?
    private(set) var isImporting = false
    private(set) var errorMessage: String?
    private(set) var resultMessage: String?

    init(promptViewModel: PromptViewModel) {
        self.promptViewModel = promptViewModel
    }

    func load(_ url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            try prepare(Data(contentsOf: url))
        } catch {
            preview = nil
            resultMessage = nil
            errorMessage = error.localizedDescription
            AppLogger.persistence.error("JSON prompt file read or validation failed")
        }
    }

    func prepare(_ data: Data) throws {
        preview = try PromptImportParser.parse(data)
        errorMessage = nil
        resultMessage = nil
    }

    func importValidPrompts() async {
        guard let preview, !preview.validEntries.isEmpty else { return }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            try await promptViewModel.createMany(
                preview.validEntries.map { PromptDraft(text: $0.text) }
            )
            let imported = preview.validEntries.count
            let skipped = preview.invalidEntries.count
            self.preview = nil
            resultMessage = "Imported \(imported) prompt\(imported == 1 ? "" : "s"); skipped \(skipped)."
            AppLogger.persistence.info("JSON prompt import completed; imported: \(imported), skipped: \(skipped)")
        } catch {
            errorMessage = "The prompts could not be saved. Please retry."
            AppLogger.persistence.error("JSON prompt import failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func dismissResult() {
        resultMessage = nil
    }

    func setFileSelectionError(_ error: Error) {
        preview = nil
        resultMessage = nil
        errorMessage = error.localizedDescription
        AppLogger.persistence.error("JSON prompt file selection failed")
    }
}
