import Foundation
import Testing
@testable import PowerNotifications

@Suite("Prompt JSON import")
struct PromptImportParserTests {
    @Test("Version 1 documents decode with or without a name", arguments: [
        "{\"schemaVersion\":1,\"name\":\"Morning\",\"prompts\":[{\"text\":\"Breathe\"}]}",
        "{\"schemaVersion\":1,\"prompts\":[{\"text\":\"Breathe\"}]}"
    ])
    func decodesVersionOne(_ json: String) throws {
        let preview = try PromptImportParser.parse(Data(json.utf8))

        #expect(preview.validEntries.map(\.text) == ["Breathe"])
        #expect(preview.invalidEntries.isEmpty)
    }

    @Test("Semantic failures are reported while valid duplicate text remains importable")
    func previewsSemanticFailures() throws {
        let oversized = String(repeating: "x", count: 281)
        let json = """
        {"schemaVersion":1,"name":"Mixed","prompts":[
          {"text":"  Same  "},
          {"text":"Same"},
          {"text":"  "},
          {"text":"\(oversized)"}
        ]}
        """

        let preview = try PromptImportParser.parse(Data(json.utf8))

        #expect(preview.name == "Mixed")
        #expect(preview.validEntries.map(\.text) == ["Same", "Same"])
        #expect(preview.invalidEntries.map(\.reason) == [
            "Prompt text is blank.",
            "Prompt text exceeds 280 characters."
        ])
    }

    @Test("Invalid documents are rejected", arguments: [
        ("not json", PromptImportDocumentError.malformed),
        ("{\"schemaVersion\":2,\"prompts\":[{\"text\":\"Hi\"}]}", .unsupportedVersion(2)),
        ("{\"schemaVersion\":1,\"prompts\":[]}", .empty),
        ("{\"schemaVersion\":1,\"prompts\":[{}]}", .malformed)
    ])
    func rejectsInvalidDocuments(_ json: String, _ expected: PromptImportDocumentError) {
        #expect(throws: expected) {
            try PromptImportParser.parse(Data(json.utf8))
        }
    }

    @Test("Documents over one thousand entries are rejected")
    func rejectsOversizedDocument() throws {
        let prompts = Array(repeating: ["text": "Prompt"], count: 1_001)
        let object: [String: Any] = ["schemaVersion": 1, "prompts": prompts]
        let data = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: PromptImportDocumentError.tooMany(maximum: 1_000)) {
            try PromptImportParser.parse(data)
        }
    }
}
