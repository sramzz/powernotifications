import Foundation
import Observation

@MainActor
@Observable
final class ScheduleManager {
    private let preferences: SchedulePreferences
    private let scheduler: NotificationScheduling

    private(set) var slots: [ScheduledSlot] = []
    private(set) var authorizationState: NotificationAuthorizationState = .notDetermined
    private(set) var isWorking = false
    var errorMessage: String?

    init(preferences: SchedulePreferences, scheduler: NotificationScheduling) {
        self.preferences = preferences
        self.scheduler = scheduler
    }

    func setDeliveryEnabled(_ enabled: Bool, prompts: [PromptSnapshot]) async {
        guard !isWorking else { return }
        errorMessage = nil

        if !enabled {
            await scheduler.cancelSchedule()
            preferences.deliveryEnabled = false
            slots = []
            return
        }

        isWorking = true
        defer { isWorking = false }

        authorizationState = await scheduler.authorizationStatus()
        AppLogger.notifications.info("Authorization state checked: \(String(describing: self.authorizationState), privacy: .public)")
        if authorizationState == .notDetermined {
            do {
                try await scheduler.requestAuthorization()
                authorizationState = await scheduler.authorizationStatus()
            } catch {
                authorizationState = .denied
                fail("Notification permission could not be requested.")
                return
            }
        }

        guard authorizationState.allowsDelivery else {
            fail("Notifications are disabled. Allow them in Settings to continue.")
            return
        }

        await rebuild(prompts: prompts)
    }

    func saveSchedule(
        count: Int,
        wakeMinute: Int,
        bedtimeMinute: Int,
        prompts: [PromptSnapshot]
    ) async {
        preferences.dailyCount = count
        preferences.wakeMinute = wakeMinute
        preferences.bedtimeMinute = bedtimeMinute
        errorMessage = nil

        if preferences.deliveryEnabled {
            await rebuild(prompts: prompts)
        }
    }

    func promptsDidChange(_ prompts: [PromptSnapshot]) async {
        guard preferences.deliveryEnabled else { return }
        await rebuild(prompts: prompts)
    }

    func reshuffle(prompts: [PromptSnapshot]) async {
        guard preferences.deliveryEnabled else {
            errorMessage = "Enable delivery before reshuffling the pattern."
            return
        }
        await rebuild(prompts: prompts)
    }

    func reconcile(prompts: [PromptSnapshot]) async {
        authorizationState = await scheduler.authorizationStatus()
        AppLogger.notifications.info("Reconciliation checked authorization state: \(String(describing: self.authorizationState), privacy: .public)")

        guard authorizationState.allowsDelivery else {
            if preferences.deliveryEnabled {
                AppLogger.notifications.error("Reconciliation disabled delivery because notification authorization was revoked")
                await scheduler.cancelSchedule()
                preferences.deliveryEnabled = false
                slots = []
                errorMessage = "Notifications are disabled. Allow them in Settings to continue."
            }
            return
        }

        let pending = await scheduler.pendingSlots(wakeMinute: preferences.wakeMinute)
        slots = pending
        if preferences.deliveryEnabled,
           !isConsistent(pending, prompts: prompts, configuration: configuration) {
            AppLogger.notifications.info("Reconciling an incomplete notification pattern")
            await rebuild(prompts: prompts)
        } else if preferences.deliveryEnabled {
            AppLogger.notifications.info("Notification pattern reconciliation succeeded")
        }
    }

    private func rebuild(prompts: [PromptSnapshot]) async {
        isWorking = true
        defer { isWorking = false }

        do {
            var random = SystemRandomNumberGenerator()
            let generated = try ScheduleGenerator.generate(
                prompts: prompts,
                configuration: configuration,
                using: &random
            )
            try await scheduler.replaceSchedule(with: generated)
            let pending = await scheduler.pendingSlots(wakeMinute: preferences.wakeMinute)
            guard isConsistent(pending, prompts: prompts, configuration: configuration) else {
                throw ScheduleManagerError.verificationFailed
            }
            slots = pending
            preferences.deliveryEnabled = true
            errorMessage = nil
        } catch {
            await scheduler.cancelSchedule()
            fail(message(for: error))
        }
    }

    private func fail(_ message: String) {
        preferences.deliveryEnabled = false
        slots = []
        errorMessage = message
        AppLogger.notifications.error("Schedule inactive: \(message, privacy: .public)")
    }

    private var configuration: ScheduleConfiguration {
        ScheduleConfiguration(
            count: preferences.dailyCount,
            wakeMinute: preferences.wakeMinute,
            bedtimeMinute: preferences.bedtimeMinute
        )
    }

    private func isConsistent(
        _ pending: [ScheduledSlot],
        prompts: [PromptSnapshot],
        configuration: ScheduleConfiguration
    ) -> Bool {
        guard pending.count == configuration.count else { return false }
        let currentPrompts = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, $0.text) })
        let distinctTimes = Set(pending.map(\.minuteOfDay))

        return distinctTimes.count == pending.count && pending.allSatisfy { slot in
            slot.configuration == configuration
                && slot.minuteOffset < configuration.activeWindowMinutes
                && currentPrompts[slot.promptID] == slot.promptText
        }
    }

    private func message(for error: Error) -> String {
        switch error {
        case ScheduleGenerationError.noPrompts:
            return "Add at least one prompt before enabling delivery."
        case ScheduleGenerationError.equalWakeAndBedtime:
            return "Wake time and bedtime must be different."
        case ScheduleGenerationError.invalidCount(let maximum):
            return "Choose between 1 and \(maximum) notifications for this active window."
        default:
            return "The notification pattern could not be scheduled. Please retry."
        }
    }
}

private enum ScheduleManagerError: Error {
    case verificationFailed
}
