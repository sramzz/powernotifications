import SwiftUI

struct PromptEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialText: String
    let onSave: @MainActor (String) async throws -> Void

    @State private var text: String
    @State private var validationMessage: String?
    @State private var isSaving = false

    init(
        title: String,
        initialText: String = "",
        onSave: @escaping @MainActor (String) async throws -> Void
    ) {
        self.title = title
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Prompt") {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Prompt text")

                    HStack {
                        if let validationMessage {
                            Text(validationMessage)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        Text("\(text.count)/\(PromptTextValidator.maximumLength)")
                            .foregroundStyle(text.count > PromptTextValidator.maximumLength ? .red : .secondary)
                    }
                    .font(.caption)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        do {
            let validated = try PromptTextValidator.validate(text)
            validationMessage = nil
            isSaving = true
            defer { isSaving = false }
            try await onSave(validated)
            dismiss()
        } catch PromptValidationError.empty {
            validationMessage = "Enter a prompt."
        } catch PromptValidationError.tooLong {
            validationMessage = "Keep the prompt to 280 characters."
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
