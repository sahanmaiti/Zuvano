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

    func fetchDrafts(for intakeID: UUID) throws -> [ActionDraftSnapshot] {
        guard let intake = try fetchIntake(id: intakeID) else {
            throw StoreError.intakeNotFound
        }
        return intake.drafts
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.snapshot() }
    }

    func replaceDrafts(for intakeID: UUID, drafts: [ActionDraftSnapshot]) throws -> [ActionDraftSnapshot] {
        guard let intake = try fetchIntake(id: intakeID) else {
            throw StoreError.intakeNotFound
        }

        for draft in intake.drafts {
            modelContext.delete(draft)
        }
        intake.drafts.removeAll()

        for snapshot in drafts {
            let record = ActionDraftRecord.from(snapshot: snapshot)
            record.intake = intake
            intake.drafts.append(record)
            modelContext.insert(record)
        }

        intake.updatedAt = .now
        try modelContext.save()
        return try fetchDrafts(for: intakeID)
    }

    func updateDraft(_ snapshot: ActionDraftSnapshot) throws -> ActionDraftSnapshot {
        guard let draft = try fetchDraft(id: snapshot.id) else {
            throw StoreError.draftNotFound
        }
        draft.apply(snapshot: snapshot)
        try modelContext.save()
        return draft.snapshot()
    }

    func deleteDrafts(for intakeID: UUID) throws {
        guard let intake = try fetchIntake(id: intakeID) else {
            throw StoreError.intakeNotFound
        }
        for draft in intake.drafts {
            modelContext.delete(draft)
        }
        intake.drafts.removeAll()
        intake.updatedAt = .now
        try modelContext.save()
    }

    private func fetchDraft(id: UUID) throws -> ActionDraftRecord? {
        let descriptor = FetchDescriptor<ActionDraftRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func fetchIntake(id: UUID) throws -> IntakeRecord? {
        let descriptor = FetchDescriptor<IntakeRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    enum StoreError: Error {
        case intakeNotFound
        case draftNotFound
    }
}
