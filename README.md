# GrantivaUI

Drop-in SwiftUI views for Grantiva feature requests and support tickets. Add a full-featured feedback portal to your iOS or macOS app in minutes.

## Requirements

- iOS 18+ or macOS 15+
- [GrantivaSDK](https://github.com/grantiva/ios-sdk) 2.0.1+

## Installation

Add GrantivaUI as a Swift Package dependency:

```swift
// Package.swift
.package(url: "https://github.com/grantiva/GrantivaUI.git", from: "1.0.0"),
```

Or add it in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import SwiftUI
import Grantiva
import GrantivaUI

@main
struct MyApp: App {
    // Initialize the SDK once at app startup
    let grantiva = Grantiva(teamId: "YOUR_TEAM_ID")

    @State private var feedbackStore = FeedbackStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .feedbackService(.live(grantiva.feedback, store: feedbackStore))
                .environment(feedbackStore)
        }
    }
}

struct ContentView: View {
    @Environment(FeedbackStore.self) var feedbackStore

    @State private var showFeedback = false

    var body: some View {
        NavigationStack {
            // Your app content...
            Button("Feedback") { showFeedback = true }
                .sheet(isPresented: $showFeedback) {
                    FeedbackContainerView(store: feedbackStore)
                }
        }
    }
}
```

## Views

### `FeedbackContainerView`

Tabbed container hosting both feature requests and support tickets.

```swift
FeedbackContainerView(store: store)
    .feedbackService(service)
    .grantivaTheme(.default)
```

### `FeatureRequestListView`

Standalone list of feature requests with voting and pull-to-refresh.

```swift
FeatureRequestListView(store: store) { feature in
    // handle selection
}
```

### `SupportTicketListView`

List of the current user's support tickets.

```swift
SupportTicketListView(store: store) { ticket in
    // handle selection
}
```

## Loading, Empty, and Error States

Every list and detail view distinguishes *"nothing here yet"* from *"we couldn't load this"*.
A failed fetch renders a retry affordance instead of an empty state, and a detail view never
shows a previously selected item's content while a new one is loading.

Views read this from the store, so custom UI can use the same states:

```swift
switch store.featureListState {
case .loading:                 // fetch in flight, nothing to show yet
case .failed(let message):     // load failed — show `message` and a retry
case .empty:                   // loaded successfully, genuinely nothing here
case .loaded(let features):    // rows to render
}

// Detail state is keyed by id and only ever reports the item you asked for.
switch store.featureDetailState(for: featureId) { /* … */ }
switch store.ticketDetailState(for: ticketId)   { /* … */ }
```

`store.errorMessage` carries a presentable message for a failure that occurs on top of
content already on screen (for example a failed pull-to-refresh), which the views surface
as an inline banner above the list rather than discarding the rows.

## Theming

Customize colors, fonts, and corner radius via `GrantivaTheme`:

```swift
let myTheme = GrantivaTheme(
    accentColor: .indigo,
    cornerRadius: 8,
    spacing: 12
)

FeedbackContainerView(store: store)
    .grantivaTheme(myTheme)
```

All views read `GrantivaTheme` from the SwiftUI environment, so a single `.grantivaTheme()` modifier on a parent view applies everywhere.

### Theme Properties

| Property | Default | Description |
|---|---|---|
| `accentColor` | `.blue` | Buttons, voted state, admin badges |
| `secondaryColor` | `.secondary` | Secondary text and icons |
| `backgroundColor` | System background | Main view background |
| `surfaceColor` | Secondary background | Cards and grouped areas |
| `textPrimary` | `.primary` | Primary text |
| `textSecondary` | `.secondary` | Metadata and captions |
| `destructiveColor` | `.red` | Destructive actions |
| `successColor` | `.green` | Shipped status, resolved tickets |
| `warningColor` | `.orange` | Error banners, high priority |
| `cornerRadius` | `12` | Card corner radius |
| `spacing` | `16` | Standard spacing between elements |

## Dependency Injection

`FeedbackUIService` is injected through the environment, making views easily testable:

```swift
// Production
.feedbackService(.live(grantiva.feedback, store: store))

// SwiftUI Previews / tests
.feedbackService(.preview)

// Custom stub
.feedbackService(FeedbackUIService(
    fetchFeatureRequests: { /* stub */ },
    // ...
))
```

## Accessibility

All views support:
- **VoiceOver** — meaningful combined labels on list rows and interactive elements
- **Dynamic Type** — all text uses system font styles that scale automatically

## License

© 2025 Grantiva. All rights reserved.
