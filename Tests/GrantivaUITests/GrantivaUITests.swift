import Testing
import SwiftUI
@testable import GrantivaUI
import Grantiva

@Suite("GrantivaUI Tests")
struct GrantivaUITests {

    // MARK: - GrantivaTheme

    @Test func themeDefaults() {
        let theme = GrantivaTheme.default
        #expect(theme.cornerRadius == 12)
        #expect(theme.spacing == 16)
    }

    @Test func themeCustomCornerRadiusAndSpacing() {
        let theme = GrantivaTheme(cornerRadius: 8, spacing: 12)
        #expect(theme.cornerRadius == 8)
        #expect(theme.spacing == 12)
    }

    @Test func themeCustomColors() {
        let accent = Color.purple
        let destructive = Color.pink
        let theme = GrantivaTheme(accentColor: accent, destructiveColor: destructive)
        #expect(theme.accentColor == accent)
        #expect(theme.destructiveColor == destructive)
    }

    @Test func themeAllFieldsSettable() {
        let theme = GrantivaTheme(
            accentColor: .blue,
            secondaryColor: .gray,
            backgroundColor: .white,
            surfaceColor: .white,
            textPrimary: .black,
            textSecondary: .gray,
            destructiveColor: .red,
            successColor: .green,
            warningColor: .orange,
            cornerRadius: 6,
            spacing: 8
        )
        #expect(theme.cornerRadius == 6)
        #expect(theme.spacing == 8)
        #expect(theme.accentColor == .blue)
        #expect(theme.successColor == .green)
        #expect(theme.warningColor == .orange)
    }

    // MARK: - FeedbackStore

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

    @MainActor
    @Test func feedbackStoreSelectedFeatureRequestInitiallyNil() {
        let store = FeedbackStore()
        #expect(store.selectedFeatureRequest == nil)
    }

    @MainActor
    @Test func feedbackStoreSelectedTicketInitiallyNil() {
        let store = FeedbackStore()
        #expect(store.selectedTicket == nil)
    }

    @MainActor
    @Test func feedbackStoreCommentsInitiallyEmpty() {
        let store = FeedbackStore()
        #expect(store.featureComments.isEmpty)
        #expect(store.ticketMessages.isEmpty)
    }

    @MainActor
    @Test func feedbackStoreLoadingFlagsInitiallyFalse() {
        let store = FeedbackStore()
        #expect(store.isLoadingFeatureDetail == false)
        #expect(store.isLoadingComments == false)
        #expect(store.isLoadingTicketDetail == false)
    }

    @MainActor
    @Test func feedbackStoreCanSetLoadingFeatures() {
        let store = FeedbackStore()
        store.isLoadingFeatures = true
        #expect(store.isLoadingFeatures == true)
    }

    @MainActor
    @Test func feedbackStoreCanSetError() {
        let store = FeedbackStore()
        let error = NSError(domain: "TestError", code: 42, userInfo: nil)
        store.error = error
        #expect(store.error != nil)
        store.error = nil
        #expect(store.error == nil)
    }

    @MainActor
    @Test func feedbackStoreCanSetSubmitting() {
        let store = FeedbackStore()
        store.isSubmitting = true
        #expect(store.isSubmitting == true)
        store.isSubmitting = false
        #expect(store.isSubmitting == false)
    }

    // MARK: - FeedbackUIService

    @MainActor
    @Test func previewServiceFetchFeatureRequestsIsNoop() async {
        // preview service should complete without crashing
        let service = FeedbackUIService.preview
        await service.fetchFeatureRequests()
    }

    @MainActor
    @Test func previewServiceSubmitFeatureRequestReturnsTrue() async {
        let service = FeedbackUIService.preview
        let result = await service.submitFeatureRequest("Title", "Description text here")
        #expect(result == true)
    }

    @MainActor
    @Test func previewServiceSubmitTicketReturnsTrue() async {
        let service = FeedbackUIService.preview
        let result = await service.submitTicket("Subject", "Body text here", nil)
        #expect(result == true)
    }

    @MainActor
    @Test func previewServiceAddCommentReturnsTrue() async {
        let service = FeedbackUIService.preview
        let result = await service.addComment(UUID(), "A comment body")
        #expect(result == true)
    }

    @MainActor
    @Test func previewServiceReplyToTicketReturnsTrue() async {
        let service = FeedbackUIService.preview
        let result = await service.replyToTicket(UUID(), "A reply body")
        #expect(result == true)
    }

    @MainActor
    @Test func previewServiceVoteIsNoop() async {
        let service = FeedbackUIService.preview
        // Should not crash
        await service.vote(UUID())
        await service.removeVote(UUID())
    }

    // MARK: - FeedbackUIService live integration with store

    @MainActor
    @Test func liveServiceFetchFeatureRequestsUpdatesStore() async {
        let store = FeedbackStore()
        var fetchCalled = false
        let service = FeedbackUIService(
            fetchFeatureRequests: { @Sendable in
                await MainActor.run {
                    store.featureRequests = [
                        FeatureRequest(id: UUID(), title: "Test", description: "Desc",
                                       status: .open, voteCount: 1, hasVoted: false,
                                       commentCount: 0, createdAt: .now, updatedAt: .now)
                    ]
                    fetchCalled = true
                }
            },
            fetchFeatureRequest: { _ in },
            submitFeatureRequest: { _, _ in true },
            vote: { _ in },
            removeVote: { _ in },
            fetchComments: { _ in },
            addComment: { _, _ in true },
            fetchTickets: {},
            fetchTicketDetail: { _ in },
            submitTicket: { _, _, _ in true },
            replyToTicket: { _, _ in true }
        )
        await service.fetchFeatureRequests()
        #expect(fetchCalled == true)
        #expect(store.featureRequests.count == 1)
        #expect(store.featureRequests.first?.title == "Test")
    }

    @MainActor
    @Test func liveServiceFetchTicketsUpdatesStore() async {
        let store = FeedbackStore()
        let service = FeedbackUIService(
            fetchFeatureRequests: {},
            fetchFeatureRequest: { _ in },
            submitFeatureRequest: { _, _ in true },
            vote: { _ in },
            removeVote: { _ in },
            fetchComments: { _ in },
            addComment: { _, _ in true },
            fetchTickets: { @Sendable in
                await MainActor.run {
                    store.tickets = [
                        SupportTicket(id: UUID(), subject: "Help!", status: .open,
                                      priority: .high, messageCount: 0,
                                      createdAt: .now, updatedAt: .now)
                    ]
                }
            },
            fetchTicketDetail: { _ in },
            submitTicket: { _, _, _ in true },
            replyToTicket: { _, _ in true }
        )
        await service.fetchTickets()
        #expect(store.tickets.count == 1)
        #expect(store.tickets.first?.subject == "Help!")
    }
}
