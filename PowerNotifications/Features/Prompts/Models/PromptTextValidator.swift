import Foundation

enum PromptValidationError: Error, Equatable {
    case empty
    case tooLong
}

enum PromptTextValidator {
    static let maximumLength = 280

    static func validate(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PromptValidationError.empty }
        guard trimmed.count <= maximumLength else { throw PromptValidationError.tooLong }
        return trimmed
    }
}
