import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sramzz.powernotifications"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}

