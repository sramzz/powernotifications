import SwiftUI

@main
struct PowerNotificationsApp: App {
    init() {
        AppLogger.lifecycle.info("PowerNotifications launched")
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

