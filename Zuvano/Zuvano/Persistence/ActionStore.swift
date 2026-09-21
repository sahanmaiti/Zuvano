import Foundation
import SwiftData

@ModelActor
actor ActionStore {
    private var imageStore = TemporaryImageStore()

    func setImageStoreDirectory(_ url: URL) {
        imageStore = TemporaryImageStore(directoryURL: url)
    }

    func createIntake(sourceType: SourceType, imageData: Data?) throws -> IntakeSnapshot {
        let intake = IntakeRecord(sourceType: sourceType)
        if let imageData {
            let ref = try imageStore.save(imageData: imageData, intakeID: intake.id)
            intake.temporaryImageRef = ref
        }
        modelContext.insert(intake)
        try modelContext.save()
        return intake.snapshot()
    }

    func snapshot(for id: UUID) throws -> IntakeSnapshot? {
        try fetchIntake(id: id)?.snapshot()
    }

    func fetchActiveSnapshots() throws -> [IntakeSnapshot] {
        let descriptor = FetchDescriptor<IntakeRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
            .filter { $0.processingState != .discarded }
            .map { $0.snapshot() }
    }

    func updateIntake(
        id: UUID,
        processingState: ProcessingState? = nil,
        extractedText: String?? = nil,
        temporaryImageRef: String?? = nil,
        failedStage: PipelineStage?? = nil,
        failureReason: FailureReason?? = nil
    ) throws -> IntakeSnapshot {
        guard let intake = try fetchIntake(id: id) else {
            throw StoreError.intakeNotFound
        }

        if let processingState {
            intake.processingState = processingState
        }
        if let extractedText {
            intake.extractedText = extractedText
        }
        if let temporaryImageRef {
            intake.temporaryImageRef = temporaryImageRef
        }
        if let failedStage {
            intake.failedStage = failedStage
        }
        if let failureReason {
            intake.failureReason = failureReason
        }
        intake.updatedAt = .now
        try modelContext.save()
        return intake.snapshot()
    }

    func loadTemporaryImage(fileName: String) throws -> Data {
        try imageStore.load(fileName: fileName)
    }

    func deleteTemporaryImage(fileName: String?) {
        imageStore.delete(fileName: fileName)
    }

    func purgeIntake(id: UUID) throws {
        guard let intake = try fetchIntake(id: id) else { return }
        deleteTemporaryImage(fileName: intake.temporaryImageRef)
        intake.extractedText = nil
        intake.temporaryImageRef = nil
        intake.processingState = .discarded
        intake.updatedAt = .now
        modelContext.delete(intake)
        try modelContext.save()
    }

    private func fetchIntake(id: UUID) throws -> IntakeRecord? {
        let descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    enum StoreError: Error {
        case intakeNotFound
    }
}
