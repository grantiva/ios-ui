import SwiftUI
import Grantiva

/// Displays a list of feature requests with voting.
public struct FeatureRequestListView: View {
    @Environment(\.feedbackService) private var service
    @Environment(\.grantivaTheme) private var theme
    var store: FeedbackStore
    var onSelect: (FeatureRequest) -> Void

    public init(store: FeedbackStore, onSelect: @escaping (FeatureRequest) -> Void) {
        self.store = store
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            if store.isLoadingFeatures && store.featureRequests.isEmpty {
                LoadingView(message: "Loading feature requests…")
            } else if store.featureRequests.isEmpty {
                ContentUnavailableView(
                    "No Feature Requests",
                    systemImage: "lightbulb",
                    description: Text("Be the first to suggest a feature.")
                )
            } else {
                List(store.featureRequests) { feature in
                    FeatureRequestRow(feature: feature) {
                        Task {
                            if feature.hasVoted {
                                await service.removeVote(feature.id)
                            } else {
                                await service.vote(feature.id)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(feature) }
                }
                .listStyle(.plain)
                .refreshable {
                    await service.fetchFeatureRequests()
                }
            }
        }
        .task {
            await service.fetchFeatureRequests()
        }
    }
}

#Preview {
    let store = FeedbackStore()
    store.featureRequests = [
        FeatureRequest(id: UUID(), title: "Dark mode support", description: "Add a dark mode option.", status: .planned, voteCount: 42, hasVoted: false, commentCount: 5, createdAt: .now.addingTimeInterval(-86400 * 2), updatedAt: .now.addingTimeInterval(-3600)),
        FeatureRequest(id: UUID(), title: "Export data to CSV", description: "Allow CSV export.", status: .open, voteCount: 17, hasVoted: true, commentCount: 0, createdAt: .now.addingTimeInterval(-86400 * 7), updatedAt: .now.addingTimeInterval(-86400)),
        FeatureRequest(id: UUID(), title: "Keyboard shortcuts", description: "Add customizable keyboard shortcuts.", status: .shipped, voteCount: 89, hasVoted: true, commentCount: 12, createdAt: .now.addingTimeInterval(-86400 * 30), updatedAt: .now.addingTimeInterval(-86400 * 3)),
    ]
    return FeatureRequestListView(store: store, onSelect: { _ in })
        .feedbackService(.preview)
}

#Preview("Empty") {
    FeatureRequestListView(store: FeedbackStore(), onSelect: { _ in })
        .feedbackService(.preview)
}
