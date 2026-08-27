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

    @Test("A notification response routes and completes on the main actor")
    func completesNotificationResponseOnMainActor() async {
        let handler = NotificationResponseHandler()
        let payload = PromptNotificationPayload(
            promptID: UUID(),
            promptText: "Delivered text"
        )
        var receivedPayload: PromptNotificationPayload?
        handler.onResponse = { receivedPayload = $0 }

        await Task.detached {
            await withCheckedContinuation { continuation in
                handler.handle(payload) {
                    MainActor.preconditionIsolated()
                    continuation.resume()
                }
            }
        }.value

        #expect(receivedPayload == payload)
    }
}
