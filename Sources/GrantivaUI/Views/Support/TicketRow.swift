import SwiftUI
import Grantiva

/// A single row in the support ticket list.
struct TicketRow: View {
    let ticket: SupportTicket
    @Environment(\.grantivaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ticket.subject)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                StatusBadge(ticketStatus: ticket.status)
            }

            HStack(spacing: 12) {
                StatusBadge(priority: ticket.priority)

                Label("\(ticket.messageCount)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                RelativeTimeText(date: ticket.updatedAt)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        TicketRow(ticket: SupportTicket(
            id: UUID(),
            subject: "Cannot reset my password",
            status: .open,
            priority: .high,
            messageCount: 3,
            createdAt: .now.addingTimeInterval(-86400),
            updatedAt: .now.addingTimeInterval(-3600)
        ))
        TicketRow(ticket: SupportTicket(
            id: UUID(),
            subject: "Billing question about Pro plan",
            status: .awaitingReply,
            priority: .normal,
            messageCount: 1,
            createdAt: .now.addingTimeInterval(-86400 * 5),
            updatedAt: .now.addingTimeInterval(-86400 * 2)
        ))
    }
    .listStyle(.plain)
}
