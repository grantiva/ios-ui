import Foundation
import Testing
@testable import GrantivaUI
import Grantiva

/// Regression coverage for two shipping view bugs:
///
/// 1. List and detail views swallowed load errors — a failed fetch was presented to the
///    user as an empty state, with no retry affordance.
/// 2. Detail views rendered the *previously* selected item while the newly selected one
///    was still loading, so tapping A then B showed A's content under B's heading.
@MainActor
@Suite("View-facing state")
struct ViewStateTests {

    // MARK: - Bug 2: stale detail on navigation

    @Test func selectingASecondFeatureDoesNotLeaveTheFirstReadableWhileLoading() async {
        let store = FeedbackStore()
        let a = Fixture.feature(title: "Feature A")
        let b = Fixture.feature(title: "Feature B")
        let visibleDuringLoad = Box<FeatureRequest?>(nil)

        var backend = StubBackend()
        backend.featureRequest = { @Sendable id in
            await MainActor.run { visibleDuringLoad.value = store.selectedFeatureRequest }
            return id == a.id ? a : b
        }
        let service = makeStubService(store: store, backend: backend)

        await service.fetchFeatureRequest(a.id)
        visibleDuringLoad.value = nil
        await service.fetchFeatureRequest(b.id)

        #expect(
            visibleDuringLoad.value == nil,
            "while B's detail is loading, A's content must not still be the current selection"
        )
        #expect(store.selectedFeatureRequest?.id == b.id)
    }

    @Test func aFailedFeatureDetailLoadDoesNotLeaveThePreviousFeatureSelected() async {
        let store = FeedbackStore()
        let a = Fixture.feature(title: "Feature A")
        let bId = UUID()

        var backend = StubBackend()
        backend.featureRequest = { @Sendable id in
            if id == a.id { return a }
            throw StubError.boom
        }
        let service = makeStubService(store: store, backend: backend)

        await service.fetchFeatureRequest(a.id)
        await service.fetchFeatureRequest(bId)

        #expect(
            store.selectedFeatureRequest == nil,
            "a failed load of B must not leave A's content on screen as B's detail"
        )
        #expect(store.error as? StubError == .boom)
    }

    @Test func loadingAnotherFeatureDropsThePreviousFeaturesComments() async {
        let store = FeedbackStore()
        let a = Fixture.feature(title: "Feature A")
        let b = Fixture.feature(title: "Feature B")
        store.featureComments = [Fixture.comment(featureId: a.id, body: "A's comment")]

        var backend = StubBackend()
        backend.featureRequest = { @Sendable id in id == a.id ? a : b }
        let service = makeStubService(store: store, backend: backend)

        await service.fetchFeatureRequest(b.id)

        #expect(
            store.featureComments.isEmpty,
            "A's comments must not appear under B while B's comments are still loading"
        )
    }

    @Test func selectingASecondTicketDoesNotLeaveTheFirstReadableWhileLoading() async {
        let store = FeedbackStore()
        let a = Fixture.ticket(subject: "Ticket A")
        let b = Fixture.ticket(subject: "Ticket B")
        let visibleTicket = Box<SupportTicket?>(nil)
        let visibleMessages = Box<[TicketMessage]>([])

        var backend = StubBackend()
        backend.ticketDetail = { @Sendable id in
            await MainActor.run {
                visibleTicket.value = store.selectedTicket
                visibleMessages.value = store.ticketMessages
            }
            let ticket = id == a.id ? a : b
            return (ticket, [Fixture.message(ticketId: ticket.id, body: "msg for \(ticket.subject)")])
        }
        let service = makeStubService(store: store, backend: backend)

        await service.fetchTicketDetail(a.id)
        visibleTicket.value = nil
        visibleMessages.value = []
        await service.fetchTicketDetail(b.id)

        #expect(visibleTicket.value == nil, "A's ticket must not be the current selection while B loads")
        #expect(visibleMessages.value.isEmpty, "A's messages must not render inside B's conversation")
        #expect(store.selectedTicket?.id == b.id)
    }

    @Test func aFailedTicketDetailLoadDoesNotLeaveThePreviousTicketSelected() async {
        let store = FeedbackStore()
        let a = Fixture.ticket(subject: "Ticket A")

        var backend = StubBackend()
        backend.ticketDetail = { @Sendable id in
            if id == a.id { return (a, [Fixture.message(ticketId: a.id)]) }
            throw StubError.boom
        }
        let service = makeStubService(store: store, backend: backend)

        await service.fetchTicketDetail(a.id)
        await service.fetchTicketDetail(UUID())

        #expect(store.selectedTicket == nil, "a failed load must not leave the previous ticket on screen")
        #expect(store.ticketMessages.isEmpty)
        #expect(store.error as? StubError == .boom)
    }

    @Test func reloadingTheSameFeatureKeepsItOnScreen() async {
        let store = FeedbackStore()
        let a = Fixture.feature(title: "Feature A")
        let visibleDuringReload = Box<UUID?>(nil)

        var backend = StubBackend()
        backend.featureRequest = { @Sendable _ in
            await MainActor.run { visibleDuringReload.value = store.selectedFeatureRequest?.id }
            return a
        }
        let service = makeStubService(store: store, backend: backend)

        await service.fetchFeatureRequest(a.id)
        await service.fetchFeatureRequest(a.id)

        #expect(
            visibleDuringReload.value == a.id,
            "refreshing the item already on screen must not blank it out"
        )
    }

    // MARK: - Bug 1: load errors surfaced, not swallowed

    @Test func aFailedFeatureListLoadIsAFailureStateNotAnEmptyState() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchFeatureRequests()

        let state = store.featureListState
        #expect(state.failureMessage?.isEmpty == false, "a failed load must give the view something to render")
        #expect(state.isEmpty == false, "a failed load must not masquerade as \"nothing here yet\"")
        #expect(state.isLoading == false)
    }

    @Test func anEmptyFeatureListIsAnEmptyStateNotAFailure() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in [] }

        await makeStubService(store: store, backend: backend).fetchFeatureRequests()

        let state = store.featureListState
        #expect(state.isEmpty == true)
        #expect(state.failureMessage == nil)
    }

    @Test func emptyAndFailedFeatureListStatesAreDistinguishable() async {
        let emptyStore = FeedbackStore()
        var emptyBackend = StubBackend()
        emptyBackend.featureRequests = { @Sendable in [] }
        await makeStubService(store: emptyStore, backend: emptyBackend).fetchFeatureRequests()

        let failedStore = FeedbackStore()
        var failingBackend = StubBackend()
        failingBackend.featureRequests = { @Sendable in throw StubError.boom }
        await makeStubService(store: failedStore, backend: failingBackend).fetchFeatureRequests()

        #expect(emptyStore.featureListState.isEmpty != failedStore.featureListState.isEmpty)
        #expect(emptyStore.featureListState.failureMessage == nil)
        #expect(failedStore.featureListState.failureMessage != nil)
    }

    @Test func aFailedTicketListLoadIsAFailureStateNotAnEmptyState() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.tickets = { @Sendable in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchTickets()

        let state = store.ticketListState
        #expect(state.failureMessage?.isEmpty == false)
        #expect(state.isEmpty == false)
    }

    @Test func anEmptyTicketListIsAnEmptyStateNotAFailure() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.tickets = { @Sendable in [] }

        await makeStubService(store: store, backend: backend).fetchTickets()

        #expect(store.ticketListState.isEmpty == true)
        #expect(store.ticketListState.failureMessage == nil)
    }

    @Test func anErrorOnTopOfAPopulatedListStillLeavesTheListRenderable() async {
        let store = FeedbackStore()
        let shouldFail = Box(false)
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in
            if shouldFail.value { throw StubError.boom }
            return [Fixture.feature(title: "A")]
        }
        let service = makeStubService(store: store, backend: backend)

        await service.fetchFeatureRequests()
        shouldFail.value = true
        await service.fetchFeatureRequests()

        #expect(store.featureListState.loaded?.count == 1, "a failed refresh must not discard rows already on screen")
        #expect(store.errorMessage?.isEmpty == false, "the failure must still be surfaced above the list")
    }

    @Test func aFailedFeatureDetailLoadIsRenderableAsAFailure() async {
        let store = FeedbackStore()
        let id = UUID()
        var backend = StubBackend()
        backend.featureRequest = { @Sendable _ in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchFeatureRequest(id)

        let state = store.featureDetailState(for: id)
        #expect(state.failureMessage?.isEmpty == false, "a failed detail fetch must not render as a blank page")
        #expect(state.loaded == nil)
    }

    @Test func aFailedTicketDetailLoadIsRenderableAsAFailure() async {
        let store = FeedbackStore()
        let id = UUID()
        var backend = StubBackend()
        backend.ticketDetail = { @Sendable _ in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchTicketDetail(id)

        let state = store.ticketDetailState(for: id)
        #expect(state.failureMessage?.isEmpty == false)
        #expect(state.loaded == nil)
    }

    @Test func aDetailStateNeverReportsAnotherItemAsLoaded() async {
        let store = FeedbackStore()
        let a = Fixture.feature(title: "Feature A")
        let bId = UUID()
        var backend = StubBackend()
        backend.featureRequest = { @Sendable _ in a }

        await makeStubService(store: store, backend: backend).fetchFeatureRequest(a.id)

        #expect(store.featureDetailState(for: a.id).loaded?.id == a.id)
        #expect(
            store.featureDetailState(for: bId).loaded == nil,
            "a third view asking for a different id must never be handed A's content"
        )
    }
}
