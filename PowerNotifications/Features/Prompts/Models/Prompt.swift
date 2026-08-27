import Foundation
import SwiftData

struct PromptDraft: Equatable, Sendable {
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

@Model
final class Prompt {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(text: String, at date: Date = .now) throws {
        self.text = try PromptTextValidator.validate(text)
        updatedAt = date
    }

    var snapshot: PromptSnapshot {
        PromptSnapshot(id: id, text: text)
    }
}
