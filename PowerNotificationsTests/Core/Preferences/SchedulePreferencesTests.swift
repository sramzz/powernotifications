import Foundation
import Testing
@testable import PowerNotifications

@Suite("SchedulePreferences")
@MainActor
struct SchedulePreferencesTests {
    @Test("Uses the v1 defaults on first launch")
    func usesFirstLaunchDefaults() {
        let preferences = makePreferences().preferences

        #expect(!preferences.onboardingCompleted)
        #expect(!preferences.deliveryEnabled)
        #expect(preferences.dailyCount == 3)
        #expect(preferences.wakeMinute == 480)
        #expect(preferences.bedtimeMinute == 1_320)
    }

    @Test("Persists onboarding and schedule choices across relaunch")
    func persistsAcrossInstances() {
        let setup = makePreferences()
        setup.preferences.onboardingCompleted = true
        setup.preferences.deliveryEnabled = true
        setup.preferences.dailyCount = 8
        setup.preferences.wakeMinute = 600
        setup.preferences.bedtimeMinute = 60

        let relaunched = SchedulePreferences(defaults: setup.defaults)

        #expect(relaunched.onboardingCompleted)
        #expect(relaunched.deliveryEnabled)
        #expect(relaunched.dailyCount == 8)
        #expect(relaunched.wakeMinute == 600)
        #expect(relaunched.bedtimeMinute == 60)
    }

    private func makePreferences() -> (preferences: SchedulePreferences, defaults: UserDefaults) {
        let suiteName = "SchedulePreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (SchedulePreferences(defaults: defaults), defaults)
    }
}
