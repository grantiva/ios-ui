import SwiftUI

/// A vote button showing count and voted state.
struct VoteButton: View {
    let count: Int
    let hasVoted: Bool
    let action: () -> Void

    @Environment(\.grantivaTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: hasVoted ? "chevron.up.circle.fill" : "chevron.up.circle")
                    .font(.body.weight(.semibold))
                Text("\(count)")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(hasVoted ? .white : theme.accentColor)
            .background(
                hasVoted ? AnyShapeStyle(theme.accentColor) : AnyShapeStyle(theme.accentColor.opacity(0.1)),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hasVoted)
    }
}

#Preview("Not Voted") {
    VoteButton(count: 12, hasVoted: false, action: {})
        .padding()
}

#Preview("Voted") {
    VoteButton(count: 13, hasVoted: true, action: {})
        .padding()
}
