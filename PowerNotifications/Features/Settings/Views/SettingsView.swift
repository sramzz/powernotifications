import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(ScheduleManager.self) private var scheduleManager
    @Query(sort: \Prompt.createdAt) private var prompts: [Prompt]

    var body: some View {
        Form {
            Section("Notifications") {
                LabeledContent("Authorization", value: authorizationLabel)

                if scheduleManager.authorizationState == .denied {
                    Button("Open iOS Settings", systemImage: "arrow.up.forward.app") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section("About") {
                Text("PowerNotifications delivers your own prompts throughout your waking hours. Your prompts stay on this device.")
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Settings")
        .task {
            await scheduleManager.reconcile(prompts: prompts.map(\.snapshot))
        }
    }

    private var authorizationLabel: String {
        switch scheduleManager.authorizationState {
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Disabled"
        case .authorized:
            return "Allowed"
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
