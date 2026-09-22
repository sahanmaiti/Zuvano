import Foundation
import SwiftData

@Model
final class IntakeRecord {
    @Attribute(.unique) var id: UUID
    var sourceTypeRaw: String
    var extractedText: String?
    var temporaryImageRef: String?
    var processingStateRaw: String
    var failedStageRaw: String?
    var failureReasonRaw: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ActionDraftRecord.intake)
    var drafts: [ActionDraftRecord] = []

    init(
        id: UUID = UUID(),
        sourceType: SourceType,
        extractedText: String? = nil,
        temporaryImageRef: String? = nil,
        processingState: ProcessingState = .importing,
        failedStage: PipelineStage? = nil,
        failureReason: FailureReason? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.sourceTypeRaw = sourceType.rawValue
        self.extractedText = extractedText
        self.temporaryImageRef = temporaryImageRef
        self.processingStateRaw = processingState.rawValue
        self.failedStageRaw = failedStage?.rawValue
        self.failureReasonRaw = failureReason?.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .text }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var processingState: ProcessingState {
        get { ProcessingState(rawValue: processingStateRaw) ?? .importing }
        set { processingStateRaw = newValue.rawValue }
    }

    var failedStage: PipelineStage? {
        get { failedStageRaw.flatMap(PipelineStage.init(rawValue:)) }
        set { failedStageRaw = newValue?.rawValue }
    }

    var failureReason: FailureReason? {
        get { failureReasonRaw.flatMap(FailureReason.init(rawValue:)) }
        set { failureReasonRaw = newValue?.rawValue }
    }

    nonisolated func snapshot() -> IntakeSnapshot {
        IntakeSnapshot(
            id: id,
            sourceType: sourceType,
            extractedText: extractedText,
            temporaryImageRef: temporaryImageRef,
            processingState: processingState,
            failedStage: failedStage,
            failureReason: failureReason,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
