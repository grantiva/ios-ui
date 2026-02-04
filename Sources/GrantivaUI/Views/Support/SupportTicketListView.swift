import SwiftUI
import Grantiva

/// Displays a list of the user's support tickets.
public struct SupportTicketListView: View {
    @Environment(\.feedbackService) private var service
    @Environment(\.grantivaTheme) private var theme
    var store: FeedbackStore
    var onSelect: (SupportTicket) -> Void

    public init(store: FeedbackStore, onSelect: @escaping (SupportTicket) -> Void) {
        self.store = store
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            if store.isLoadingTickets && store.tickets.isEmpty {
                LoadingView(message: "Loading tickets…")
            } else if store.tickets.isEmpty {
                ContentUnavailableView(
                    "No Support Tickets",
                    systemImage: "ticket",
                    description: Text("Submit a ticket if you need help.")
                )
            } else {
                List(store.tickets) { ticket in
                    TicketRow(ticket: ticket)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(ticket) }
                }
                .listStyle(.plain)
                .refreshable {
                    await service.fetchTickets()
                }
            }
        }
        .task {
            await service.fetchTickets()
        }
    }
}

#Preview {
    let store = FeedbackStore()
    store.tickets = [
        SupportTicket(id: UUID(), subject: "Cannot reset my password", status: .open, priority: .high, messageCount: 3, createdAt: .now.addingTimeInterval(-86400), updatedAt: .now.addingTimeInterval(-3600)),
        SupportTicket(id: UUID(), subject: "Billing question about Pro plan", status: .awaitingReply, priority: .normal, messageCount: 1, createdAt: .now.addingTimeInterval(-86400 * 5), updatedAt: .now.addingTimeInterval(-86400 * 2)),
    ]
    return SupportTicketListView(store: store, onSelect: { _ in })
        .feedbackService(.preview)
}

#Preview("Empty") {
    SupportTicketListView(store: FeedbackStore(), onSelect: { _ in })
        .feedbackService(.preview)
}
