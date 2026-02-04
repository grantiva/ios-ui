import SwiftUI
import Grantiva

/// A single row in the feature request list.
struct FeatureRequestRow: View {
    let feature: FeatureRequest
    let onVote: () -> Void

    @Environment(\.grantivaTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing) {
            VoteButton(count: feature.voteCount, hasVoted: feature.hasVoted, action: onVote)

            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    StatusBadge(featureStatus: feature.status)

                    Label("\(feature.commentCount)", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    RelativeTimeText(date: feature.createdAt)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        FeatureRequestRow(
            feature: FeatureRequest(
                id: UUID(),
                title: "Dark mode support",
                description: "It would be great to have a dark mode option for the app.",
                status: .planned,
                voteCount: 42,
                hasVoted: false,
                commentCount: 5,
                createdAt: .now.addingTimeInterval(-86400 * 2),
                updatedAt: .now.addingTimeInterval(-3600)
            ),
            onVote: {}
        )
        FeatureRequestRow(
            feature: FeatureRequest(
                id: UUID(),
                title: "Export data to CSV",
                description: "Allow users to export their data in CSV format for external analysis.",
                status: .open,
                voteCount: 17,
                hasVoted: true,
                commentCount: 0,
                createdAt: .now.addingTimeInterval(-86400 * 7),
                updatedAt: .now.addingTimeInterval(-86400)
            ),
            onVote: {}
        )
    }
    .listStyle(.plain)
}
