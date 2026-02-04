import Testing
@testable import GrantivaUI

@Suite("GrantivaUI Tests")
struct GrantivaUITests {
    @Test func themeDefaults() {
        let theme = GrantivaTheme.default
        #expect(theme.cornerRadius == 12)
        #expect(theme.spacing == 16)
    }

    @MainActor
    @Test func feedbackStoreInitialState() {
        let store = FeedbackStore()
        #expect(store.featureRequests.isEmpty)
        #expect(store.tickets.isEmpty)
        #expect(store.isLoadingFeatures == false)
        #expect(store.isLoadingTickets == false)
        #expect(store.isSubmitting == false)
        #expect(store.error == nil)
    }
}
