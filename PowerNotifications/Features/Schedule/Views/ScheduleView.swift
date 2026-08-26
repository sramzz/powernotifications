import SwiftData
import SwiftUI

struct ScheduleView: View {
    @Environment(ScheduleManager.self) private var scheduleManager
    @Environment(SchedulePreferences.self) private var preferences
    @Query(sort: \Prompt.createdAt) private var prompts: [Prompt]

    @State private var dailyCount = 3
    @State private var wakeTime = TimeOfDay.date(for: 8 * 60)
    @State private var bedtime = TimeOfDay.date(for: 22 * 60)
    @State private var didLoad = false

    private var wakeMinute: Int { TimeOfDay.minuteOfDay(for: wakeTime) }
    private var bedtimeMinute: Int { TimeOfDay.minuteOfDay(for: bedtime) }
    private var maximumCount: Int {
        ScheduleGenerator.maximumCount(
            wakeMinute: wakeMinute,
            bedtimeMinute: bedtimeMinute
        )
    }
    private var snapshots: [PromptSnapshot] { prompts.map(\.snapshot) }

    var body: some View {
        @Bindable var scheduleManager = scheduleManager

        Form {
            Section {
                Toggle("Delivery", isOn: deliveryBinding)
                    .disabled(scheduleManager.isWorking || prompts.isEmpty)

                if prompts.isEmpty {
                    Text("Add a prompt before enabling delivery.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(preferences.deliveryEnabled ? "Your fixed daily pattern is active." : "No notifications are currently scheduled.")
            }

            Section("Daily schedule") {
                ScheduleControls(
                    dailyCount: $dailyCount,
                    wakeTime: $wakeTime,
                    bedtime: $bedtime
                )

                Button("Save Schedule") {
                    Task { await saveSchedule() }
                }
                .disabled(!scheduleIsValid || scheduleManager.isWorking)
            }

            if let errorMessage = scheduleManager.errorMessage {
                Section("Needs attention") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                    if !prompts.isEmpty {
                        Button("Retry") {
                            Task {
                                await scheduleManager.setDeliveryEnabled(
                                    true,
                                    prompts: snapshots
                                )
                            }
                        }
                    }
                }
            }

            Section {
                if scheduleManager.slots.isEmpty {
                    Text("Enable delivery to generate the daily pattern.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(scheduleManager.slots) { slot in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TimeOfDay.formatted(minuteOfDay: slot.minuteOfDay))
                                .font(.headline)
                            Text(slot.promptText)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                    Button("Reshuffle Pattern", systemImage: "shuffle") {
                        Task { await scheduleManager.reshuffle(prompts: snapshots) }
                    }
                    .disabled(scheduleManager.isWorking)
                }
            } header: {
                Text("Daily pattern")
            } footer: {
                Text("These times and prompts repeat every day until you save a change or reshuffle.")
            }
        }
        .navigationTitle("Schedule")
        .task {
            guard !didLoad else { return }
            didLoad = true
            dailyCount = preferences.dailyCount
            wakeTime = TimeOfDay.date(for: preferences.wakeMinute)
            bedtime = TimeOfDay.date(for: preferences.bedtimeMinute)
            await scheduleManager.reconcile(prompts: snapshots)
        }
        .onChange(of: maximumCount) { _, newMaximum in
            guard newMaximum > 0, dailyCount > newMaximum else { return }
            dailyCount = newMaximum
        }
    }

    private var scheduleIsValid: Bool {
        maximumCount > 0 && (1...maximumCount).contains(dailyCount)
    }

    private var deliveryBinding: Binding<Bool> {
        Binding(
            get: { preferences.deliveryEnabled },
            set: { enabled in
                Task {
                    await scheduleManager.setDeliveryEnabled(enabled, prompts: snapshots)
                }
            }
        )
    }

    private func saveSchedule() async {
        await scheduleManager.saveSchedule(
            count: dailyCount,
            wakeMinute: wakeMinute,
            bedtimeMinute: bedtimeMinute,
            prompts: snapshots
        )
    }
}
