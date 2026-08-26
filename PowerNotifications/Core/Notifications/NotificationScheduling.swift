import Foundation

enum NotificationAuthorizationState: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized

    var allowsDelivery: Bool { self == .authorized }
}

struct PromptNotificationPayload: Equatable, Sendable {
    let promptID: UUID
    let promptText: String
}

@MainActor
protocol NotificationScheduling: AnyObject {
    func authorizationStatus() async -> NotificationAuthorizationState
    func requestAuthorization() async throws
    func replaceSchedule(with slots: [ScheduledSlot]) async throws
    func cancelSchedule() async
    func pendingSlots(wakeMinute: Int) async -> [ScheduledSlot]
}
