import SwiftUI

struct RootView: View {
    @Environment(SchedulePreferences.self) private var preferences

    var body: some View {
        Group {
            if preferences.onboardingCompleted {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.default, value: preferences.onboardingCompleted)
    }
}
