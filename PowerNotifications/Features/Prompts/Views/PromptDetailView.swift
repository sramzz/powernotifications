import SwiftData
import SwiftUI

struct PromptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PromptViewModel.self) private var promptViewModel
    @Environment(SchedulePreferences.self) private var preferences
    @Query(sort: \Prompt.createdAt) private var prompts: [Prompt]

    let promptID: UUID
    let fallbackText: String

    @State private var showingEdit = false
    @State private var showingDelete = false
    @State private var message: String?

    private var prompt: Prompt? {
        prompts.first { $0.id == promptID }
    }

    var body: some View {
        Group {
            if let prompt {
                List {
                    Section("Prompt") {
                        Text(prompt.text)
                            .textSelection(.enabled)
                    }
                    Section("Details") {
                        LabeledContent("Created", value: prompt.createdAt.formatted())
                        LabeledContent("Updated", value: prompt.updatedAt.formatted())
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Edit") { showingEdit = true }
                        Button("Delete", role: .destructive) { requestDeletion() }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Prompt Deleted", systemImage: "trash")
                } description: {
                    Text("This is the text captured when the notification was scheduled.")
                } actions: {
                    Text(fallbackText)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                }
                .padding()
            }
        }
        .navigationTitle("Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            if let prompt {
                PromptEditorView(
                    title: "Edit Prompt",
                    initialText: prompt.text
                ) { text in
                    try await promptViewModel.update(prompt, text: text)
                }
            }
        }
        .alert("Delete Prompt?", isPresented: $showingDelete) {
            Button("Delete", role: .destructive) {
                Task { await deletePrompt() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the prompt from future notification patterns.")
        }
        .alert("Unable to Continue", isPresented: messagePresented) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var messagePresented: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }

    private func requestDeletion() {
        guard PromptDeletionPolicy.canDelete(
            promptCount: prompts.count,
            deliveryEnabled: preferences.deliveryEnabled
        ) else {
            message = "Turn off delivery or add another prompt before deleting the last prompt."
            return
        }
        showingDelete = true
    }

    private func deletePrompt() async {
        guard let prompt else { return }
        do {
            try await promptViewModel.delete(
                prompt,
                promptCount: prompts.count,
                deliveryEnabled: preferences.deliveryEnabled
            )
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
