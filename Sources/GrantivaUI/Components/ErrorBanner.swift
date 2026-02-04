import SwiftUI

/// An inline error banner with a retry action.
struct ErrorBanner: View {
    let message: String
    var retryAction: (() -> Void)?

    @Environment(\.grantivaTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warningColor)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            if let retryAction {
                Button("Retry", action: retryAction)
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding()
        .background(theme.warningColor.opacity(0.1), in: .rect(cornerRadius: theme.cornerRadius))
    }
}

#Preview {
    VStack(spacing: 16) {
        ErrorBanner(message: "Something went wrong.")
        ErrorBanner(message: "Network request failed.", retryAction: {})
    }
    .padding()
}
