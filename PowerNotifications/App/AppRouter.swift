import Foundation
import Observation

enum AppTab: Hashable {
    case prompts
    case schedule
    case settings
}

enum PromptRoute: Hashable {
    case detail(promptID: UUID, fallbackText: String)
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .prompts
    var promptPath: [PromptRoute] = []

    func openPrompt(id: UUID, fallbackText: String) {
        selectedTab = .prompts
        promptPath.append(.detail(promptID: id, fallbackText: fallbackText))
    }

    func openNotification(_ payload: PromptNotificationPayload) {
        selectedTab = .prompts
        promptPath = [
            .detail(promptID: payload.promptID, fallbackText: payload.promptText)
        ]
    }
}
