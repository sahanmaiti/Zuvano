import Foundation

private struct HandoffEnvelope: Sendable {
    let sourceType: String
    let text: String?
}

struct ShareHandoffWriteResult: Sendable, Equatable {
    nonisolated let token: UUID
    nonisolated let openURL: URL
}

enum ShareHandoffError: Error, Sendable {
    case appGroupUnavailable
    case invalidPayload
    case missingFile
    case unsupportedSourceType
}

struct ShareHandoffStore: Sendable {
    private let handoffDirectoryURL: URL

    nonisolated init(handoffDirectoryURL: URL? = nil) {
        if let handoffDirectoryURL {
            self.handoffDirectoryURL = handoffDirectoryURL
        } else if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        ) {
            self.handoffDirectoryURL = container
                .appendingPathComponent("Library/Caches", isDirectory: true)
                .appendingPathComponent(AppGroupConstants.handoffDirectoryName, isDirectory: true)
        } else {
            self.handoffDirectoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(AppGroupConstants.handoffDirectoryName, isDirectory: true)
        }
    }

    nonisolated func write(source: Source) throws -> ShareHandoffWriteResult {
        let token = UUID()
        try FileManager.default.createDirectory(at: handoffDirectoryURL, withIntermediateDirectories: true)

        switch source.type {
        case .shareText, .text:
            let trimmed = source.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { throw ShareHandoffError.invalidPayload }
            let envelope = HandoffEnvelope(sourceType: SourceType.shareText.rawValue, text: trimmed)
            try writeEnvelope(envelope, token: token)
        case .shareImage, .image:
            guard let imageData = source.imageData, !imageData.isEmpty else {
                throw ShareHandoffError.invalidPayload
            }
            let envelope = HandoffEnvelope(sourceType: SourceType.shareImage.rawValue, text: nil)
            try writeEnvelope(envelope, token: token)
            let imageURL = imageFileURL(for: token)
            try imageData.write(to: imageURL, options: .atomic)
        }

        let openURL = handoffURL(for: token)
        return ShareHandoffWriteResult(token: token, openURL: openURL)
    }

    nonisolated func load(token: UUID) throws -> Source {
        let envelope = try readEnvelope(token: token)
        switch envelope.sourceType {
        case SourceType.shareText.rawValue:
            let text = envelope.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { throw ShareHandoffError.invalidPayload }
            return .sharedText(text)
        case SourceType.shareImage.rawValue:
            let imageURL = imageFileURL(for: token)
            guard FileManager.default.fileExists(atPath: imageURL.path) else {
                throw ShareHandoffError.missingFile
            }
            let data = try Data(contentsOf: imageURL)
            guard !data.isEmpty else { throw ShareHandoffError.invalidPayload }
            return .sharedImage(data)
        default:
            throw ShareHandoffError.unsupportedSourceType
        }
    }

    nonisolated func delete(token: UUID) {
        try? FileManager.default.removeItem(at: envelopeFileURL(for: token))
        try? FileManager.default.removeItem(at: imageFileURL(for: token))
    }

    nonisolated func pendingTokens() -> [UUID] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: handoffDirectoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files.compactMap { url -> UUID? in
            guard url.pathExtension == "json" else { return nil }
            return UUID(uuidString: url.deletingPathExtension().lastPathComponent)
        }
    }

    nonisolated func deleteStale(except exceptToken: UUID? = nil) {
        let cutoff = Date().addingTimeInterval(-AppGroupConstants.handoffMaxAge)
        for token in pendingTokens() {
            if token == exceptToken { continue }
            let envelopeURL = envelopeFileURL(for: token)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: envelopeURL.path),
                  let modified = attrs[.modificationDate] as? Date else {
                delete(token: token)
                continue
            }
            if modified < cutoff {
                delete(token: token)
            }
        }
    }

    nonisolated static func parseHandoffToken(from url: URL) -> UUID? {
        guard url.scheme == AppGroupConstants.urlScheme,
              url.host == AppGroupConstants.handoffHost else {
            return nil
        }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else { return nil }
        return UUID(uuidString: path)
    }

    nonisolated func handoffURL(for token: UUID) -> URL {
        var components = URLComponents()
        components.scheme = AppGroupConstants.urlScheme
        components.host = AppGroupConstants.handoffHost
        components.path = "/\(token.uuidString)"
        return components.url!
    }

    private nonisolated func envelopeFileURL(for token: UUID) -> URL {
        handoffDirectoryURL.appendingPathComponent("\(token.uuidString).json")
    }

    private nonisolated func imageFileURL(for token: UUID) -> URL {
        handoffDirectoryURL.appendingPathComponent("\(token.uuidString).img")
    }

    private nonisolated func writeEnvelope(_ envelope: HandoffEnvelope, token: UUID) throws {
        var payload: [String: Any] = ["sourceType": envelope.sourceType]
        if let text = envelope.text {
            payload["text"] = text
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        try data.write(to: envelopeFileURL(for: token), options: .atomic)
    }

    private nonisolated func readEnvelope(token: UUID) throws -> HandoffEnvelope {
        let url = envelopeFileURL(for: token)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ShareHandoffError.missingFile
        }
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let sourceType = object?["sourceType"] as? String else {
            throw ShareHandoffError.invalidPayload
        }
        let text = object?["text"] as? String
        return HandoffEnvelope(sourceType: sourceType, text: text)
    }
}
