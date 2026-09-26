import Foundation
import SwiftData
import Testing
@testable import Zuvano

struct PurgeTests {
    @Test func purgeIntakeRemovesTextDraftsAndTemporaryImage() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zuvano-purge-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: imageDirectory) }

        let store = ActionStore(modelContainer: container)
        await store.setImageStoreDirectory(imageDirectory)

        let imageData = Data("fake-screenshot".utf8)
        let intake = try await store.createIntake(sourceType: .image, imageData: imageData)
        let imageRef = try #require(intake.temporaryImageRef)

        _ = try await store.updateIntake(
            id: intake.id,
            processingState: .readyForReview,
            extractedText: .some("Sensitive conversation text.")
        )

        let draft = ActionDraftSnapshot(
            intakeID: intake.id,
            intentKind: .reminder,
            actionKind: .reminder,
            title: "Call Sam",
            sourcePhrase: "I'll call Sam tomorrow",
            when: nil,
            confidence: .high,
            confirmationState: .pending,
            executionState: .notStarted
        )
        _ = try await store.replaceDrafts(for: intake.id, drafts: [draft])

        _ = try await store.loadTemporaryImage(fileName: imageRef)
        #expect(FileManager.default.fileExists(atPath: imageDirectory.appendingPathComponent(imageRef).path))

        try await store.purgeIntake(id: intake.id)

        #expect(try await store.snapshot(for: intake.id) == nil)
        #expect(FileManager.default.fileExists(atPath: imageDirectory.appendingPathComponent(imageRef).path) == false)

        await #expect(throws: ActionStore.StoreError.intakeNotFound) {
            try await store.fetchDrafts(for: intake.id)
        }
    }

    @Test func modelContainerProductionConfigurationSucceeds() throws {
        _ = try ZuvanoModelContainer.make()
    }
}
