import SwiftUI

/// Displays a date as relative time (e.g. "2 hours ago").
struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        Text(date, format: .relative(presentation: .named))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack {
        RelativeTimeText(date: .now.addingTimeInterval(-60))
        RelativeTimeText(date: .now.addingTimeInterval(-3600))
        RelativeTimeText(date: .now.addingTimeInterval(-86400 * 3))
    }
    .padding()
}
