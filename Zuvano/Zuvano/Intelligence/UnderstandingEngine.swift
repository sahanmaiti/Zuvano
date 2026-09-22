import Foundation

protocol UnderstandingEngine: Sendable {
    func understand(_ text: String) async throws -> UnderstandingResult
}

struct MockUnderstandingEngine: UnderstandingEngine {
    nonisolated let result: Result<UnderstandingResult, UnderstandingError>

    nonisolated init(result: Result<UnderstandingResult, UnderstandingError>) {
        self.result = result
    }

    nonisolated func understand(_ text: String) async throws -> UnderstandingResult {
        _ = text
        return try result.get()
    }
}

/// Primary → fallback selection per architecture §10.
struct CompositeUnderstandingEngine: UnderstandingEngine {
    private let primary: any UnderstandingEngine
    private let fallback: any UnderstandingEngine

    nonisolated init(
        primary: any UnderstandingEngine = FoundationModelsUnderstandingEngine(),
        fallback: any UnderstandingEngine = FallbackUnderstandingEngine()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    nonisolated func understand(_ text: String) async throws -> UnderstandingResult {
        do {
            return try await primary.understand(text)
        } catch {
            do {
                return try await fallback.understand(text)
            } catch {
                throw UnderstandingError.extractionFailed
            }
        }
    }
}
