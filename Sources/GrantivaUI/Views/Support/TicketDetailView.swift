import SwiftUI
import Grantiva

/// Detail view for a support ticket conversation.
public struct TicketDetailView: View {
    @Environment(\.feedbackService) private var service
    @Environment(\.grantivaTheme) private var theme
    var store: FeedbackStore
    let ticketId: UUID

    @State private var reply: String = ""

    public init(store: FeedbackStore, ticketId: UUID) {
        self.store = store
        self.ticketId = ticketId
    }

    public var body: some View {
        VStack(spacing: 0) {
            if store.isLoadingTicketDetail && store.selectedTicket == nil {
                LoadingView(message: "Loading conversation…")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing) {
                        if let ticket = store.selectedTicket {
                            ticketHeader(ticket)
                            Divider()
                        }

                        ForEach(store.ticketMessages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }

                replyInput
            }
        }
        .navigationTitle("Ticket")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await service.fetchTicketDetail(ticketId)
        }
    }

    @ViewBuilder
    private func ticketHeader(_ ticket: SupportTicket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ticket.subject)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            HStack(spacing: 8) {
                StatusBadge(ticketStatus: ticket.status)
                StatusBadge(priority: ticket.priority)
                Spacer()
                RelativeTimeText(date: ticket.createdAt)
            }
        }
    }

    @ViewBuilder
    private var replyInput: some View {
        if store.selectedTicket?.status != .closed {
            HStack(spacing: 8) {
                TextField("Write a reply…", text: $reply, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    Task {
                        let body = reply
                        reply = ""
                        _ = await service.replyToTicket(ticketId, body)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSubmitting)
            }
            .padding()
            .background(.bar)
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: TicketMessage
    @Environment(\.grantivaTheme) private var theme

    private var isAdmin: Bool { message.authorType == .admin }

    var body: some View {
        HStack {
            if isAdmin { Spacer(minLength: 48) }

            VStack(alignment: isAdmin ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: isAdmin ? "shield.fill" : "person.fill")
                        .font(.caption2)
                    Text(isAdmin ? "Support" : "You")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(isAdmin ? theme.accentColor : theme.textSecondary)

                Text(message.body)
                    .font(.subheadline)
                    .foregroundStyle(theme.textPrimary)
                    .padding()
                    .background(
                        isAdmin ? theme.accentColor.opacity(0.1) : theme.surfaceColor,
                        in: .rect(cornerRadius: theme.cornerRadius)
                    )

                RelativeTimeText(date: message.createdAt)
            }

            if !isAdmin { Spacer(minLength: 48) }
        }
    }
}

#Preview {
    let store = FeedbackStore()
    let ticketId = UUID()
    store.selectedTicket = SupportTicket(
        id: ticketId,
        subject: "Cannot reset my password",
        status: .open,
        priority: .high,
        messageCount: 3,
        createdAt: .now.addingTimeInterval(-86400),
        updatedAt: .now.addingTimeInterval(-3600)
    )
    store.ticketMessages = [
        TicketMessage(id: UUID(), ticketId: ticketId, authorType: .user, body: "I've been trying to reset my password but I never receive the email. I've checked my spam folder too.", createdAt: .now.addingTimeInterval(-86400)),
        TicketMessage(id: UUID(), ticketId: ticketId, authorType: .admin, body: "Hi there! I can see the reset emails are being sent. Could you check if you have any email filters set up?", createdAt: .now.addingTimeInterval(-43200)),
        TicketMessage(id: UUID(), ticketId: ticketId, authorType: .user, body: "Found it — my email provider was blocking it. Working now, thanks!", createdAt: .now.addingTimeInterval(-3600)),
    ]
    return NavigationStack {
        TicketDetailView(store: store, ticketId: ticketId)
    }
    .feedbackService(.preview)
}
