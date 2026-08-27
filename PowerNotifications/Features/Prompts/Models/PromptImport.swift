import Foundation

struct PromptImportDocument: Decodable, Equatable {
    let schemaVersion: Int
    let name: String?
    let prompts: [PromptImportItem]
}

struct PromptImportItem: Decodable, Equatable {
    let text: String
}

struct PromptImportEntry: Equatable, Identifiable {
    let index: Int
    let text: String

    var id: Int { index }
}

struct InvalidPromptImportEntry: Equatable, Identifiable {
    let index: Int
    let text: String
    let reason: String

    var id: Int { index }
}

struct PromptImportPreview: Equatable {
    let name: String?
    let validEntries: [PromptImportEntry]
    let invalidEntries: [InvalidPromptImportEntry]
}

enum PromptImportDocumentError: LocalizedError, Equatable {
    case malformed
    case unsupportedVersion(Int)
    case empty
    case tooMany(maximum: Int)

    var errorDescription: String? {
        switch self {
        case .malformed:
            return "The file does not match the PowerNotifications JSON format."
        case .unsupportedVersion(let version):
            return "Schema version \(version) is not supported."
        case .empty:
            return "The file contains no prompts."
        case .tooMany(let maximum):
            return "A file can contain at most \(maximum) prompts."
        }
    }
}

enum PromptImportParser {
    static let supportedVersion = 1
    static let maximumPrompts = 1_000

    static func parse(_ data: Data) throws -> PromptImportPreview {
        let document: PromptImportDocument
        do {
            document = try JSONDecoder().decode(PromptImportDocument.self, from: data)
        } catch {
            throw PromptImportDocumentError.malformed
        }

        guard document.schemaVersion == supportedVersion else {
            throw PromptImportDocumentError.unsupportedVersion(document.schemaVersion)
        }
        guard !document.prompts.isEmpty else {
            throw PromptImportDocumentError.empty
        }
        guard document.prompts.count <= maximumPrompts else {
            throw PromptImportDocumentError.tooMany(maximum: maximumPrompts)
        }

        var validEntries: [PromptImportEntry] = []
        var invalidEntries: [InvalidPromptImportEntry] = []
        for (offset, item) in document.prompts.enumerated() {
            do {
                validEntries.append(PromptImportEntry(
                    index: offset + 1,
                    text: try PromptTextValidator.validate(item.text)
                ))
            } catch PromptValidationError.empty {
                invalidEntries.append(InvalidPromptImportEntry(
                    index: offset + 1,
                    text: item.text,
                    reason: "Prompt text is blank."
                ))
            } catch {
                invalidEntries.append(InvalidPromptImportEntry(
                    index: offset + 1,
                    text: item.text,
                    reason: "Prompt text exceeds 280 characters."
                ))
            }
        }

        return PromptImportPreview(
            name: document.name,
            validEntries: validEntries,
            invalidEntries: invalidEntries
        )
    }
}
