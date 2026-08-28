import Foundation
import SwiftUI
import Testing
@testable import GrantivaUI
import Grantiva

@Suite("Status display mapping")
struct StatusDisplayTests {

    @Test(arguments: [
        (FeatureRequestStatus.pending, "Pending", Color.secondary),
        (.open, "Open", .blue),
        (.planned, "Planned", .purple),
        (.inProgress, "In Progress", .orange),
        (.shipped, "Shipped", .green),
        (.declined, "Declined", .red),
        (.duplicate, "Duplicate", .gray)
    ])
    func featureStatusDisplay(status: FeatureRequestStatus, name: String, color: Color) {
        #expect(status.displayName == name)
        #expect(status.displayColor == color)
    }

    @Test(arguments: [
        (TicketStatus.open, "Open", Color.blue),
        (.awaitingReply, "Awaiting Reply", .orange),
        (.resolved, "Resolved", .green),
        (.closed, "Closed", .secondary)
    ])
    func ticketStatusDisplay(status: TicketStatus, name: String, color: Color) {
        #expect(status.displayName == name)
        #expect(status.displayColor == color)
    }

    @Test(arguments: [
        (TicketPriority.low, "Low", Color.secondary),
        (.normal, "Normal", .blue),
        (.high, "High", .orange),
        (.urgent, "Urgent", .red)
    ])
    func priorityDisplay(priority: TicketPriority, name: String, color: Color) {
        #expect(priority.displayName == name)
        #expect(priority.displayColor == color)
    }

    /// Every case must have a non-empty, human-readable label — a missing switch arm in
    /// `displayName` after an SDK enum gains a case would otherwise ship as a raw value.
    @Test func everyStatusCaseHasANonEmptyLabel() {
        for status in FeatureRequestStatus.allCases {
            #expect(status.displayName.isEmpty == false)
            #expect(status.displayName != status.rawValue || status.rawValue == status.displayName.lowercased())
        }
        for status in TicketStatus.allCases {
            #expect(status.displayName.isEmpty == false)
        }
        for priority in TicketPriority.allCases {
            #expect(priority.displayName.isEmpty == false)
        }
    }

    @Test func featureStatusLabelsAreDistinct() {
        let labels = Set(FeatureRequestStatus.allCases.map(\.displayName))
        #expect(labels.count == FeatureRequestStatus.allCases.count)
    }

    @Test func ticketStatusLabelsAreDistinct() {
        let labels = Set(TicketStatus.allCases.map(\.displayName))
        #expect(labels.count == TicketStatus.allCases.count)
    }
}

@MainActor
@Suite("Component construction")
struct ComponentConstructionTests {

    @Test func statusBadgeFromFeatureStatusUsesTheMappedLabelAndColor() {
        let badge = StatusBadge(featureStatus: .inProgress)
        #expect(badge.label == "In Progress")
        #expect(badge.color == .orange)
    }

    @Test func statusBadgeFromTicketStatusUsesTheMappedLabelAndColor() {
        let badge = StatusBadge(ticketStatus: .awaitingReply)
        #expect(badge.label == "Awaiting Reply")
        #expect(badge.color == .orange)
    }

    @Test func statusBadgeFromPriorityUsesTheMappedLabelAndColor() {
        let badge = StatusBadge(priority: .urgent)
        #expect(badge.label == "Urgent")
        #expect(badge.color == .red)
    }

    @Test func errorBannerCarriesMessageAndOptionalRetry() {
        let plain = ErrorBanner(message: "Network request failed.")
        #expect(plain.message == "Network request failed.")
        #expect(plain.retryAction == nil)

        let retried = Box(false)
        let withRetry = ErrorBanner(message: "Try again.", retryAction: { retried.value = true })
        #expect(withRetry.retryAction != nil)
        withRetry.retryAction?()
        #expect(retried.value == true)
    }

    @Test func loadingViewMessageIsOptional() {
        #expect(LoadingView().message == nil)
        #expect(LoadingView(message: "Loading…").message == "Loading…")
    }

    @Test func relativeTimeTextHoldsTheGivenDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(RelativeTimeText(date: date).date == date)
    }

    @Test func voteButtonReflectsCountAndVotedStateAndInvokesAction() {
        let tapped = Box(0)
        let button = VoteButton(count: 12, hasVoted: true) { tapped.value += 1 }
        #expect(button.count == 12)
        #expect(button.hasVoted == true)
        button.action()
        #expect(tapped.value == 1)
    }

    @Test func featureRequestRowCarriesItsFeatureAndVoteAction() {
        let feature = Fixture.feature(title: "Row")
        let voted = Box(false)
        let row = FeatureRequestRow(feature: feature) { voted.value = true }
        #expect(row.feature.id == feature.id)
        #expect(row.feature.title == "Row")
        row.onVote()
        #expect(voted.value == true)
    }

    @Test func ticketRowCarriesItsTicket() {
        let ticket = Fixture.ticket(subject: "Row ticket")
        let row = TicketRow(ticket: ticket)
        #expect(row.ticket.id == ticket.id)
        #expect(row.ticket.subject == "Row ticket")
    }
}

@MainActor
@Suite("Public view construction")
struct PublicViewConstructionTests {

    @Test func feedbackContainerViewTakesAStore() {
        let store = FeedbackStore()
        let view = FeedbackContainerView(store: store)
        #expect(view.store === store)
    }

    @Test func featureRequestListViewTakesAStoreAndSelectionHandler() {
        let store = FeedbackStore()
        let selected = Box<UUID?>(nil)
        let view = FeatureRequestListView(store: store) { selected.value = $0.id }
        #expect(view.store === store)

        let feature = Fixture.feature()
        view.onSelect(feature)
        #expect(selected.value == feature.id)
    }

    @Test func featureRequestDetailViewTakesAStoreAndFeatureId() {
        let store = FeedbackStore()
        let id = UUID()
        let view = FeatureRequestDetailView(store: store, featureId: id)
        #expect(view.store === store)
        #expect(view.featureId == id)
    }

    @Test func submitFeatureRequestViewTakesAStore() {
        let store = FeedbackStore()
        let view = SubmitFeatureRequestView(store: store)
        #expect(view.store === store)
    }

    @Test func supportTicketListViewTakesAStoreAndSelectionHandler() {
        let store = FeedbackStore()
        let selected = Box<UUID?>(nil)
        let view = SupportTicketListView(store: store) { selected.value = $0.id }
        #expect(view.store === store)

        let ticket = Fixture.ticket()
        view.onSelect(ticket)
        #expect(selected.value == ticket.id)
    }

    @Test func ticketDetailViewTakesAStoreAndTicketId() {
        let store = FeedbackStore()
        let id = UUID()
        let view = TicketDetailView(store: store, ticketId: id)
        #expect(view.store === store)
        #expect(view.ticketId == id)
    }

    @Test func submitTicketViewTakesAStore() {
        let store = FeedbackStore()
        let view = SubmitTicketView(store: store)
        #expect(view.store === store)
    }

    /// Views read their service and theme from the environment; the modifiers that put
    /// them there must stay available on any `View`.
    @Test func environmentModifiersAreApplicableToPublicViews() {
        let store = FeedbackStore()
        let themed = FeedbackContainerView(store: store)
            .feedbackService(.preview)
            .grantivaTheme(GrantivaTheme(cornerRadius: 4, spacing: 4))
        #expect(themed is any View)
    }
}
