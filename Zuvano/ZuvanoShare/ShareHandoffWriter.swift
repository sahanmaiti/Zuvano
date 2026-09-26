import Foundation

enum ShareHandoffWriteError: Error {
    case appGroupUnavailable
    case invalidPayload
}

struct ShareHandoffWriteResult {
    let token: UUID
    let openURL: URL
}

enum ShareHandoffWriter {
    static func write(text: String) throws -> ShareHandoffWriteResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ShareHandoffWriteError.invalidPayload }
        return try writeEnvelope(sourceType: "shareText", text: trimmed, imageData: nil)
    }

    static func write(imageData: Data) throws -> ShareHandoffWriteResult {
        guard !imageData.isEmpty else { throw ShareHandoffWriteError.invalidPayload }
        return try writeEnvelope(sourceType: "shareImage", text: nil, imageData: imageData)
    }

    private struct Envelope: Codable {
        let sourceType: String
        let text: String?
    }

    private static func handoffDirectoryURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        ) else {
            throw ShareHandoffWriteError.appGroupUnavailable
        }
        return container
            .appendingPathComponent("Library/Caches", isDirectory: true)
            .appendingPathComponent(AppGroupConstants.handoffDirectoryName, isDirectory: true)
    }

    private static func writeEnvelope(
        sourceType: String,
        text: String?,
        imageData: Data?
    ) throws -> ShareHandoffWriteResult {
        let token = UUID()
        let directory = try handoffDirectoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let envelope = Envelope(sourceType: sourceType, text: text)
        let envelopeURL = directory.appendingPathComponent("\(token.uuidString).json")
        try JSONEncoder().encode(envelope).write(to: envelopeURL, options: .atomic)

        if let imageData {
            let imageURL = directory.appendingPathComponent("\(token.uuidString).img")
            try imageData.write(to: imageURL, options: .atomic)
        }

        var components = URLComponents()
        components.scheme = AppGroupConstants.urlScheme
        components.host = AppGroupConstants.handoffHost
        components.path = "/\(token.uuidString)"
        guard let openURL = components.url else {
            throw ShareHandoffWriteError.invalidPayload
        }

        return ShareHandoffWriteResult(token: token, openURL: openURL)
    }
}
