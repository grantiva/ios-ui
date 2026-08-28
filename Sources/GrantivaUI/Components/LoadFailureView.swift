import SwiftUI

/// The state a view shows when a load *failed*, as opposed to succeeding with nothing.
///
/// Deliberately distinct from `ContentUnavailableView("No …")`: a network failure
/// presented as "there's nothing here" is misleading and hides the retry affordance.
struct LoadFailureView: View {
    let title: String
    let systemImage: String
    let message: String
    let retry: () async -> Void

    @Environment(\.grantivaTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing) {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text("We couldn't load this. Check your connection and try again.")
            )

            ErrorBanner(message: message) {
                Task { await retry() }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    LoadFailureView(
        title: "Couldn't Load Feature Requests",
        systemImage: "lightbulb.slash",
        message: URLError(.notConnectedToInternet).localizedDescription,
        retry: {}
    )
}
