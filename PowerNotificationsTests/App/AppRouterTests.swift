import Foundation
import Testing
@testable import PowerNotifications

@Suite("AppRouter")
@MainActor
struct AppRouterTests {
    @Test("A notification routes to Prompts with a text fallback")
    func routesNotificationPayload() {
        let router = AppRouter()
        let id = UUID()

        router.openNotification(
            PromptNotificationPayload(promptID: id, promptText: "Delivered text")
        )

        #expect(router.selectedTab == .prompts)
        #expect(router.promptPath == [
            PromptRoute.detail(promptID: id, fallbackText: "Delivered text")
        ])
    }
}
