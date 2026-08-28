import Foundation
import Testing
@testable import GrantivaUI
import Grantiva

// MARK: - Errors

struct StubError: Error, Equatable {
    let label: String
    static let notStubbed = StubError(label: "not stubbed")
    static let boom = StubError(label: "boom")
}

// MARK: - Mutable capture box

/// `@Sendable` closures cannot capture `inout`/`var` locals, so tests that need to
/// observe state *during* an async operation record it into one of these.
final class Box<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}

// MARK: - Stub backend

/// A stand-in for the SDK's `FeedbackService`.
///
/// `FeedbackUIService.live(_:store:)` cannot be exercised directly from tests: the SDK's
/// `FeedbackService` actor has an `internal` initializer and `Grantiva` exposes no way to
/// point it at a test server, so any attempt to build one would either fail to compile or
/// make real network calls. `StubBackend` + `makeStubService(store:backend:)` therefore
/// reproduce the same wiring `live` uses, so these tests pin down the state machine that
/// `live` (and any future service implementation) must satisfy: which loading flag is
/// raised, that it is always lowered again, and what lands in the store on success,
/// on an empty result, and on failure.
struct StubBackend: Sendable {
    var featureRequests: @Sendable () async throws -> [FeatureRequest] = { throw StubError.notStubbed }
    var featureRequest: @Sendable (UUID) async throws -> FeatureRequest = { _ in throw StubError.notStubbed }
    var submitFeatureRequest: @Sendable (String, String) async throws -> FeatureRequest = { _, _ in throw StubError.notStubbed }
    var vote: @Sendable (UUID) async throws -> Void = { _ in throw StubError.notStubbed }
    var removeVote: @Sendable (UUID) async throws -> Void = { _ in throw StubError.notStubbed }
    var comments: @Sendable (UUID) async throws -> [FeatureComment] = { _ in throw StubError.notStubbed }
    var addComment: @Sendable (UUID, String) async throws -> FeatureComment = { _, _ in throw StubError.notStubbed }
    var tickets: @Sendable () async throws -> [SupportTicket] = { throw StubError.notStubbed }
    var ticketDetail: @Sendable (UUID) async throws -> (SupportTicket, [TicketMessage]) = { _ in throw StubError.notStubbed }
    var submitTicket: @Sendable (String, String, String?) async throws -> SupportTicket = { _, _, _ in throw StubError.notStubbed }
    var reply: @Sendable (UUID, String) async throws -> TicketMessage = { _, _ in throw StubError.notStubbed }
}

