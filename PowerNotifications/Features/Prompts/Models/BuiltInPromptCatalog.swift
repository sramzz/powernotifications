import Foundation

struct BuiltInPromptEntry: Equatable, Sendable {
    let id: UUID
    let text: String
    let introducedInVersion: Int
}

struct BuiltInPromptCatalog: Equatable, Sendable {
    let currentVersion: Int
    let entries: [BuiltInPromptEntry]

    static let current = BuiltInPromptCatalog(
        currentVersion: 1,
        entries: [
            BuiltInPromptEntry(
                id: UUID(uuidString: "213434CC-1CB2-4547-9A10-AF3781086C43")!,
                text: "What matters most right now?",
                introducedInVersion: 1
            ),
            BuiltInPromptEntry(
                id: UUID(uuidString: "8A7C52E6-C16B-4F1A-8B51-F364939C99D9")!,
                text: "Relax your shoulders.",
                introducedInVersion: 1
            ),
            BuiltInPromptEntry(
                id: UUID(uuidString: "23E4F2CB-8D7A-4D5C-955E-F2DF43C5CB9B")!,
                text: "What are you avoiding?",
                introducedInVersion: 1
            ),
            BuiltInPromptEntry(
                id: UUID(uuidString: "8C291F56-A90B-4D35-93B2-6743E1A3B142")!,
                text: "Take three slow breaths.",
                introducedInVersion: 1
            )
        ]
    )
}
