import SwiftUI
import Grantiva

/// Detail view for a single feature request with comments.
public struct FeatureRequestDetailView: View {
    @Environment(\.feedbackService) private var service
    @Environment(\.grantivaTheme) private var theme
    var store: FeedbackStore
    let featureId: UUID

    @State private var newComment: String = ""

    public init(store: FeedbackStore, featureId: UUID) {
        self.store = store
        self.featureId = featureId
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing) {
                if let feature = store.selectedFeatureRequest {
                    featureHeader(feature)
                    Divider()
                    commentsSection
                    commentInput
                } else if store.isLoadingFeatureDetail {
                    LoadingView(message: "Loading details…")
                }
            }
            .padding()
        }
        .navigationTitle("Feature Request")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await service.fetchFeatureRequest(featureId)
            await service.fetchComments(featureId)
        }
    }

    @ViewBuilder
    private func featureHeader(_ feature: FeatureRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusBadge(featureStatus: feature.status)
                Spacer()
                VoteButton(count: feature.voteCount, hasVoted: feature.hasVoted) {
                    Task {
                        if feature.hasVoted {
                            await service.removeVote(feature.id)
                        } else {
                            await service.vote(feature.id)
                        }
                    }
                }
            }

            Text(feature.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.textPrimary)

            Text(feature.description)
                .font(.body)
                .foregroundStyle(theme.textSecondary)

            RelativeTimeText(date: feature.createdAt)
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)

            if store.isLoadingComments {
                ProgressView()
            } else if store.featureComments.isEmpty {
                Text("No comments yet.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(store.featureComments) { comment in
                    CommentBubble(comment: comment)
                }
            }
        }
    }

    @ViewBuilder
    private var commentInput: some View {
        HStack(spacing: 8) {
            TextField("Add a comment…", text: $newComment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button {
                Task {
                    let body = newComment
                    newComment = ""
                    _ = await service.addComment(featureId, body)
                }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSubmitting)
        }
        .padding(.top, 8)
    }
}

// MARK: - Comment Bubble

private struct CommentBubble: View {
    let comment: FeatureComment
    @Environment(\.grantivaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: comment.authorType == .admin ? "shield.fill" : "person.fill")
                    .font(.caption)
                    .foregroundStyle(comment.authorType == .admin ? theme.accentColor : theme.textSecondary)
                Text(comment.authorType == .admin ? "Team" : "User")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(comment.authorType == .admin ? theme.accentColor : theme.textSecondary)
                Spacer()
                RelativeTimeText(date: comment.createdAt)
            }

            Text(comment.body)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
        }
        .padding()
        .background(theme.surfaceColor, in: .rect(cornerRadius: theme.cornerRadius))
    }
}

#Preview {
    let store = FeedbackStore()
    let featureId = UUID()
    store.selectedFeatureRequest = FeatureRequest(
        id: featureId,
        title: "Dark mode support",
        description: "It would be great to have a dark mode option for the entire app. This would help reduce eye strain during nighttime usage.",
        status: .planned,
        voteCount: 42,
        hasVoted: false,
        commentCount: 2,
        createdAt: .now.addingTimeInterval(-86400 * 2),
        updatedAt: .now.addingTimeInterval(-3600)
    )
    store.featureComments = [
        FeatureComment(id: UUID(), featureRequestId: featureId, authorType: .user, body: "This would be amazing! I use the app mostly at night.", createdAt: .now.addingTimeInterval(-86400)),
        FeatureComment(id: UUID(), featureRequestId: featureId, authorType: .admin, body: "Thanks for the suggestion! We're planning to ship this in the next release.", createdAt: .now.addingTimeInterval(-3600)),
    ]
    return NavigationStack {
        FeatureRequestDetailView(store: store, featureId: featureId)
    }
    .feedbackService(.preview)
}
