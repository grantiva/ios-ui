import Foundation
import Grantiva

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
}
