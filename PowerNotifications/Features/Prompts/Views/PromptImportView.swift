import SwiftUI
import UniformTypeIdentifiers

struct PromptImportView: View {
    @Environment(PromptImportViewModel.self) private var viewModel
    @State private var showingFileImporter = false

    var body: some View {
        List {
            Section {
                Button("Choose JSON File", systemImage: "doc.badge.plus") {
                    showingFileImporter = true
                }
            } footer: {
                Text("Files are validated before anything is added.")
            }

            if let preview = viewModel.preview {
                if let name = preview.name {
                    Section("Collection") { Text(name) }
                }

                Section("Valid (\(preview.validEntries.count))") {
                    ForEach(preview.validEntries) { entry in
                        LabeledContent("#\(entry.index)", value: entry.text)
                    }
                }

                if !preview.invalidEntries.isEmpty {
                    Section("Skipped (\(preview.invalidEntries.count))") {
                        ForEach(preview.invalidEntries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("#\(entry.index): \(entry.reason)")
                                    .foregroundStyle(.red)
                                Text(entry.text.isEmpty ? "Empty text" : entry.text)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button("Import \(preview.validEntries.count) Prompts") {
                        Task { await viewModel.importValidPrompts() }
                    }
                    .disabled(preview.validEntries.isEmpty || viewModel.isImporting)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section("Needs attention") {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Import Prompts")
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { viewModel.load(url) }
            case .failure(let error):
                viewModel.setFileSelectionError(error)
            }
        }
        .alert(
            "Import Complete",
            isPresented: Binding(
                get: { viewModel.resultMessage != nil },
                set: { if !$0 { viewModel.dismissResult() } }
            )
        ) {
            Button("OK") { viewModel.dismissResult() }
        } message: {
            Text(viewModel.resultMessage ?? "")
        }
    }
}

struct PromptImportFormatView: View {
    private let example = """
    {
      "schemaVersion": 1,
      "name": "Morning prompts",
      "prompts": [
        { "text": "What deserves my attention today?" },
        { "text": "Take three slow breaths." }
      ]
    }
    """

    var body: some View {
        List {
            Section("Required structure") {
                Text("Use schemaVersion 1 and a nonempty prompts array. The name is optional. Each prompt needs a text string of 1–280 characters.")
            }
            Section("Example") {
                Text(example)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                ShareLink(item: example) {
                    Label("Copy or Share Example", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("JSON Format")
    }
}
