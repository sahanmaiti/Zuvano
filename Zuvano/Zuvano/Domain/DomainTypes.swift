import Foundation

enum SourceType: String, Codable, Sendable {
    case image
    case text
    case shareText
    case shareImage
}

enum ExtractionMethod: String, Codable, Sendable {
    case direct
    case ocr
}

enum EngineKind: String, Codable, Sendable {
    case foundationModels
    case fallback
}

enum IntentKind: String, Codable, Sendable {
    case task
    case reminder
    case meeting
    case followUp
    case commitment
}

enum EntityKind: String, Codable, Sendable {
    case dateTime
    case location
    case person
}

enum ConfidenceLevel: String, Codable, Sendable {
    case high
    case medium
    case low
}

/// Who the statement applies to and whether it represents a user action.
enum IntentAttribution: String, Codable, Sendable {
    case userAction
    case otherPerson
    case question
    case historical
    case hypothetical
    case entityOnly
}

enum ProcessingState: String, Codable, Sendable {
    case importing
    case extracting
    case understanding
    case generatingDrafts
    case readyForReview
    case failed
    case discarded
}

enum PipelineStage: String, Codable, Sendable {
    case extraction
    case understanding
    case draftGeneration
}

enum FailureReason: String, Codable, Sendable {
    case invalidInput
    case unsupportedInput
    case ocrFailed
    case aiUnavailable
    case aiExtractionFailed
    case malformedOutput
    case draftGenerationFailed
    case persistenceFailed
    case cancelled
    case interrupted
    case permissionDenied
    case calendarFailed
    case reminderFailed
}

struct Source: Sendable {
    nonisolated let type: SourceType
    nonisolated let text: String?
    nonisolated let imageData: Data?

    nonisolated init(type: SourceType, text: String?, imageData: Data?) {
        self.type = type
        self.text = text
        self.imageData = imageData
    }

    nonisolated static func pastedText(_ text: String) -> Source {
        Source(type: .text, text: text, imageData: nil)
    }

    nonisolated static func pickedImage(_ data: Data) -> Source {
        Source(type: .image, text: nil, imageData: data)
    }
}

struct ExtractedText: Sendable {
    nonisolated let text: String
    nonisolated let method: ExtractionMethod
    nonisolated let ocrConfidence: Double?

    nonisolated init(text: String, method: ExtractionMethod, ocrConfidence: Double?) {
        self.text = text
        self.method = method
        self.ocrConfidence = ocrConfidence
    }
}

struct IntakeSnapshot: Identifiable, Sendable {
    nonisolated let id: UUID
    nonisolated let sourceType: SourceType
    nonisolated let extractedText: String?
    nonisolated let temporaryImageRef: String?
    nonisolated let processingState: ProcessingState
    nonisolated let failedStage: PipelineStage?
    nonisolated let failureReason: FailureReason?
    nonisolated let createdAt: Date
    nonisolated let updatedAt: Date

    nonisolated init(
        id: UUID,
        sourceType: SourceType,
        extractedText: String?,
        temporaryImageRef: String?,
        processingState: ProcessingState,
        failedStage: PipelineStage?,
        failureReason: FailureReason?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.sourceType = sourceType
        self.extractedText = extractedText
        self.temporaryImageRef = temporaryImageRef
        self.processingState = processingState
        self.failedStage = failedStage
        self.failureReason = failureReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum ExtractionError: Error, Sendable {
    case invalidImage
    case emptyResult
    case ocrFailed
}

struct IntentEntity: Equatable, Sendable, Identifiable {
    nonisolated let id: UUID
    nonisolated let kind: EntityKind
    nonisolated let rawExpression: String
    nonisolated let normalizedValue: String?
    nonisolated let ambiguous: Bool

    nonisolated init(
        id: UUID = UUID(),
        kind: EntityKind,
        rawExpression: String,
        normalizedValue: String? = nil,
        ambiguous: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.rawExpression = rawExpression
        self.normalizedValue = normalizedValue
        self.ambiguous = ambiguous
    }
}

struct Intent: Equatable, Sendable, Identifiable {
    nonisolated let id: UUID
    nonisolated let kind: IntentKind
    nonisolated let sourcePhrase: String
    nonisolated let entities: [IntentEntity]
    nonisolated let confidence: ConfidenceLevel
    nonisolated let ambiguous: Bool
    nonisolated let attribution: IntentAttribution

    nonisolated init(
        id: UUID = UUID(),
        kind: IntentKind,
        sourcePhrase: String,
        entities: [IntentEntity] = [],
        confidence: ConfidenceLevel,
        ambiguous: Bool = false,
        attribution: IntentAttribution
    ) {
        self.id = id
        self.kind = kind
        self.sourcePhrase = sourcePhrase
        self.entities = entities
        self.confidence = confidence
        self.ambiguous = ambiguous
        self.attribution = attribution
    }
}

struct UnderstandingResult: Equatable, Sendable {
    nonisolated let intents: [Intent]
    nonisolated let engine: EngineKind

    nonisolated init(intents: [Intent], engine: EngineKind) {
        self.intents = intents
        self.engine = engine
    }
}

struct UnderstandingOutcome: Sendable {
    nonisolated let snapshot: IntakeSnapshot
    nonisolated let filteredIntents: [Intent]

    nonisolated init(snapshot: IntakeSnapshot, filteredIntents: [Intent]) {
        self.snapshot = snapshot
        self.filteredIntents = filteredIntents
    }
}

enum UnderstandingError: Error, Sendable {
    case unavailable
    case extractionFailed
    case malformedOutput
}
