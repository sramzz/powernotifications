import SwiftData
import SwiftUI

struct PromptListView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PromptViewModel.self) private var promptViewModel
    @Environment(SchedulePreferences.self) private var preferences
    @Query(sort: \Prompt.createdAt) private var prompts: [Prompt]

    @State private var showingCreate = false
    @State private var promptToDelete: Prompt?
    @State private var message: String?

    var body: some View {
        List {
            if prompts.isEmpty {
                ContentUnavailableView(
                    "No Prompts",
                    systemImage: "text.bubble",
                    description: Text("Create a prompt to include it in your daily pattern.")
                )
            } else {
                ForEach(prompts) { prompt in
                    Button {
                        router.openPrompt(id: prompt.id, fallbackText: prompt.text)
                    } label: {
                        Text(prompt.text)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            requestDeletion(of: prompt)
                        }
                    }
                }
            }
        }
        .navigationTitle("Prompts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Prompt", systemImage: "plus") {
                    showingCreate = true
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            PromptEditorView(title: "New Prompt") { text in
                try await promptViewModel.create(text: text)
            }
        }
        .alert("Delete Prompt?", isPresented: deletionConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deletePrompt() }
            }
            Button("Cancel", role: .cancel) { promptToDelete = nil }
        } message: {
            Text("This removes the prompt from future notification patterns.")
        }
        .alert("Unable to Continue", isPresented: messagePresented) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var deletionConfirmation: Binding<Bool> {
        Binding(
            get: { promptToDelete != nil },
            set: { if !$0 { promptToDelete = nil } }
        )
    }

    private var messagePresented: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }

    private func requestDeletion(of prompt: Prompt) {
        guard PromptDeletionPolicy.canDelete(
            promptCount: prompts.count,
            deliveryEnabled: preferences.deliveryEnabled
        ) else {
            message = "Turn off delivery or add another prompt before deleting the last prompt."
            return
        }
        promptToDelete = prompt
    }

    private func deletePrompt() async {
        guard let promptToDelete else { return }
        self.promptToDelete = nil
        do {
            try await promptViewModel.delete(
                promptToDelete,
                promptCount: prompts.count,
                deliveryEnabled: preferences.deliveryEnabled
            )
        } catch {
            message = error.localizedDescription
        }
    }
}
