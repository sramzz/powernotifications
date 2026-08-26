import Foundation
import Observation

@MainActor
@Observable
final class SchedulePreferences {
    private enum Key {
        static let onboardingCompleted = "onboardingCompleted"
        static let deliveryEnabled = "deliveryEnabled"
        static let dailyCount = "dailyCount"
        static let wakeMinute = "wakeMinute"
        static let bedtimeMinute = "bedtimeMinute"
    }

    private let defaults: UserDefaults

    var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }

    var deliveryEnabled: Bool {
        didSet { defaults.set(deliveryEnabled, forKey: Key.deliveryEnabled) }
    }

    var dailyCount: Int {
        didSet { defaults.set(dailyCount, forKey: Key.dailyCount) }
    }

    var wakeMinute: Int {
        didSet { defaults.set(wakeMinute, forKey: Key.wakeMinute) }
    }

    var bedtimeMinute: Int {
        didSet { defaults.set(bedtimeMinute, forKey: Key.bedtimeMinute) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        deliveryEnabled = defaults.bool(forKey: Key.deliveryEnabled)
        dailyCount = defaults.object(forKey: Key.dailyCount) as? Int ?? 3
        wakeMinute = defaults.object(forKey: Key.wakeMinute) as? Int ?? 8 * 60
        bedtimeMinute = defaults.object(forKey: Key.bedtimeMinute) as? Int ?? 22 * 60
    }
}
