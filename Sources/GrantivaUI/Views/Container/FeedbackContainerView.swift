import SwiftUI
import Grantiva

/// Top-level container providing tabbed access to feature requests and support tickets.
///
/// Usage:
/// ```swift
/// let store = FeedbackStore()
/// let service = FeedbackUIService.live(grantiva.feedback, store: store)
///
/// FeedbackContainerView(store: store)
///     .feedbackService(service)
///     .grantivaTheme(.default)
/// ```
public struct FeedbackContainerView: View {
    var store: FeedbackStore

    @State private var selectedTab: FeedbackTab = .featureRequests
    @State private var showingSubmitFeature = false
    @State private var showingSubmitTicket = false
    @State private var navigationPath = NavigationPath()

    @Environment(\.grantivaTheme) private var theme

    public init(store: FeedbackStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                tabPicker
                tabContent
            }
            .navigationTitle("Feedback")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        switch selectedTab {
                        case .featureRequests: showingSubmitFeature = true
                        case .support: showingSubmitTicket = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: FeatureDestination.self) { destination in
                FeatureRequestDetailView(store: store, featureId: destination.id)
            }
            .navigationDestination(for: TicketDestination.self) { destination in
                TicketDetailView(store: store, ticketId: destination.id)
            }
            .sheet(isPresented: $showingSubmitFeature) {
                SubmitFeatureRequestView(store: store)
            }
            .sheet(isPresented: $showingSubmitTicket) {
                SubmitTicketView(store: store)
            }
        }
    }

    @ViewBuilder
    private var tabPicker: some View {
        Picker("Section", selection: $selectedTab) {
            ForEach(FeedbackTab.allCases, id: \.self) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .featureRequests:
            FeatureRequestListView(store: store) { feature in
                navigationPath.append(FeatureDestination(id: feature.id))
            }
        case .support:
            SupportTicketListView(store: store) { ticket in
                navigationPath.append(TicketDestination(id: ticket.id))
            }
        }
    }
}

// MARK: - Tab Enum

private enum FeedbackTab: String, CaseIterable {
    case featureRequests
    case support

    var title: String {
        switch self {
        case .featureRequests: "Features"
        case .support: "Support"
        }
    }
}

// MARK: - Navigation Destinations

struct FeatureDestination: Hashable {
    let id: UUID
}

struct TicketDestination: Hashable {
    let id: UUID
}

#Preview {
    let store = FeedbackStore()
    store.featureRequests = [
        FeatureRequest(id: UUID(), title: "Dark mode support", description: "Add a dark mode option.", status: .planned, voteCount: 42, hasVoted: false, commentCount: 5, createdAt: .now.addingTimeInterval(-86400 * 2), updatedAt: .now.addingTimeInterval(-3600)),
        FeatureRequest(id: UUID(), title: "Export data to CSV", description: "Allow CSV export.", status: .open, voteCount: 17, hasVoted: true, commentCount: 0, createdAt: .now.addingTimeInterval(-86400 * 7), updatedAt: .now.addingTimeInterval(-86400)),
    ]
    store.tickets = [
        SupportTicket(id: UUID(), subject: "Cannot reset my password", status: .open, priority: .high, messageCount: 3, createdAt: .now.addingTimeInterval(-86400), updatedAt: .now.addingTimeInterval(-3600)),
    ]
    return FeedbackContainerView(store: store)
        .feedbackService(.preview)
}
