import Foundation

struct IntakePipeline: Sendable {
    private let store: ActionStore
    private let extractor: any TextExtracting

    nonisolated init(store: ActionStore, extractor: any TextExtracting = VisionTextExtractor()) {
        self.store = store
        self.extractor = extractor
    }

    nonisolated func startIntake(from source: Source) async throws -> IntakeSnapshot {
        let trimmedText = source.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = trimmedText?.isEmpty == false
        let hasImage = source.imageData != nil

        guard hasText || hasImage else {
            throw PipelineError.invalidInput
        }

        let snapshot = try await store.createIntake(
            sourceType: source.type,
            imageData: source.imageData
        )

        _ = try await store.updateIntake(id: snapshot.id, processingState: .extracting)
        return try await runExtraction(intakeID: snapshot.id, source: source)
    }

    nonisolated func retryUnderstanding(intakeID: UUID) async throws -> IntakeSnapshot {
        guard let intake = try await store.snapshot(for: intakeID) else {
            throw PipelineError.intakeNotFound
        }

        guard intake.failedStage == .understanding,
              let text = intake.extractedText,
              !text.isEmpty else {
            throw PipelineError.invalidRetry
        }

        return try await store.updateIntake(
            id: intakeID,
            processingState: .understanding,
            failedStage: .some(nil),
            failureReason: .some(nil)
        )
    }

    nonisolated func retryDraftGeneration(intakeID: UUID) async throws -> IntakeSnapshot {
        guard let intake = try await store.snapshot(for: intakeID) else {
            throw PipelineError.intakeNotFound
        }

        guard intake.failedStage == .draftGeneration,
              let text = intake.extractedText,
              !text.isEmpty else {
            throw PipelineError.invalidRetry
        }

        return try await store.updateIntake(
            id: intakeID,
            processingState: .generatingDrafts,
            failedStage: .some(nil),
            failureReason: .some(nil)
        )
    }

    nonisolated func retryExtraction(intakeID: UUID) async throws -> IntakeSnapshot {
        guard let intake = try await store.snapshot(for: intakeID) else {
            throw PipelineError.intakeNotFound
        }

        guard intake.failedStage == .extraction || intake.processingState == .extracting else {
            throw PipelineError.invalidRetry
        }

        _ = try await store.updateIntake(
            id: intakeID,
            processingState: .extracting,
            failedStage: .some(nil),
            failureReason: .some(nil)
        )

        let source = try await sourceForRetry(intake: intake)
        return try await runExtraction(intakeID: intakeID, source: source)
    }

    nonisolated func applyManualText(intakeID: UUID, text: String) async throws -> IntakeSnapshot {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PipelineError.invalidInput
        }

        guard let intake = try await store.snapshot(for: intakeID) else {
            throw PipelineError.intakeNotFound
        }

        await store.deleteTemporaryImage(fileName: intake.temporaryImageRef)

        return try await store.updateIntake(
            id: intakeID,
            processingState: .understanding,
            extractedText: .some(trimmed),
            temporaryImageRef: .some(nil),
            failedStage: .some(nil),
            failureReason: .some(nil)
        )
    }

    nonisolated func discard(intakeID: UUID) async throws {
        try await store.purgeIntake(id: intakeID)
    }

    /// Resumes or recovers in-flight intakes after launch.
    /// Extraction-complete intakes (`.understanding` with text) are resumed, not marked failed.
    nonisolated func recoverSessionsOnLaunch() async -> [IntakeSnapshot] {
        do {
            let intakes = try await store.fetchActiveSnapshots()
            var recovered: [IntakeSnapshot] = []

            for intake in intakes {
                switch intake.processingState {
                case .understanding:
                    if let text = intake.extractedText, !text.isEmpty {
                        recovered.append(intake)
                    } else {
                        let snapshot = try await store.updateIntake(
                            id: intake.id,
                            processingState: .failed,
                            failedStage: .some(.understanding),
                            failureReason: .some(.interrupted)
                        )
                        recovered.append(snapshot)
                    }
                case .generatingDrafts:
                    let snapshot = try await store.updateIntake(
                        id: intake.id,
                        processingState: .failed,
                        failedStage: .some(.understanding),
                        failureReason: .some(.interrupted)
                    )
                    recovered.append(snapshot)
                case .importing, .extracting:
                    let snapshot = try await store.updateIntake(
                        id: intake.id,
                        processingState: .failed,
                        failedStage: .some(.extraction),
                        failureReason: .some(.interrupted)
                    )
                    recovered.append(snapshot)
                case .failed:
                    recovered.append(intake)
                default:
                    continue
                }
            }

            return recovered.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            return []
        }
    }

    nonisolated func snapshot(for intakeID: UUID) async throws -> IntakeSnapshot {
        guard let snapshot = try await store.snapshot(for: intakeID) else {
            throw PipelineError.intakeNotFound
        }
        return snapshot
    }

    nonisolated private func runExtraction(intakeID: UUID, source: Source) async throws -> IntakeSnapshot {
        do {
            let resolvedSource = try await resolvedSource(source: source, intakeID: intakeID)
            let extracted = try await extractor.extract(from: resolvedSource)

            let current = try await store.snapshot(for: intakeID)
            await store.deleteTemporaryImage(fileName: current?.temporaryImageRef)

            return try await store.updateIntake(
                id: intakeID,
                processingState: .understanding,
                extractedText: .some(extracted.text),
                temporaryImageRef: .some(nil),
                failedStage: .some(nil),
                failureReason: .some(nil)
            )
        } catch {
            let failureReason: FailureReason
            if let extractionError = error as? ExtractionError {
                switch extractionError {
                case .invalidImage, .emptyResult, .ocrFailed:
                    failureReason = .ocrFailed
                }
            } else if error is PipelineError {
                failureReason = .invalidInput
            } else {
                failureReason = .ocrFailed
            }

            return try await store.updateIntake(
                id: intakeID,
                processingState: .failed,
                failedStage: .some(.extraction),
                failureReason: .some(failureReason)
            )
        }
    }

    nonisolated private func resolvedSource(source: Source, intakeID: UUID) async throws -> Source {
        if source.imageData != nil || source.text != nil {
            return source
        }

        guard let intake = try await store.snapshot(for: intakeID),
              let ref = intake.temporaryImageRef else {
            throw ExtractionError.invalidImage
        }

        let imageData = try await store.loadTemporaryImage(fileName: ref)
        return Source(type: intake.sourceType, text: nil, imageData: imageData)
    }

    nonisolated private func sourceForRetry(intake: IntakeSnapshot) async throws -> Source {
        if let text = intake.extractedText, !text.isEmpty {
            return Source(type: intake.sourceType, text: text, imageData: nil)
        }

        if let ref = intake.temporaryImageRef {
            let imageData = try await store.loadTemporaryImage(fileName: ref)
            return Source(type: intake.sourceType, text: nil, imageData: imageData)
        }

        throw ExtractionError.invalidImage
    }

    enum PipelineError: Error {
        case invalidInput
        case intakeNotFound
        case invalidRetry
    }
}
