import Testing
@testable import PowerNotifications

@Suite("HomeViewModel")
@MainActor
struct HomeViewModelTests {
    @Test("Provides the initial greeting")
    func providesInitialGreeting() {
        let viewModel = HomeViewModel()

        #expect(viewModel.greeting == "Hello, World!")
    }
}

