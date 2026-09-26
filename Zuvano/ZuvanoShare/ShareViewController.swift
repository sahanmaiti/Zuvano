import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        statusLabel.text = "Opening Zuvano…"
        statusLabel.textAlignment = .center
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await captureAndHandoff() }
    }

    @MainActor
    private func captureAndHandoff() async {
        guard let extensionContext else {
            finish()
            return
        }

        do {
            let result = try await writeHandoff(from: extensionContext)
            _ = await extensionContext.open(result.openURL)
            finish()
        } catch {
            finish()
        }
    }

    @MainActor
    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func writeHandoff(from context: NSExtensionContext) async throws -> ShareHandoffWriteResult {
        let items = context.inputItems.compactMap { $0 as? NSExtensionItem }

        for item in items {
            if let text = item.attributedContentText?.string.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return try ShareHandoffWriter.write(text: text)
            }
        }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    let value = try await loadItem(from: provider, type: UTType.plainText.identifier)
                    switch value {
                    case .text(let text):
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { return try ShareHandoffWriter.write(text: trimmed) }
                    case .url(let url):
                        if let text = try? String(contentsOf: url, encoding: .utf8) {
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { return try ShareHandoffWriter.write(text: trimmed) }
                        }
                    default:
                        break
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    let value = try await loadItem(from: provider, type: UTType.image.identifier)
                    switch value {
                    case .data(let data) where !data.isEmpty:
                        return try ShareHandoffWriter.write(imageData: data)
                    case .url(let url):
                        if let data = try? Data(contentsOf: url), !data.isEmpty {
                            return try ShareHandoffWriter.write(imageData: data)
                        }
                    default:
                        break
                    }
                }
            }
        }

        throw ShareHandoffWriteError.invalidPayload
    }

    private func loadItem(from provider: NSItemProvider, type: String) async throws -> LoadedHandoffItem {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let text = item as? String {
                    continuation.resume(returning: .text(text))
                } else if let data = item as? Data {
                    continuation.resume(returning: .data(data))
                } else if let url = item as? URL {
                    continuation.resume(returning: .url(url))
                } else if let image = item as? UIImage, let data = image.pngData() {
                    continuation.resume(returning: .data(data))
                } else {
                    continuation.resume(throwing: ShareHandoffWriteError.invalidPayload)
                }
            }
        }
    }
}

private enum LoadedHandoffItem: Sendable {
    case text(String)
    case data(Data)
    case url(URL)
}
