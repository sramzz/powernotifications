import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Query(sort: \Prompt.createdAt) private var prompts: [Prompt]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProgressView(value: Double(viewModel.step.rawValue + 1), total: 3)
                    .accessibilityLabel("Setup step \(viewModel.step.rawValue + 1) of 3")

                Group {
                    switch viewModel.step {
                    case .welcome:
                        welcomeStep
                    case .prompt:
                        promptStep
                    case .schedule:
                        scheduleStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding()
            .navigationTitle("Set Up")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Prompts throughout your day")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Write what matters to you. PowerNotifications will distribute those prompts across your waking hours.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Continue") {
                viewModel.continueFromWelcome(hasPrompts: !prompts.isEmpty)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var promptStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create your first prompt")
                .font(.title.bold())
            Text("It can be a reminder, affirmation, question, or idea.")
                .foregroundStyle(.secondary)
            TextEditor(text: binding(for: \OnboardingViewModel.promptText))
                .frame(minHeight: 180)
                .padding(8)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.secondary.opacity(0.3))
                }
                .accessibilityLabel("First prompt")
            HStack {
                Text(viewModel.promptError ?? "")
                    .foregroundStyle(.red)
                Spacer()
                Text("\(viewModel.promptText.count)/280")
                    .foregroundStyle(viewModel.promptText.count > 280 ? .red : .secondary)
            }
            .font(.caption)
            Button("Save Prompt") {
                Task { await viewModel.saveFirstPrompt() }
            }
                .buttonStyle(.borderedProminent)
        }
    }

    private var scheduleStep: some View {
        Form {
            Section {
                Text("Choose your daily rhythm")
                    .font(.title.bold())
                    .listRowInsets(EdgeInsets())
            }
            Section("Schedule") {
                ScheduleControls(
                    dailyCount: binding(for: \OnboardingViewModel.dailyCount),
                    wakeTime: binding(for: \OnboardingViewModel.wakeTime),
                    bedtime: binding(for: \OnboardingViewModel.bedtime)
                )
            }
            if let errorMessage = viewModel.errorMessage {
                Section("Needs attention") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button("Enable Notifications") {
                    Task { await viewModel.finishSetup() }
                }
                .disabled(!viewModel.scheduleIsValid || viewModel.isWorking)
            } footer: {
                Text("iOS will ask for permission. If you decline, your prompts and schedule will still be saved.")
            }
        }
        .formStyle(.grouped)
    }

    private func binding<Value>(
        for keyPath: ReferenceWritableKeyPath<OnboardingViewModel, Value>
    ) -> Binding<Value> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
    }

}
