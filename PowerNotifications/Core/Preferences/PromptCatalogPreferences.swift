import Foundation

@MainActor
final class PromptCatalogPreferences {
    private static let appliedVersionKey = "promptCatalogAppliedVersion"
    private let defaults: UserDefaults

    var appliedVersion: Int {
        didSet { defaults.set(appliedVersion, forKey: Self.appliedVersionKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appliedVersion = defaults.integer(forKey: Self.appliedVersionKey)
    }
}
