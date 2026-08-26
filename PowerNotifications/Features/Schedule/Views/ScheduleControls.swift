import SwiftUI

struct ScheduleControls: View {
    @Binding var dailyCount: Int
    @Binding var wakeTime: Date
    @Binding var bedtime: Date

    private var wakeMinute: Int { TimeOfDay.minuteOfDay(for: wakeTime) }
    private var bedtimeMinute: Int { TimeOfDay.minuteOfDay(for: bedtime) }
    private var maximumCount: Int {
        ScheduleGenerator.maximumCount(
            wakeMinute: wakeMinute,
            bedtimeMinute: bedtimeMinute
        )
    }

    var body: some View {
        DatePicker("Wake time", selection: $wakeTime, displayedComponents: .hourAndMinute)
        DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)

        Stepper(
            "\(dailyCount) notification\(dailyCount == 1 ? "" : "s") per day",
            value: $dailyCount,
            in: 1...max(1, maximumCount)
        )
        .onChange(of: maximumCount) { _, newMaximum in
            guard newMaximum > 0, dailyCount > newMaximum else { return }
            dailyCount = newMaximum
        }

        if maximumCount == 0 {
            Text("Wake time and bedtime must be different.")
                .font(.caption)
                .foregroundStyle(.red)
        } else {
            Text("Notifications are spread between wake time and the next occurrence of bedtime.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
