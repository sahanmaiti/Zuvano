import SwiftUI

/// Centered discard confirmation matching native iOS alert layout (title + destructive + cancel rows).
struct DiscardConversationConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let cancelTitle: String
    let onDiscard: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .accessibilityHidden(true)

                        confirmationCard
                            .accessibilityAddTraits(.isModal)
                    }
                    .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isPresented)
    }

    private var confirmationCard: some View {
        VStack(spacing: 0) {
            Text("Discard this conversation?")
                .font(.headline)
                .foregroundStyle(ZuvanoColors.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .accessibilityAddTraits(.isHeader)

            Divider()

            Button {
                isPresented = false
                onDiscard()
            } label: {
                Text("Discard")
                    .font(.body)
                    .foregroundStyle(ZuvanoColors.error)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Discards this conversation and returns home.")

            Divider()

            Button {
                isPresented = false
            } label: {
                Text(cancelTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ZuvanoColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Returns to the current screen without discarding.")
        }
        .frame(width: 270)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
    }
}

extension View {
    func discardConversationConfirmation(
        isPresented: Binding<Bool>,
        cancelTitle: String,
        onDiscard: @escaping () -> Void
    ) -> some View {
        modifier(
            DiscardConversationConfirmationModifier(
                isPresented: isPresented,
                cancelTitle: cancelTitle,
                onDiscard: onDiscard
            )
        )
    }
}
