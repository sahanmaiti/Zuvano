import Foundation

protocol TextExtracting: Sendable {
    func extract(from source: Source) async throws -> ExtractedText
}

struct PassthroughTextExtractor: TextExtracting {
    nonisolated func extract(from source: Source) async throws -> ExtractedText {
        switch source.type {
        case .text, .shareText:
            guard let text = source.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                throw ExtractionError.emptyResult
            }
            return ExtractedText(text: text, method: .direct, ocrConfidence: nil)
        case .image, .shareImage:
            guard source.imageData != nil else {
                throw ExtractionError.invalidImage
            }
            throw ExtractionError.ocrFailed
        }
    }
}

struct StubTextExtractor: TextExtracting {
    nonisolated let result: Result<ExtractedText, ExtractionError>

    nonisolated init(result: Result<ExtractedText, ExtractionError>) {
        self.result = result
    }

    nonisolated func extract(from source: Source) async throws -> ExtractedText {
        try result.get()
    }
}
