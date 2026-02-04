import SwiftUI
import Grantiva

/// Displays a colored badge for feature request or ticket status.
struct StatusBadge: View {
    let label: String
    let color: Color

    @Environment(\.grantivaTheme) private var theme

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: .capsule)
    }
}

// MARK: - Convenience Initializers

extension StatusBadge {
    init(featureStatus: FeatureRequestStatus) {
        self.label = featureStatus.displayName
        self.color = featureStatus.displayColor
    }

    init(ticketStatus: TicketStatus) {
        self.label = ticketStatus.displayName
        self.color = ticketStatus.displayColor
    }

    init(priority: TicketPriority) {
        self.label = priority.displayName
        self.color = priority.displayColor
    }
}

// MARK: - Display Helpers

extension FeatureRequestStatus {
    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .open: "Open"
        case .planned: "Planned"
        case .inProgress: "In Progress"
        case .shipped: "Shipped"
        case .declined: "Declined"
        case .duplicate: "Duplicate"
        }
    }

    var displayColor: Color {
        switch self {
        case .pending: .secondary
        case .open: .blue
        case .planned: .purple
        case .inProgress: .orange
        case .shipped: .green
        case .declined: .red
        case .duplicate: .gray
        }
    }
}

extension TicketStatus {
    var displayName: String {
        switch self {
        case .open: "Open"
        case .awaitingReply: "Awaiting Reply"
        case .resolved: "Resolved"
        case .closed: "Closed"
        }
    }

    var displayColor: Color {
        switch self {
        case .open: .blue
        case .awaitingReply: .orange
        case .resolved: .green
        case .closed: .secondary
        }
    }
}

extension TicketPriority {
    var displayName: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    var displayColor: Color {
        switch self {
        case .low: .secondary
        case .normal: .blue
        case .high: .orange
        case .urgent: .red
        }
    }
}

#Preview("Feature Statuses") {
    VStack(spacing: 8) {
        ForEach(FeatureRequestStatus.allCases, id: \.self) { status in
            StatusBadge(featureStatus: status)
        }
    }
    .padding()
}

#Preview("Ticket Statuses") {
    VStack(spacing: 8) {
        ForEach(TicketStatus.allCases, id: \.self) { status in
            StatusBadge(ticketStatus: status)
        }
    }
    .padding()
}

#Preview("Priorities") {
    VStack(spacing: 8) {
        ForEach(TicketPriority.allCases, id: \.self) { priority in
            StatusBadge(priority: priority)
        }
    }
    .padding()
}
