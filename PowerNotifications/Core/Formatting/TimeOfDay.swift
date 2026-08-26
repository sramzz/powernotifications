import Foundation

enum TimeOfDay {
    static func date(for minuteOfDay: Int, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .minute, value: minuteOfDay, to: start) ?? start
    }

    static func minuteOfDay(for date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func formatted(minuteOfDay: Int) -> String {
        date(for: minuteOfDay).formatted(date: .omitted, time: .shortened)
    }
}
