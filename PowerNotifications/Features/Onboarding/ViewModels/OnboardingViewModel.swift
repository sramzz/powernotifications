import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private let preferences: SchedulePreferences
    private let promptViewModel: PromptViewModel
    private let scheduleManager: ScheduleManager
    private let catalogInstaller: PromptCatalogInstaller

    var step: OnboardingStep = .welcome
    var promptText = ""
    var promptError: String?
    var dailyCount = 3
    var wakeTime = TimeOfDay.date(for: 8 * 60)
    var bedtime = TimeOfDay.date(for: 22 * 60)
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    init(
        preferences: SchedulePreferences,
        promptViewModel: PromptViewModel,
        scheduleManager: ScheduleManager,
        catalogInstaller: PromptCatalogInstaller
    ) {
        self.preferences = preferences
        self.promptViewModel = promptViewModel
        self.scheduleManager = scheduleManager
        self.catalogInstaller = catalogInstaller
    }

    var scheduleIsValid: Bool {
        let maximum = ScheduleGenerator.maximumCount(
            wakeMinute: TimeOfDay.minuteOfDay(for: wakeTime),
            bedtimeMinute: TimeOfDay.minuteOfDay(for: bedtime)
        )
        return maximum > 0 && (1...maximum).contains(dailyCount)
    }

    func continueFromWelcome(hasPrompts: Bool) {
        step = hasPrompts ? .schedule : .prompt
    }

    func saveFirstPrompt() async {
        promptError = nil
        do {
            try await promptViewModel.create(text: promptText)
            step = .schedule
        } catch PromptValidationError.empty {
            promptError = "Enter a prompt."
        } catch PromptValidationError.tooLong {
            promptError = "Keep the prompt to 280 characters."
        } catch {
            promptError = error.localizedDescription
        }
    }

    func finishSetup() async {
        guard scheduleIsValid else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await catalogInstaller.installIfNeeded()
        } catch {
            errorMessage = "Starter prompts could not be added. Please retry."
            AppLogger.lifecycle.error("Onboarding catalog installation failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        let snapshots: [PromptSnapshot]
        do {
            snapshots = try promptViewModel.snapshots()
        } catch {
            errorMessage = "Your prompts could not be loaded. Please retry."
            return
        }

        await scheduleManager.saveSchedule(
            count: dailyCount,
            wakeMinute: TimeOfDay.minuteOfDay(for: wakeTime),
            bedtimeMinute: TimeOfDay.minuteOfDay(for: bedtime),
            prompts: snapshots
        )
        await scheduleManager.setDeliveryEnabled(true, prompts: snapshots)
        preferences.onboardingCompleted = true
        AppLogger.lifecycle.info("Onboarding completed")
    }
}

enum OnboardingStep: Int, Equatable {
    case welcome
    case prompt
    case schedule
}
