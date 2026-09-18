import Observation
import UIKit

protocol ClipboardChecking: Sendable {
    var hasPasteableText: Bool { get }
}

struct LiveClipboardChecker: ClipboardChecking {
    var hasPasteableText: Bool {
        guard UIPasteboard.general.hasStrings else { return false }
        let trimmed = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }
}

struct StubClipboardChecker: ClipboardChecking {
    let hasPasteableText: Bool
}

@Observable
@MainActor
final class HomeViewModel {
    var clipboardHasText = false

    private let clipboardChecker: any ClipboardChecking

    init(clipboardChecker: any ClipboardChecking = LiveClipboardChecker()) {
        self.clipboardChecker = clipboardChecker
        refreshClipboardState()
    }

    func refreshClipboardState() {
        clipboardHasText = clipboardChecker.hasPasteableText
    }

    /// Day 1 stub: pipeline wiring arrives on Day 2.
    func pasteTapped() {
        guard clipboardHasText else { return }
    }
}
