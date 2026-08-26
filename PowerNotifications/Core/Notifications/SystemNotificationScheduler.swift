@preconcurrency import UserNotifications
import Foundation

@MainActor
final class SystemNotificationScheduler: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
    private enum PayloadKey {
        static let promptID = "promptID"
        static let promptText = "promptText"
        static let count = "scheduleCount"
        static let wakeMinute = "scheduleWakeMinute"
        static let bedtimeMinute = "scheduleBedtimeMinute"
    }

    private static let requestPrefix = "powernotifications.slot."
    private let center: UNUserNotificationCenter
    var onNotificationResponse: ((PromptNotificationPayload) -> Void)?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        AppLogger.notifications.info("Notification authorization request completed: \(granted)")
    }

    func replaceSchedule(with slots: [ScheduledSlot]) async throws {
        let oldIdentifiers = await appOwnedPendingIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: oldIdentifiers)

        var newIdentifiers: [String] = []
        do {
            for slot in slots {
                let configuration = slot.configuration
                let content = UNMutableNotificationContent()
                content.title = "PowerNotifications"
                content.body = slot.promptText
                content.sound = .default
                content.userInfo = [
                    PayloadKey.promptID: slot.promptID.uuidString,
                    PayloadKey.promptText: slot.promptText,
                    PayloadKey.count: configuration.count,
                    PayloadKey.wakeMinute: configuration.wakeMinute,
                    PayloadKey.bedtimeMinute: configuration.bedtimeMinute
                ]

                var components = DateComponents()
                components.hour = slot.minuteOfDay / 60
                components.minute = slot.minuteOfDay % 60
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: true
                )
                let identifier = Self.requestPrefix + slot.id
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                try await center.add(request)
                newIdentifiers.append(identifier)
            }
            AppLogger.notifications.info("Scheduled \(slots.count) repeating notifications")
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: newIdentifiers)
            AppLogger.notifications.error("Notification replacement failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func cancelSchedule() async {
        let identifiers = await appOwnedPendingIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        AppLogger.notifications.info("Cancelled \(identifiers.count) pending notifications")
    }

    func pendingSlots(wakeMinute: Int) async -> [ScheduledSlot] {
        let requests = await center.pendingNotificationRequests()
        return requests.compactMap { request in
            guard request.identifier.hasPrefix(Self.requestPrefix) else { return nil }
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let hour = trigger.dateComponents.hour,
                  let minute = trigger.dateComponents.minute,
                  let promptIDString = request.content.userInfo[PayloadKey.promptID] as? String,
                  let promptID = UUID(uuidString: promptIDString),
                  let promptText = request.content.userInfo[PayloadKey.promptText] as? String,
                  let count = request.content.userInfo[PayloadKey.count] as? Int,
                  let scheduledWakeMinute = request.content.userInfo[PayloadKey.wakeMinute] as? Int,
                  let bedtimeMinute = request.content.userInfo[PayloadKey.bedtimeMinute] as? Int else {
                AppLogger.notifications.error("Discarded malformed app-owned pending notification request")
                return nil
            }

            let minuteOfDay = hour * 60 + minute
            let configuration = ScheduleConfiguration(
                count: count,
                wakeMinute: scheduledWakeMinute,
                bedtimeMinute: bedtimeMinute
            )
            return ScheduledSlot(
                id: String(request.identifier.dropFirst(Self.requestPrefix.count)),
                minuteOffset: (minuteOfDay - wakeMinute + 1_440) % 1_440,
                minuteOfDay: minuteOfDay,
                promptID: promptID,
                promptText: promptText,
                configuration: configuration
            )
        }
        .sorted { $0.minuteOffset < $1.minuteOffset }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let promptIDString = userInfo[PayloadKey.promptID] as? String,
              let promptID = UUID(uuidString: promptIDString),
              let promptText = userInfo[PayloadKey.promptText] as? String else {
            AppLogger.notifications.error("Ignored notification response with malformed payload")
            return
        }

        await MainActor.run {
            onNotificationResponse?(
                PromptNotificationPayload(promptID: promptID, promptText: promptText)
            )
        }
    }

    private func appOwnedPendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.requestPrefix) }
    }
}
