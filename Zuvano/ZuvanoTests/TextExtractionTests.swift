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
    private func makePipeline(extractor: any TextExtracting) throws -> IntakePipeline {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        return IntakePipeline(
            store: store,
            extractor: extractor,
            understandingEngine: FallbackUnderstandingEngine()
        )
    }

    @Test func textIntakeProducesExtractedText() async throws {
        let pipeline = try makePipeline(extractor: PassthroughTextExtractor())

        let outcome = try await pipeline.startIntake(from: .pastedText("Call Arjun on Thursday."))

        #expect(outcome.snapshot.processingState == .readyForReview)
        #expect(outcome.snapshot.extractedText == "Call Arjun on Thursday.")
        #expect(outcome.snapshot.temporaryImageRef == nil)
    }

    @Test func ocrFailureKeepsTemporaryImageReference() async throws {
        let pipeline = try makePipeline(
            extractor: StubTextExtractor(result: .failure(ExtractionError.emptyResult))
        )

        let outcome = try await pipeline.startIntake(
            from: .pickedImage(Data("fake-image".utf8))
        )

        #expect(outcome.snapshot.processingState == .failed)
        #expect(outcome.snapshot.failedStage == .extraction)
        #expect(outcome.snapshot.failureReason == .ocrFailed)
        #expect(outcome.snapshot.temporaryImageRef != nil)
    }

    @Test func manualTextFallbackClearsTemporaryImage() async throws {
        let pipeline = try makePipeline(
            extractor: StubTextExtractor(result: .failure(ExtractionError.emptyResult))
        )

        let failedOutcome = try await pipeline.startIntake(
            from: .pickedImage(Data("fake-image".utf8))
        )

        let recovered = try await pipeline.applyManualText(
            intakeID: failedOutcome.snapshot.id,
            text: "Manual conversation text."
        )

        #expect(recovered.snapshot.processingState == .readyForReview)
        #expect(recovered.snapshot.extractedText == "Manual conversation text.")
        #expect(recovered.snapshot.temporaryImageRef == nil)
    }

    @Test func recoverInterruptedExtractionMarksFailed() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(
            store: store,
            extractor: PassthroughTextExtractor(),
            understandingEngine: FallbackUnderstandingEngine()
        )

        let snapshot = try await store.createIntake(sourceType: .text, imageData: nil)
        _ = try await store.updateIntake(id: snapshot.id, processingState: .extracting)

        let recovered = await pipeline.recoverSessionsOnLaunch()

        #expect(recovered.count == 1)
        #expect(recovered[0].processingState == .failed)
        #expect(recovered[0].failedStage == .extraction)
        #expect(recovered[0].failureReason == .interrupted)
    }

    @Test func completedExtractionResumesOnLaunch() async throws {
        let pipeline = try makePipeline(extractor: PassthroughTextExtractor())

        let outcome = try await pipeline.startIntake(from: .pastedText("Saved conversation text."))
        let recovered = await pipeline.recoverSessionsOnLaunch()

        #expect(outcome.snapshot.processingState == .readyForReview)
        #expect(recovered.count == 1)
        #expect(recovered[0].processingState == .readyForReview)
        #expect(recovered[0].extractedText == "Saved conversation text.")
    }

    @Test func successfulExtractionDeletesTemporaryImageFile() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        await store.setImageStoreDirectory(tempDirectory)

        let failingPipeline = IntakePipeline(
            store: store,
            extractor: StubTextExtractor(result: .failure(.emptyResult)),
            understandingEngine: FallbackUnderstandingEngine()
        )
        let failedOutcome = try await failingPipeline.startIntake(
            from: .pickedImage(Data("fake-image".utf8))
        )
        let fileName = try #require(failedOutcome.snapshot.temporaryImageRef)
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let succeedingPipeline = IntakePipeline(
            store: store,
            extractor: StubTextExtractor(
                result: .success(
                    ExtractedText(text: "OCR text", method: .ocr, ocrConfidence: 0.95)
                )
            ),
            understandingEngine: FallbackUnderstandingEngine()
        )
        let result = try await succeedingPipeline.retryExtraction(intakeID: failedOutcome.snapshot.id)

        #expect(result.snapshot.extractedText == "OCR text")
        #expect(result.snapshot.temporaryImageRef == nil)
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
    }

    @Test func retryExtractionAfterFailure() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)

        let failingPipeline = IntakePipeline(
            store: store,
            extractor: StubTextExtractor(result: .failure(ExtractionError.emptyResult)),
            understandingEngine: FallbackUnderstandingEngine()
        )
        let failedOutcome = try await failingPipeline.startIntake(
            from: .pickedImage(Data("fake-image".utf8))
        )

        let ocrExtractor = StubTextExtractor(
            result: .success(
                ExtractedText(text: "Recovered OCR text", method: .ocr, ocrConfidence: 0.9)
            )
        )
        let retryPipeline = IntakePipeline(
            store: store,
            extractor: ocrExtractor,
            understandingEngine: FallbackUnderstandingEngine()
        )
        let retried = try await retryPipeline.retryExtraction(intakeID: failedOutcome.snapshot.id)

        #expect(retried.snapshot.processingState == .readyForReview)
        #expect(retried.snapshot.extractedText == "Recovered OCR text")
        #expect(retried.snapshot.temporaryImageRef == nil)
    }
}
