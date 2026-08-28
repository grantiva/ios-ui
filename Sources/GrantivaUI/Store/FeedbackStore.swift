import Foundation
import Grantiva

/// What a view should render for one piece of feedback content.
///
/// Views switch on this instead of inspecting the store's raw flags, so "nothing here
/// yet" and "we could not load this" can never collapse into the same empty state.
public enum FeedbackContentState<Content: Sendable>: Sendable {
    /// A load is in flight and there is nothing valid to show yet.
    case loading
    /// A load failed. `message` is presentable to the user.
    case failed(message: String)
    /// The load succeeded and there is genuinely nothing to show.
    case empty
    /// Content is available and belongs to what the view asked for.
    case loaded(Content)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    /// The user-facing failure message, or `nil` when this is not a failure.
    public var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }

    /// The loaded content, or `nil` in every other state.
    public var loaded: Content? {
        if case .loaded(let content) = self { return content }
        return nil
    }
}

/// Observable store holding all feedback state.
///
/// Views observe this directly — no view models needed.
/// Mutated only through `FeedbackService` closures.
@MainActor
@Observable
public final class FeedbackStore {
    public var featureRequests: [FeatureRequest] = []
    public var selectedFeatureRequest: FeatureRequest?
    public var featureComments: [FeatureComment] = []
    public var tickets: [SupportTicket] = []
    public var selectedTicket: SupportTicket?
    public var ticketMessages: [TicketMessage] = []

    public var isLoadingFeatures: Bool = false
    public var isLoadingFeatureDetail: Bool = false
    public var isLoadingComments: Bool = false
    public var isLoadingTickets: Bool = false
    public var isLoadingTicketDetail: Bool = false
    public var isSubmitting: Bool = false

    public var error: Error?

    public init() {}

    // MARK: - Error presentation

    /// The current error rendered as a user-facing string, or `nil` when there is none.
    public var errorMessage: String? {
        error.map { $0.localizedDescription }
    }

    // MARK: - List states

    public var featureListState: FeedbackContentState<[FeatureRequest]> {
        Self.listState(items: featureRequests, isLoading: isLoadingFeatures, errorMessage: errorMessage)
    }

    public var ticketListState: FeedbackContentState<[SupportTicket]> {
        Self.listState(items: tickets, isLoading: isLoadingTickets, errorMessage: errorMessage)
    }

    private static func listState<Item: Sendable>(
        items: [Item],
        isLoading: Bool,
        errorMessage: String?
    ) -> FeedbackContentState<[Item]> {
        // Rows already on screen survive a failed refresh; the failure is surfaced
        // alongside them via `errorMessage` rather than replacing them.
        if !items.isEmpty { return .loaded(items) }
        if isLoading { return .loading }
        if let errorMessage { return .failed(message: errorMessage) }
        return .empty
    }

    // MARK: - Detail states

    /// State for the feature request detail view showing `id`.
    ///
    /// Content is only ever reported as `.loaded` when it is the item the caller asked
    /// for, so a detail view can never render another item's content — including a
    /// third view added later that this store knows nothing about.
    public func featureDetailState(for id: UUID) -> FeedbackContentState<FeatureRequest> {
        Self.detailState(
            selected: selectedFeatureRequest,
            matches: { $0.id == id },
            isLoading: isLoadingFeatureDetail,
            errorMessage: errorMessage
        )
    }

    /// State for the ticket detail view showing `id`. See `featureDetailState(for:)`.
    public func ticketDetailState(for id: UUID) -> FeedbackContentState<SupportTicket> {
        Self.detailState(
            selected: selectedTicket,
            matches: { $0.id == id },
            isLoading: isLoadingTicketDetail,
            errorMessage: errorMessage
        )
    }

    private static func detailState<Item: Sendable>(
        selected: Item?,
        matches: (Item) -> Bool,
        isLoading: Bool,
        errorMessage: String?
    ) -> FeedbackContentState<Item> {
        // Identity first: refreshing the item already on screen must not blank it out.
        if let selected, matches(selected) { return .loaded(selected) }
        if isLoading { return .loading }
        if let errorMessage { return .failed(message: errorMessage) }
        // Nothing selected, nothing failed — the fetch has not started yet.
        return .loading
    }

    /// Comments belonging to `featureId`, ignoring any left over from another feature.
    public func comments(for featureId: UUID) -> [FeatureComment] {
        featureComments.filter { $0.featureRequestId == featureId }
    }

    /// Messages belonging to `ticketId`, ignoring any left over from another ticket.
    public func messages(for ticketId: UUID) -> [TicketMessage] {
        ticketMessages.filter { $0.ticketId == ticketId }
    }

    // MARK: - Detail load lifecycle

    /// Marks the start of a feature request detail load.
    ///
    /// Discards the previous selection (and its comments) when a *different* item is
    /// being loaded, so no view can show item A's content while item B is in flight.
    /// Reloading the item already on screen leaves it in place.
    public func beginFeatureDetailLoad(id: UUID) {
        if selectedFeatureRequest?.id != id {
            selectedFeatureRequest = nil
            featureComments = []
        }
        isLoadingFeatureDetail = true
    }

    /// Marks the start of a ticket detail load. See `beginFeatureDetailLoad(id:)`.
    public func beginTicketDetailLoad(id: UUID) {
        if selectedTicket?.id != id {
            selectedTicket = nil
            ticketMessages = []
        }
        isLoadingTicketDetail = true
    }

    /// Marks the start of a comments load for `featureId`, dropping comments that
    /// belong to a different feature request.
    public func beginCommentsLoad(featureId: UUID) {
        if featureComments.contains(where: { $0.featureRequestId != featureId }) {
            featureComments = []
        }
        isLoadingComments = true
    }
}
