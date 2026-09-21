import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Visible system paste control. iOS only authorizes clipboard access when this control
/// is fully on-screen, unobscured, and the actual tap target.
///
/// Idle colors match the other Home `.bordered` actions. When the pasteboard reports
/// strings (`hasStrings` only — contents are never read), the control is recreated
/// filled accent with a white label. Configuration is never mutated after attach.
struct ZuvanoPasteControl: View {
    let onPaste: @MainActor (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasClipboardText = UIPasteboard.general.hasStrings

    var body: some View {
        PasteControlRepresentable(onPaste: onPaste, hasClipboardText: hasClipboardText)
            .id(hasClipboardText)
            .onAppear(perform: refreshClipboardAvailability)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshClipboardAvailability()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
                refreshClipboardAvailability()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                refreshClipboardAvailability()
            }
    }

    private func refreshClipboardAvailability() {
        hasClipboardText = UIPasteboard.general.hasStrings
    }
}

private struct PasteControlRepresentable: UIViewRepresentable {
    let onPaste: @MainActor (String) -> Void
    let hasClipboardText: Bool

    func makeUIView(context: Context) -> PasteHostView {
        PasteHostView(onPaste: onPaste, hasClipboardText: hasClipboardText)
    }

    func updateUIView(_ uiView: PasteHostView, context: Context) {
        uiView.onPaste = onPaste
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PasteHostView, context: Context) -> CGSize {
        CGSize(
            width: proposal.width ?? UIView.noIntrinsicMetric,
            height: ZuvanoSpacing.homeActionButtonHeight
        )
    }
}

final class PasteHostView: UIView {
    var onPaste: (@MainActor (String) -> Void)?

    private let pasteControl: UIPasteControl

    init(onPaste: @escaping @MainActor (String) -> Void, hasClipboardText: Bool) {
        self.onPaste = onPaste

        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconAndLabel
        configuration.cornerStyle = .capsule
        if hasClipboardText {
            configuration.baseBackgroundColor = .tintColor
            configuration.baseForegroundColor = .white
        } else {
            configuration.baseBackgroundColor = .systemGray5
            configuration.baseForegroundColor = .tintColor
        }

        pasteControl = UIPasteControl(configuration: configuration)
        super.init(frame: .zero)

        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = true
        pasteConfiguration = UIPasteConfiguration(
            acceptableTypeIdentifiers: [
                UTType.plainText.identifier,
                UTType.utf8PlainText.identifier,
                UTType.text.identifier,
            ]
        )

        pasteControl.target = self
        pasteControl.translatesAutoresizingMaskIntoConstraints = false
        pasteControl.isAccessibilityElement = true
        pasteControl.accessibilityLabel = "Paste"
        addSubview(pasteControl)

        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            pasteControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            pasteControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            pasteControl.topAnchor.constraint(equalTo: topAnchor),
            pasteControl.heightAnchor.constraint(equalToConstant: ZuvanoSpacing.homeActionButtonHeight),
            heightAnchor.constraint(equalToConstant: ZuvanoSpacing.homeActionButtonHeight),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ZuvanoSpacing.homeActionButtonHeight)
    }

    override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
        itemProviders.contains { provider in
            provider.canLoadObject(ofClass: String.self)
                || provider.canLoadObject(ofClass: NSString.self)
        }
    }

    override func paste(itemProviders: [NSItemProvider]) {
        for provider in itemProviders {
            if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { [weak self] object, _ in
                    Task { @MainActor in
                        self?.deliverPastedText(object)
                    }
                }
                return
            }

            if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
                    let pasted = object as? NSString
                    let text: String? = pasted.map { $0 as String }
                    Task { @MainActor in
                        self?.deliverPastedText(text)
                    }
                }
                return
            }
        }
    }

    private func deliverPastedText(_ rawText: String?) {
        let text = rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }
        onPaste?(text)
    }
}
