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

enum ActionKind: String, Codable, Sendable {
    case calendarEvent
    case reminder
}

enum ConfirmationState: String, Codable, Sendable {
    case pending
    case confirmed
    case rejected
}

enum ExecutionState: String, Codable, Sendable {
    case notStarted
    case executing
    case executed
    case failed
}

enum DraftValidationConcern: Equatable, Sendable {
    case ready
    case ambiguousReady
    case needsTitle
    case needsStartTime
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

struct ActionDateTime: Equatable, Sendable {
    nonisolated let rawExpression: String
    nonisolated let startDate: Date?
    nonisolated let endDate: Date?
    nonisolated let allDay: Bool
    nonisolated let ambiguous: Bool

    nonisolated init(
        rawExpression: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        allDay: Bool = false,
        ambiguous: Bool = false
    ) {
        self.rawExpression = rawExpression
        self.startDate = startDate
        self.endDate = endDate
        self.allDay = allDay
        self.ambiguous = ambiguous
    }
}

struct ActionDraftSnapshot: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let intakeID: UUID
    nonisolated let intentKind: IntentKind
    nonisolated let actionKind: ActionKind
    nonisolated let title: String
    nonisolated let sourcePhrase: String
    nonisolated let when: ActionDateTime?
    nonisolated let location: String?
    nonisolated let person: String?
    nonisolated let notes: String?
    nonisolated let confidence: ConfidenceLevel
    nonisolated let ambiguous: Bool
    nonisolated let confirmationState: ConfirmationState
    nonisolated let executionState: ExecutionState
    nonisolated let nativeIdentifier: String?
    nonisolated let executionError: FailureReason?
    nonisolated let createdAt: Date
    nonisolated let updatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        intakeID: UUID,
        intentKind: IntentKind,
        actionKind: ActionKind,
        title: String,
        sourcePhrase: String,
        when: ActionDateTime? = nil,
        location: String? = nil,
        person: String? = nil,
        notes: String? = nil,
        confidence: ConfidenceLevel,
        ambiguous: Bool = false,
        confirmationState: ConfirmationState = .pending,
        executionState: ExecutionState = .notStarted,
        nativeIdentifier: String? = nil,
        executionError: FailureReason? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.intakeID = intakeID
        self.intentKind = intentKind
        self.actionKind = actionKind
        self.title = title
        self.sourcePhrase = sourcePhrase
        self.when = when
        self.location = location
        self.person = person
        self.notes = notes
        self.confidence = confidence
        self.ambiguous = ambiguous
        self.confirmationState = confirmationState
        self.executionState = executionState
        self.nativeIdentifier = nativeIdentifier
        self.executionError = executionError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ReviewOutcome: Sendable {
    nonisolated let snapshot: IntakeSnapshot
    nonisolated let drafts: [ActionDraftSnapshot]

    nonisolated init(snapshot: IntakeSnapshot, drafts: [ActionDraftSnapshot]) {
        self.snapshot = snapshot
        self.drafts = drafts
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
