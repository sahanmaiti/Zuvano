import SwiftUI

struct ManualTextEntryView: View {
    @State private var text = ""
    @FocusState private var isEditorFocused: Bool
    @ScaledMetric(relativeTo: .body) private var editorMinHeight = 200
    @State private var showDiscardConfirmation = false

    let isSubmitting: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .focused($isEditorFocused)
                        .frame(minHeight: editorMinHeight)
                        .accessibilityLabel("Conversation text")
                        .accessibilityHint("Enter the conversation text to continue.")
                } footer: {
                    Text("Paste or type the conversation. Zuvano will read this text instead of the screenshot.")
                        .zuvanoFootnoteStyle()
                }
            }

            if isSubmitting {
                ProgressView("Continuing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Continuing with entered text.")
            }
        }
        .navigationTitle("Enter Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: handleCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSubmitting {
                    ProgressView()
                        .accessibilityLabel("Continuing")
                } else {
                    Button("Continue") {
                        onSubmit(text)
                    }
                    .disabled(!canSubmit)
                    .accessibilityHint(canSubmit ? "Continues with the entered text." : "Enter conversation text to continue.")
                }
            }
        }
        .confirmationDialog(
            "Discard entered text?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive, action: onCancel)
            Button("Keep Editing", role: .cancel) {}
        }
        .onAppear {
            isEditorFocused = true
        }
    }

    private var canSubmit: Bool {
        !isSubmitting && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleCancel() {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onCancel()
        } else {
            showDiscardConfirmation = true
        }
    }
}

#Preview {
    NavigationStack {
        ManualTextEntryView(isSubmitting: false, onSubmit: { _ in }, onCancel: {})
    }
}

#Preview("Submitting") {
    NavigationStack {
        ManualTextEntryView(isSubmitting: true, onSubmit: { _ in }, onCancel: {})
    }
}

#Preview("Dark") {
    NavigationStack {
        ManualTextEntryView(isSubmitting: false, onSubmit: { _ in }, onCancel: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    NavigationStack {
        ManualTextEntryView(isSubmitting: false, onSubmit: { _ in }, onCancel: {})
    }
    .dynamicTypeSize(.accessibility3)
}
