import Foundation
import SwiftUI
import Grantiva

/// Closure-based service for feedback operations.
///
/// Each operation is a closure that can be swapped for testing or previews.
/// Inject via the SwiftUI environment:
///
/// ```swift
/// ContentView()
///     .feedbackService(.live(grantiva.feedback, store: store))
/// ```
public struct FeedbackUIService: Sendable {
    public var fetchFeatureRequests: @Sendable () async -> Void
    public var fetchFeatureRequest: @Sendable (UUID) async -> Void
    public var submitFeatureRequest: @Sendable (String, String) async -> Bool
    public var vote: @Sendable (UUID) async -> Void
    public var removeVote: @Sendable (UUID) async -> Void
    public var fetchComments: @Sendable (UUID) async -> Void
    public var addComment: @Sendable (UUID, String) async -> Bool
    public var fetchTickets: @Sendable () async -> Void
    public var fetchTicketDetail: @Sendable (UUID) async -> Void
    public var submitTicket: @Sendable (String, String, String?) async -> Bool
    public var replyToTicket: @Sendable (UUID, String) async -> Bool

    public init(
        fetchFeatureRequests: @escaping @Sendable () async -> Void,
        fetchFeatureRequest: @escaping @Sendable (UUID) async -> Void,
        submitFeatureRequest: @escaping @Sendable (String, String) async -> Bool,
        vote: @escaping @Sendable (UUID) async -> Void,
        removeVote: @escaping @Sendable (UUID) async -> Void,
        fetchComments: @escaping @Sendable (UUID) async -> Void,
        addComment: @escaping @Sendable (UUID, String) async -> Bool,
        fetchTickets: @escaping @Sendable () async -> Void,
        fetchTicketDetail: @escaping @Sendable (UUID) async -> Void,
        submitTicket: @escaping @Sendable (String, String, String?) async -> Bool,
        replyToTicket: @escaping @Sendable (UUID, String) async -> Bool
    ) {
        self.fetchFeatureRequests = fetchFeatureRequests
        self.fetchFeatureRequest = fetchFeatureRequest
        self.submitFeatureRequest = submitFeatureRequest
        self.vote = vote
        self.removeVote = removeVote
        self.fetchComments = fetchComments
        self.addComment = addComment
        self.fetchTickets = fetchTickets
        self.fetchTicketDetail = fetchTicketDetail
        self.submitTicket = submitTicket
        self.replyToTicket = replyToTicket
    }
}

// MARK: - Live Implementation

extension FeedbackUIService {
    /// Creates a live service backed by the SDK's `FeedbackService`.
    public static func live(_ sdk: FeedbackService, store: FeedbackStore) -> FeedbackUIService {
        return FeedbackUIService(
            fetchFeatureRequests: { @Sendable in
                await MainActor.run { store.isLoadingFeatures = true }
                do {
                    let requests = try await sdk.getFeatureRequests()
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
                await MainActor.run { store.isLoadingFeatureDetail = true }
                do {
                    let request = try await sdk.getFeatureRequest(id: id)
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
                    let created = try await sdk.submitFeatureRequest(title: title, description: description)
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
                    try await sdk.vote(for: id)
                    await MainActor.run {
                        if let index = store.featureRequests.firstIndex(where: { $0.id == id }) {
                            let old = store.featureRequests[index]
                            store.featureRequests[index] = FeatureRequest(
                                id: old.id, title: old.title, description: old.description,
                                status: old.status, voteCount: old.voteCount + 1, hasVoted: true,
                                commentCount: old.commentCount, createdAt: old.createdAt, updatedAt: old.updatedAt
                            )
                        }
                        if store.selectedFeatureRequest?.id == id, let old = store.selectedFeatureRequest {
                            store.selectedFeatureRequest = FeatureRequest(
                                id: old.id, title: old.title, description: old.description,
                                status: old.status, voteCount: old.voteCount + 1, hasVoted: true,
                                commentCount: old.commentCount, createdAt: old.createdAt, updatedAt: old.updatedAt
                            )
                        }
                        store.error = nil
                    }
                } catch {
                    await MainActor.run { store.error = error }
                }
            },
            removeVote: { @Sendable id in
                do {
                    try await sdk.removeVote(for: id)
                    await MainActor.run {
                        if let index = store.featureRequests.firstIndex(where: { $0.id == id }) {
                            let old = store.featureRequests[index]
                            store.featureRequests[index] = FeatureRequest(
                                id: old.id, title: old.title, description: old.description,
                                status: old.status, voteCount: max(0, old.voteCount - 1), hasVoted: false,
                                commentCount: old.commentCount, createdAt: old.createdAt, updatedAt: old.updatedAt
                            )
                        }
                        if store.selectedFeatureRequest?.id == id, let old = store.selectedFeatureRequest {
                            store.selectedFeatureRequest = FeatureRequest(
                                id: old.id, title: old.title, description: old.description,
                                status: old.status, voteCount: max(0, old.voteCount - 1), hasVoted: false,
                                commentCount: old.commentCount, createdAt: old.createdAt, updatedAt: old.updatedAt
                            )
                        }
                        store.error = nil
                    }
                } catch {
                    await MainActor.run { store.error = error }
                }
            },
            fetchComments: { @Sendable featureId in
                await MainActor.run { store.isLoadingComments = true }
                do {
                    let comments = try await sdk.getComments(for: featureId)
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
                    let comment = try await sdk.addComment(to: featureId, body: body)
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
                    let tickets = try await sdk.getUsersTickets()
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
                await MainActor.run { store.isLoadingTicketDetail = true }
                do {
                    let result = try await sdk.getTicket(id: id)
                    await MainActor.run {
                        store.selectedTicket = result.ticket
                        store.ticketMessages = result.messages
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
                    let ticket = try await sdk.submitTicket(subject: subject, body: body, email: email)
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
                    let message = try await sdk.reply(to: ticketId, body: body)
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
}

// MARK: - Preview / Unimplemented

extension FeedbackUIService {
    /// A no-op service for SwiftUI previews.
    public static let preview = FeedbackUIService(
        fetchFeatureRequests: {},
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
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry public var feedbackService: FeedbackUIService = .preview
}

extension View {
    public func feedbackService(_ service: FeedbackUIService) -> some View {
        environment(\.feedbackService, service)
    }
}
