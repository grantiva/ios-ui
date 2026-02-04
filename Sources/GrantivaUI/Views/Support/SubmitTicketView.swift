import SwiftUI

/// Form for submitting a new support ticket.
public struct SubmitTicketView: View {
    @Environment(\.feedbackService) private var service
    @Environment(\.grantivaTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    var store: FeedbackStore

    @State private var subject: String = ""
    @State private var messageBody: String = ""
    @State private var email: String = ""
    @State private var priority: TicketPrioritySelection = .normal

    public init(store: FeedbackStore) {
        self.store = store
    }

    private var isValid: Bool {
        subject.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        messageBody.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subject", text: $subject)
                    TextEditor(text: $messageBody)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if messageBody.isEmpty {
                                Text("Describe your issue…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Details")
                } footer: {
                    Text("Subject: 3+ characters. Description: 10+ characters.")
                }

                Section("Contact (Optional)") {
                    TextField("Email address", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        #endif
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                if let error = store.error {
                    Section {
                        ErrorBanner(message: error.localizedDescription)
                    }
                }
            }
            .navigationTitle("New Ticket")
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
                            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            let success = await service.submitTicket(
                                subject.trimmingCharacters(in: .whitespacesAndNewlines),
                                messageBody.trimmingCharacters(in: .whitespacesAndNewlines),
                                trimmedEmail.isEmpty ? nil : trimmedEmail
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

// Internal enum to avoid importing Grantiva's TicketPriority into form state
private enum TicketPrioritySelection: String, CaseIterable {
    case low, normal, high, urgent
}

#Preview {
    SubmitTicketView(store: FeedbackStore())
        .feedbackService(.preview)
}