/// Mirrors the wiring in `FeedbackUIService.live(_:store:)` against a stubbed backend.
@MainActor
func makeStubService(store: FeedbackStore, backend: StubBackend) -> FeedbackUIService {
    FeedbackUIService(
        fetchFeatureRequests: { @Sendable in
            await MainActor.run { store.isLoadingFeatures = true }
            do {
                let requests = try await backend.featureRequests()
                await MainActor.run {
                    store.featureRequests = requests
                    store.isLoadingFeatures = false
                    store.error = nil
                }
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isLoadingFeatures = false
                }
            }
        },
        fetchFeatureRequest: { @Sendable id in
            await MainActor.run { store.beginFeatureDetailLoad(id: id) }
            do {
                let request = try await backend.featureRequest(id)
                await MainActor.run {
                    store.selectedFeatureRequest = request
                    store.isLoadingFeatureDetail = false
                    store.error = nil
                }
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isLoadingFeatureDetail = false
                }
            }
        },
        submitFeatureRequest: { @Sendable title, description in
            await MainActor.run { store.isSubmitting = true }
            do {
                let created = try await backend.submitFeatureRequest(title, description)
                await MainActor.run {
                    store.featureRequests.insert(created, at: 0)
                    store.isSubmitting = false
                    store.error = nil
                }
                return true
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isSubmitting = false
                }
                return false
            }
        },
        vote: { @Sendable id in
            do {
                try await backend.vote(id)
                await MainActor.run {
                    if let index = store.featureRequests.firstIndex(where: { $0.id == id }) {
                        store.featureRequests[index] = store.featureRequests[index].applyingVote()
                    }
                    if store.selectedFeatureRequest?.id == id, let old = store.selectedFeatureRequest {
                        store.selectedFeatureRequest = old.applyingVote()
                    }
                    store.error = nil
                }
            } catch {
                await MainActor.run { store.error = error }
            }
        },
        removeVote: { @Sendable id in
            do {
                try await backend.removeVote(id)
                await MainActor.run {
                    if let index = store.featureRequests.firstIndex(where: { $0.id == id }) {
                        store.featureRequests[index] = store.featureRequests[index].removingVote()
                    }
                    if store.selectedFeatureRequest?.id == id, let old = store.selectedFeatureRequest {
                        store.selectedFeatureRequest = old.removingVote()
                    }
                    store.error = nil
                }
            } catch {
                await MainActor.run { store.error = error }
            }
        },
        fetchComments: { @Sendable featureId in
            await MainActor.run { store.beginCommentsLoad(featureId: featureId) }
            do {
                let comments = try await backend.comments(featureId)
                await MainActor.run {
                    store.featureComments = comments
                    store.isLoadingComments = false
                    store.error = nil
                }
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isLoadingComments = false
                }
            }
        },
        addComment: { @Sendable featureId, body in
            await MainActor.run { store.isSubmitting = true }
            do {
                let comment = try await backend.addComment(featureId, body)
                await MainActor.run {
                    store.featureComments.append(comment)
                    store.isSubmitting = false
                    store.error = nil
                }
                return true
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isSubmitting = false
                }
                return false
            }
        },
        fetchTickets: { @Sendable in
            await MainActor.run { store.isLoadingTickets = true }
            do {
                let tickets = try await backend.tickets()
                await MainActor.run {
                    store.tickets = tickets
                    store.isLoadingTickets = false
                    store.error = nil
                }
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isLoadingTickets = false
                }
            }
        },
        fetchTicketDetail: { @Sendable id in
            await MainActor.run { store.beginTicketDetailLoad(id: id) }
            do {
                let (ticket, messages) = try await backend.ticketDetail(id)
                await MainActor.run {
                    store.selectedTicket = ticket
                    store.ticketMessages = messages
                    store.isLoadingTicketDetail = false
                    store.error = nil
                }
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isLoadingTicketDetail = false
                }
            }
        },
        submitTicket: { @Sendable subject, body, email in
            await MainActor.run { store.isSubmitting = true }
            do {
                let ticket = try await backend.submitTicket(subject, body, email)
                await MainActor.run {
                    store.tickets.insert(ticket, at: 0)
                    store.isSubmitting = false
                    store.error = nil
                }
                return true
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isSubmitting = false
                }
                return false
            }
        },
        replyToTicket: { @Sendable ticketId, body in
            await MainActor.run { store.isSubmitting = true }
            do {
                let message = try await backend.reply(ticketId, body)
                await MainActor.run {
                    store.ticketMessages.append(message)
                    store.isSubmitting = false
                    store.error = nil
                }
                return true
            } catch {
                await MainActor.run {
                    store.error = error
                    store.isSubmitting = false
                }
                return false
            }
        }
    )
}

// MARK: - Model helpers

extension FeatureRequest {
    func applyingVote() -> FeatureRequest {
        FeatureRequest(
            id: id, title: title, description: description, status: status,
            voteCount: voteCount + 1, hasVoted: true, commentCount: commentCount,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func removingVote() -> FeatureRequest {
        FeatureRequest(
            id: id, title: title, description: description, status: status,
            voteCount: max(0, voteCount - 1), hasVoted: false, commentCount: commentCount,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

// MARK: - Fixtures

enum Fixture {
    static func feature(
        id: UUID = UUID(),
        title: String = "Dark mode",
        status: FeatureRequestStatus = .open,
        voteCount: Int = 3,
        hasVoted: Bool = false,
        commentCount: Int = 0
    ) -> FeatureRequest {
        FeatureRequest(
            id: id, title: title, description: "A description.", status: status,
            voteCount: voteCount, hasVoted: hasVoted, commentCount: commentCount,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
    }

    static func comment(featureId: UUID = UUID(), body: String = "Nice idea.") -> FeatureComment {
        FeatureComment(
            id: UUID(), featureRequestId: featureId, authorType: .user, body: body,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func ticket(
        id: UUID = UUID(),
        subject: String = "Cannot log in",
        status: TicketStatus = .open,
        priority: TicketPriority = .normal,
        messageCount: Int = 1
    ) -> SupportTicket {
        SupportTicket(
            id: id, subject: subject, status: status, priority: priority,
            messageCount: messageCount,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
    }

    static func message(ticketId: UUID = UUID(), body: String = "Any update?") -> TicketMessage {
        TicketMessage(
            id: UUID(), ticketId: ticketId, authorType: .user, body: body,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
