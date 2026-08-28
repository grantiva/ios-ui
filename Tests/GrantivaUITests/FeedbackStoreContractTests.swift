import Foundation
import Testing
@testable import GrantivaUI
import Grantiva

@MainActor
@Suite("FeedbackStore state transitions")
struct FeedbackStoreContractTests {

    // MARK: - Feature request list

    @Test func loadFeatureRequestsSuccessPopulatesStoreAndClearsSpinner() async {
        let store = FeedbackStore()
        let observedLoading = Box(false)
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in
            await MainActor.run { observedLoading.value = store.isLoadingFeatures }
            return [Fixture.feature(title: "A"), Fixture.feature(title: "B")]
        }

        await makeStubService(store: store, backend: backend).fetchFeatureRequests()

        #expect(observedLoading.value == true, "spinner must be raised while the fetch is in flight")
        #expect(store.isLoadingFeatures == false)
        #expect(store.featureRequests.map(\.title) == ["A", "B"])
        #expect(store.error == nil)
    }

    @Test func loadFeatureRequestsEmptyResultIsNotAnError() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in [] }

        await makeStubService(store: store, backend: backend).fetchFeatureRequests()

        #expect(store.featureRequests.isEmpty)
        #expect(store.isLoadingFeatures == false)
        #expect(store.error == nil)
    }

    @Test func loadFeatureRequestsFailureRecordsErrorAndClearsSpinner() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchFeatureRequests()

        #expect(store.isLoadingFeatures == false, "a failed fetch must not leave a stuck spinner")
        #expect(store.error as? StubError == .boom)
        #expect(store.error?.localizedDescription.isEmpty == false, "error must be presentable to a user")
    }

    @Test func successfulRefreshClearsAPreviousError() async {
        let store = FeedbackStore()
        let shouldFail = Box(true)
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in
            if shouldFail.value { throw StubError.boom }
            return [Fixture.feature()]
        }
        let service = makeStubService(store: store, backend: backend)

        await service.fetchFeatureRequests()
        #expect(store.error != nil)

        shouldFail.value = false
        await service.fetchFeatureRequests()

        #expect(store.error == nil)
        #expect(store.featureRequests.count == 1)
        #expect(store.isLoadingFeatures == false)
    }

    @Test func failedRefreshKeepsPreviouslyLoadedRows() async {
        let store = FeedbackStore()
        store.featureRequests = [Fixture.feature(title: "Cached")]
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchFeatureRequests()

        #expect(store.featureRequests.map(\.title) == ["Cached"])
        #expect(store.error != nil)
    }

    // MARK: - Feature request detail

    @Test func loadFeatureRequestDetailSuccess() async {
        let store = FeedbackStore()
        let id = UUID()
        let observedLoading = Box(false)
        var backend = StubBackend()
        backend.featureRequest = { @Sendable requested in
            await MainActor.run { observedLoading.value = store.isLoadingFeatureDetail }
            #expect(requested == id)
            return Fixture.feature(id: id, title: "Detail")
        }

        await makeStubService(store: store, backend: backend).fetchFeatureRequest(id)

        #expect(observedLoading.value == true)
        #expect(store.isLoadingFeatureDetail == false)
        #expect(store.selectedFeatureRequest?.title == "Detail")
        #expect(store.error == nil)
    }

    @Test func loadFeatureRequestDetailFailureClearsSpinner() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.featureRequest = { @Sendable _ in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchFeatureRequest(UUID())

        #expect(store.isLoadingFeatureDetail == false)
        #expect(store.selectedFeatureRequest == nil)
        #expect(store.error != nil)
    }

    // MARK: - Submitting a feature request

    @Test func submitFeatureRequestSuccessPrependsAndClearsSubmitting() async {
        let store = FeedbackStore()
        store.featureRequests = [Fixture.feature(title: "Existing")]
        let observedSubmitting = Box(false)
        var backend = StubBackend()
        backend.submitFeatureRequest = { @Sendable title, description in
            await MainActor.run { observedSubmitting.value = store.isSubmitting }
            #expect(title == "New idea")
            #expect(description == "Please add it.")
            return Fixture.feature(title: title)
        }

        let ok = await makeStubService(store: store, backend: backend)
            .submitFeatureRequest("New idea", "Please add it.")

        #expect(ok == true)
        #expect(observedSubmitting.value == true)
        #expect(store.isSubmitting == false)
        #expect(store.featureRequests.map(\.title) == ["New idea", "Existing"])
        #expect(store.error == nil)
    }

    @Test func submitFeatureRequestFailureReportsFalseAndClearsSubmitting() async {
        let store = FeedbackStore()
        store.featureRequests = [Fixture.feature(title: "Existing")]
        var backend = StubBackend()
        backend.submitFeatureRequest = { @Sendable _, _ in throw StubError.boom }

        let ok = await makeStubService(store: store, backend: backend)
            .submitFeatureRequest("New idea", "Please add it.")

        #expect(ok == false)
        #expect(store.isSubmitting == false, "a failed submit must re-enable the submit button")
        #expect(store.featureRequests.map(\.title) == ["Existing"], "nothing is inserted when the submit fails")
        #expect(store.error != nil)
    }

    // MARK: - Voting

    @Test func voteIncrementsCountAndMarksVoted() async {
        let store = FeedbackStore()
        let id = UUID()
        store.featureRequests = [Fixture.feature(id: id, voteCount: 3, hasVoted: false)]
        var backend = StubBackend()
        backend.vote = { @Sendable _ in }

        await makeStubService(store: store, backend: backend).vote(id)

        #expect(store.featureRequests[0].voteCount == 4)
        #expect(store.featureRequests[0].hasVoted == true)
        #expect(store.error == nil)
    }

    @Test func voteAlsoUpdatesTheSelectedFeatureRequest() async {
        let store = FeedbackStore()
        let id = UUID()
        store.featureRequests = [Fixture.feature(id: id, voteCount: 3)]
        store.selectedFeatureRequest = Fixture.feature(id: id, voteCount: 3)
        var backend = StubBackend()
        backend.vote = { @Sendable _ in }

        await makeStubService(store: store, backend: backend).vote(id)

        #expect(store.selectedFeatureRequest?.voteCount == 4)
        #expect(store.selectedFeatureRequest?.hasVoted == true)
    }

    @Test func voteLeavesUnrelatedRowsAlone() async {
        let store = FeedbackStore()
        let id = UUID()
        let otherId = UUID()
        store.featureRequests = [
            Fixture.feature(id: id, title: "Voted", voteCount: 1),
            Fixture.feature(id: otherId, title: "Untouched", voteCount: 9)
        ]
        var backend = StubBackend()
        backend.vote = { @Sendable _ in }

        await makeStubService(store: store, backend: backend).vote(id)

        #expect(store.featureRequests[0].voteCount == 2)
        #expect(store.featureRequests[1].voteCount == 9)
        #expect(store.featureRequests[1].hasVoted == false)
    }

    /// The vote is applied only *after* the backend call succeeds — there is no optimistic
    /// increment — so a failed vote must leave the count exactly where it was.
    @Test func failedVoteLeavesCountUnchanged() async {
        let store = FeedbackStore()
        let id = UUID()
        store.featureRequests = [Fixture.feature(id: id, voteCount: 3, hasVoted: false)]
        store.selectedFeatureRequest = Fixture.feature(id: id, voteCount: 3, hasVoted: false)
        var backend = StubBackend()
        backend.vote = { @Sendable _ in throw StubError.boom }

        await makeStubService(store: store, backend: backend).vote(id)

        #expect(store.featureRequests[0].voteCount == 3)
        #expect(store.featureRequests[0].hasVoted == false)
        #expect(store.selectedFeatureRequest?.voteCount == 3)
        #expect(store.error != nil)
    }

    @Test func removeVoteDecrementsCountAndClearsVoted() async {
        let store = FeedbackStore()
        let id = UUID()
        store.featureRequests = [Fixture.feature(id: id, voteCount: 4, hasVoted: true)]
        var backend = StubBackend()
        backend.removeVote = { @Sendable _ in }

        await makeStubService(store: store, backend: backend).removeVote(id)

        #expect(store.featureRequests[0].voteCount == 3)
        #expect(store.featureRequests[0].hasVoted == false)
    }

    @Test func removeVoteNeverProducesANegativeCount() async {
        let store = FeedbackStore()
        let id = UUID()
        store.featureRequests = [Fixture.feature(id: id, voteCount: 0, hasVoted: true)]
        var backend = StubBackend()
        backend.removeVote = { @Sendable _ in }

        await makeStubService(store: store, backend: backend).removeVote(id)

        #expect(store.featureRequests[0].voteCount == 0)
    }

    @Test func failedRemoveVoteLeavesCountUnchanged() async {
        let store = FeedbackStore()
        let id = UUID()
        store.featureRequests = [Fixture.feature(id: id, voteCount: 4, hasVoted: true)]
        var backend = StubBackend()
        backend.removeVote = { @Sendable _ in throw StubError.boom }

        await makeStubService(store: store, backend: backend).removeVote(id)

        #expect(store.featureRequests[0].voteCount == 4)
        #expect(store.featureRequests[0].hasVoted == true)
        #expect(store.error != nil)
    }

    @Test func voteForAnUnknownIdIsANoOp() async {
        let store = FeedbackStore()
        store.featureRequests = [Fixture.feature(voteCount: 2)]
        var backend = StubBackend()
        backend.vote = { @Sendable _ in }

        await makeStubService(store: store, backend: backend).vote(UUID())

        #expect(store.featureRequests[0].voteCount == 2)
        #expect(store.error == nil)
    }

    // MARK: - Comments

    @Test func fetchCommentsSuccessAndSpinnerLifecycle() async {
        let store = FeedbackStore()
        let featureId = UUID()
        let observedLoading = Box(false)
        var backend = StubBackend()
        backend.comments = { @Sendable _ in
            await MainActor.run { observedLoading.value = store.isLoadingComments }
            return [Fixture.comment(featureId: featureId, body: "First")]
        }

        await makeStubService(store: store, backend: backend).fetchComments(featureId)

        #expect(observedLoading.value == true)
        #expect(store.isLoadingComments == false)
        #expect(store.featureComments.map(\.body) == ["First"])
    }

    @Test func fetchCommentsFailureClearsSpinner() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.comments = { @Sendable _ in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchComments(UUID())

        #expect(store.isLoadingComments == false)
        #expect(store.error != nil)
    }

    @Test func addCommentAppendsToTheExistingThread() async {
        let store = FeedbackStore()
        let featureId = UUID()
        store.featureComments = [Fixture.comment(featureId: featureId, body: "First")]
        var backend = StubBackend()
        backend.addComment = { @Sendable id, body in
            #expect(id == featureId)
            return Fixture.comment(featureId: id, body: body)
        }

        let ok = await makeStubService(store: store, backend: backend).addComment(featureId, "Second")

        #expect(ok == true)
        #expect(store.featureComments.map(\.body) == ["First", "Second"])
        #expect(store.isSubmitting == false)
    }

    @Test func addCommentFailureDoesNotAppendAndClearsSubmitting() async {
        let store = FeedbackStore()
        store.featureComments = [Fixture.comment(body: "First")]
        var backend = StubBackend()
        backend.addComment = { @Sendable _, _ in throw StubError.boom }

        let ok = await makeStubService(store: store, backend: backend).addComment(UUID(), "Second")

        #expect(ok == false)
        #expect(store.featureComments.map(\.body) == ["First"])
        #expect(store.isSubmitting == false)
        #expect(store.error != nil)
    }

    // MARK: - Tickets

    @Test func fetchTicketsSuccessAndSpinnerLifecycle() async {
        let store = FeedbackStore()
        let observedLoading = Box(false)
        var backend = StubBackend()
        backend.tickets = { @Sendable in
            await MainActor.run { observedLoading.value = store.isLoadingTickets }
            return [Fixture.ticket(subject: "Help")]
        }

        await makeStubService(store: store, backend: backend).fetchTickets()

        #expect(observedLoading.value == true)
        #expect(store.isLoadingTickets == false)
        #expect(store.tickets.map(\.subject) == ["Help"])
        #expect(store.error == nil)
    }

    @Test func fetchTicketsEmptyResultIsNotAnError() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.tickets = { @Sendable in [] }

        await makeStubService(store: store, backend: backend).fetchTickets()

        #expect(store.tickets.isEmpty)
        #expect(store.isLoadingTickets == false)
        #expect(store.error == nil)
    }

    @Test func fetchTicketsFailureClearsSpinner() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.tickets = { @Sendable in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchTickets()

        #expect(store.isLoadingTickets == false)
        #expect(store.error != nil)
    }

    @Test func fetchTicketDetailLoadsTicketAndMessages() async {
        let store = FeedbackStore()
        let id = UUID()
        var backend = StubBackend()
        backend.ticketDetail = { @Sendable requested in
            #expect(requested == id)
            return (Fixture.ticket(id: id, subject: "Login"), [
                Fixture.message(ticketId: id, body: "Hi"),
                Fixture.message(ticketId: id, body: "Thanks")
            ])
        }

        await makeStubService(store: store, backend: backend).fetchTicketDetail(id)

        #expect(store.selectedTicket?.subject == "Login")
        #expect(store.ticketMessages.map(\.body) == ["Hi", "Thanks"])
        #expect(store.isLoadingTicketDetail == false)
    }

    @Test func fetchTicketDetailFailureClearsSpinner() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.ticketDetail = { @Sendable _ in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchTicketDetail(UUID())

        #expect(store.isLoadingTicketDetail == false)
        #expect(store.selectedTicket == nil)
        #expect(store.error != nil)
    }

    @Test func submitTicketPrependsToTheList() async {
        let store = FeedbackStore()
        store.tickets = [Fixture.ticket(subject: "Older")]
        var backend = StubBackend()
        backend.submitTicket = { @Sendable subject, body, email in
            #expect(body == "It crashes.")
            #expect(email == "me@example.com")
            return Fixture.ticket(subject: subject)
        }

        let ok = await makeStubService(store: store, backend: backend)
            .submitTicket("Crash", "It crashes.", "me@example.com")

        #expect(ok == true)
        #expect(store.tickets.map(\.subject) == ["Crash", "Older"])
        #expect(store.isSubmitting == false)
    }

    @Test func submitTicketAcceptsANilEmail() async {
        let store = FeedbackStore()
        let sawNilEmail = Box(false)
        var backend = StubBackend()
        backend.submitTicket = { @Sendable subject, _, email in
            await MainActor.run { sawNilEmail.value = (email == nil) }
            return Fixture.ticket(subject: subject)
        }

        let ok = await makeStubService(store: store, backend: backend)
            .submitTicket("Crash", "It crashes.", nil)

        #expect(ok == true)
        #expect(sawNilEmail.value == true, "a nil email must reach the backend as nil, not as an empty string")
    }

    @Test func submitTicketFailureClearsSubmitting() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.submitTicket = { @Sendable _, _, _ in throw StubError.boom }

        let ok = await makeStubService(store: store, backend: backend)
            .submitTicket("Crash", "It crashes.", nil)

        #expect(ok == false)
        #expect(store.tickets.isEmpty)
        #expect(store.isSubmitting == false)
        #expect(store.error != nil)
    }

    @Test func replyToTicketAppendsMessage() async {
        let store = FeedbackStore()
        let id = UUID()
        store.ticketMessages = [Fixture.message(ticketId: id, body: "Hi")]
        var backend = StubBackend()
        backend.reply = { @Sendable ticketId, body in
            #expect(ticketId == id)
            return Fixture.message(ticketId: ticketId, body: body)
        }

        let ok = await makeStubService(store: store, backend: backend).replyToTicket(id, "Any update?")

        #expect(ok == true)
        #expect(store.ticketMessages.map(\.body) == ["Hi", "Any update?"])
        #expect(store.isSubmitting == false)
    }

    @Test func replyToTicketFailureDoesNotAppendAndClearsSubmitting() async {
        let store = FeedbackStore()
        let id = UUID()
        store.ticketMessages = [Fixture.message(ticketId: id, body: "Hi")]
        var backend = StubBackend()
        backend.reply = { @Sendable _, _ in throw StubError.boom }

        let ok = await makeStubService(store: store, backend: backend).replyToTicket(id, "Any update?")

        #expect(ok == false)
        #expect(store.ticketMessages.map(\.body) == ["Hi"])
        #expect(store.isSubmitting == false)
        #expect(store.error != nil)
    }

    // MARK: - Cross-cutting

    @Test func featureAndTicketSpinnersAreIndependent() async {
        let store = FeedbackStore()
        var backend = StubBackend()
        backend.featureRequests = { @Sendable in throw StubError.boom }

        await makeStubService(store: store, backend: backend).fetchFeatureRequests()

        #expect(store.isLoadingFeatures == false)
        #expect(store.isLoadingTickets == false)
        #expect(store.isLoadingComments == false)
        #expect(store.isLoadingFeatureDetail == false)
        #expect(store.isLoadingTicketDetail == false)
        #expect(store.isSubmitting == false)
    }
}
