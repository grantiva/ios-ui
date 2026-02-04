import SwiftUI

/// Form for submitting a new feature request.
public struct SubmitFeatureRequestView: View {
    @Environment(\.feedbackService) private var service
    @Environment(\.grantivaTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    var store: FeedbackStore

    @State private var title: String = ""
    @State private var description: String = ""

    public init(store: FeedbackStore) {
        self.store = store
    }

    private var isValid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Describe the feature you'd like to see…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Feature Request")
                } footer: {
                    Text("Title: 3+ characters. Description: 10+ characters.")
                }

                if let error = store.error {
                    Section {
                        ErrorBanner(message: error.localizedDescription)
                    }
                }
            }
            .navigationTitle("New Feature Request")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            let success = await service.submitFeatureRequest(
                                title.trimmingCharacters(in: .whitespacesAndNewlines),
                                description.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            if success { dismiss() }
                        }
                    }
                    .disabled(!isValid || store.isSubmitting)
                }
            }
        }
    }
}

#Preview {
    SubmitFeatureRequestView(store: FeedbackStore())
        .feedbackService(.preview)
}
