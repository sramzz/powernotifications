import Testing
@testable import PowerNotifications

@Suite("PromptTextValidator")
struct PromptTextValidatorTests {
    @Test("Trims valid multiline prompt text")
    func trimsValidText() throws {
        let validated = try PromptTextValidator.validate("  Pause\nand breathe.  \n")

        #expect(validated == "Pause\nand breathe.")
    }

    @Test("Rejects blank prompt text")
    func rejectsBlankText() {
        #expect(throws: PromptValidationError.empty) {
            try PromptTextValidator.validate(" \n\t ")
        }
    }

    @Test("Rejects prompt text beyond 280 characters")
    func rejectsLongText() {
        #expect(throws: PromptValidationError.tooLong) {
            try PromptTextValidator.validate(String(repeating: "a", count: 281))
        }
    }
}
