import SwiftUI

/// A centered progress indicator with an optional message.
struct LoadingView: View {
    var message: String?

    var body: some View {
        ContentUnavailableView {
            ProgressView()
                .controlSize(.large)
        } description: {
            if let message {
                Text(message)
            }
        }
    }
}

#Preview {
    LoadingView(message: "Loading feature requests…")
}
