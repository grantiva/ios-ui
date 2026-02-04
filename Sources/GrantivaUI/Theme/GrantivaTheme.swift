import SwiftUI

/// Theming system for all GrantivaUI views.
///
/// Inject a custom theme via the environment to match your app's design:
/// ```swift
/// FeedbackContainerView()
///     .grantivaTheme(.init(
///         accentColor: .blue,
///         secondaryColor: .gray
///     ))
/// ```
public struct GrantivaTheme: Sendable {
    public var accentColor: Color
    public var secondaryColor: Color
    public var backgroundColor: Color
    public var surfaceColor: Color
    public var textPrimary: Color
    public var textSecondary: Color
    public var destructiveColor: Color
    public var successColor: Color
    public var warningColor: Color
    public var cornerRadius: CGFloat
    public var spacing: CGFloat

    public init(
        accentColor: Color = .blue,
        secondaryColor: Color = .secondary,
        backgroundColor: Color = .white,
        surfaceColor: Color = Color(white: 0.95),
        textPrimary: Color = .primary,
        textSecondary: Color = .secondary,
        destructiveColor: Color = .red,
        successColor: Color = .green,
        warningColor: Color = .orange,
        cornerRadius: CGFloat = 12,
        spacing: CGFloat = 16
    ) {
        self.accentColor = accentColor
        self.secondaryColor = secondaryColor
        self.backgroundColor = backgroundColor
        self.surfaceColor = surfaceColor
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.destructiveColor = destructiveColor
        self.successColor = successColor
        self.warningColor = warningColor
        self.cornerRadius = cornerRadius
        self.spacing = spacing
    }

    public static let `default` = GrantivaTheme()
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry public var grantivaTheme: GrantivaTheme = .default
}

extension View {
    public func grantivaTheme(_ theme: GrantivaTheme) -> some View {
        environment(\.grantivaTheme, theme)
    }
}
