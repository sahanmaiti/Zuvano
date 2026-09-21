import Foundation
import SwiftData
import Testing
@testable import Zuvano

struct TextExtractionTests {
    @Test func pastedTextPassesThrough() async throws {
        let extractor = PassthroughTextExtractor()
        let source = Source.pastedText("Meet Friday at 7.")

        let result = try await extractor.extract(from: source)

        #expect(result.text == "Meet Friday at 7.")
        #expect(result.method == .direct)
        #expect(result.ocrConfidence == nil)
    }

    @Test func emptyTextFails() async throws {
        let extractor = PassthroughTextExtractor()
        let source = Source.pastedText("   ")

        await #expect(throws: ExtractionError.emptyResult) {
            try await extractor.extract(from: source)
        }
    }
}

struct IntakePipelineTests {
    @Test func textIntakeProducesExtractedText() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(store: store, extractor: PassthroughTextExtractor())

        let snapshot = try await pipeline.startIntake(from: .pastedText("Call Arjun on Thursday."))

        #expect(snapshot.processingState == .understanding)
        #expect(snapshot.extractedText == "Call Arjun on Thursday.")
        #expect(snapshot.temporaryImageRef == nil)
    }

    @Test func ocrFailureKeepsTemporaryImageReference() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let failingExtractor = StubTextExtractor(result: .failure(ExtractionError.emptyResult))
        let pipeline = IntakePipeline(store: store, extractor: failingExtractor)

        let snapshot = try await pipeline.startIntake(
            from: .pickedImage(Data("fake-image".utf8))
        )

        #expect(snapshot.processingState == .failed)
        #expect(snapshot.failedStage == .extraction)
        #expect(snapshot.failureReason == .ocrFailed)
        #expect(snapshot.temporaryImageRef != nil)
    }

    @Test func manualTextFallbackClearsTemporaryImage() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let failingExtractor = StubTextExtractor(result: .failure(ExtractionError.emptyResult))
        let pipeline = IntakePipeline(store: store, extractor: failingExtractor)

        let failedSnapshot = try await pipeline.startIntake(
            from: .pickedImage(Data("fake-image".utf8))
        )

        let recovered = try await pipeline.applyManualText(
            intakeID: failedSnapshot.id,
            text: "Manual conversation text."
        )

        #expect(recovered.processingState == .understanding)
        #expect(recovered.extractedText == "Manual conversation text.")
        #expect(recovered.temporaryImageRef == nil)
    }

    @Test func recoverInterruptedExtractionMarksFailed() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(store: store, extractor: PassthroughTextExtractor())

        let snapshot = try await store.createIntake(sourceType: .text, imageData: nil)
        _ = try await store.updateIntake(id: snapshot.id, processingState: .extracting)

        let recovered = await pipeline.recoverSessionsOnLaunch()

        #expect(recovered.count == 1)
        #expect(recovered[0].processingState == .failed)
        #expect(recovered[0].failedStage == .extraction)
        #expect(recovered[0].failureReason == .interrupted)
    }

    @Test func completedExtractionResumesOnLaunch() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(store: store, extractor: PassthroughTextExtractor())

        let snapshot = try await pipeline.startIntake(from: .pastedText("Saved conversation text."))
        let recovered = await pipeline.recoverSessionsOnLaunch()

        #expect(snapshot.processingState == .understanding)
        #expect(recovered.count == 1)
        #expect(recovered[0].processingState == .understanding)
        #expect(recovered[0].extractedText == "Saved conversation text.")
    }

    @Test func successfulExtractionDeletesTemporaryImageFile() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let container = try ModelContainer(
            for: IntakeRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        await store.setImageStoreDirectory(tempDirectory)

        let failingPipeline = IntakePipeline(
            store: store,
            extractor: StubTextExtractor(result: .failure(.emptyResult))
        )
        let failedSnapshot = try await failingPipeline.startIntake(
            from: .pickedImage(Data("fake-image".utf8))
        )
        let fileName = try #require(failedSnapshot.temporaryImageRef)
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let succeedingPipeline = IntakePipeline(
            store: store,
            extractor: StubTextExtractor(
                result: .success(
                    ExtractedText(text: "OCR text", method: .ocr, ocrConfidence: 0.95)
                )
            )
        )
        let result = try await succeedingPipeline.retryExtraction(intakeID: failedSnapshot.id)

        #expect(result.extractedText == "OCR text")
        #expect(result.temporaryImageRef == nil)
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
    }

    @Test func retryExtractionAfterFailure() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)

        let failingExtractor = StubTextExtractor(result: .failure(ExtractionError.emptyResult))
        let failingPipeline = IntakePipeline(store: store, extractor: failingExtractor)
        let failedSnapshot = try await failingPipeline.startIntake(
            from: .pickedImage(Data("fake-image".utf8))
        )

        let succeedingPipeline = IntakePipeline(store: store, extractor: PassthroughTextExtractor())
        // Simulate retry by applying manual path is separate; for OCR retry use a succeeding OCR mock.
        let ocrExtractor = StubTextExtractor(
            result: .success(
                ExtractedText(text: "Recovered OCR text", method: .ocr, ocrConfidence: 0.9)
            )
        )
        let retryPipeline = IntakePipeline(store: store, extractor: ocrExtractor)
        let retried = try await retryPipeline.retryExtraction(intakeID: failedSnapshot.id)

        #expect(retried.processingState == .understanding)
        #expect(retried.extractedText == "Recovered OCR text")
        #expect(retried.temporaryImageRef == nil)
    }
}
