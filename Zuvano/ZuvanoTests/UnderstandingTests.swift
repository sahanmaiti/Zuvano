import Foundation
import SwiftData
import Testing
@testable import Zuvano

struct UserActionableFilterTests {
    @Test func keepsUserActions() {
        let intent = Intent(
            kind: .reminder,
            sourcePhrase: "Remind me Thursday to call Arjun.",
            confidence: .high,
            attribution: .userAction
        )

        #expect(UserActionableFilter.isUserActionable(intent))
    }

    @Test func dropsOtherPersonCommitments() {
        let intent = Intent(
            kind: .commitment,
            sourcePhrase: "Arjun will send the files tomorrow.",
            confidence: .high,
            attribution: .otherPerson
        )

        #expect(UserActionableFilter.isUserActionable(intent) == false)
    }

    @Test func dropsQuestions() {
        let intent = Intent(
            kind: .task,
            sourcePhrase: "Did you send the file yesterday?",
            confidence: .medium,
            attribution: .question
        )

        #expect(UserActionableFilter.isUserActionable(intent) == false)
    }

    @Test func dropsHistoricalStatements() {
        let intent = Intent(
            kind: .meeting,
            sourcePhrase: "Remember that we met Friday.",
            confidence: .medium,
            attribution: .historical
        )

        #expect(UserActionableFilter.isUserActionable(intent) == false)
    }

    @Test func dropsHypotheticals() {
        let intent = Intent(
            kind: .meeting,
            sourcePhrase: "I might go to Delhi next week.",
            confidence: .low,
            attribution: .hypothetical
        )

        #expect(UserActionableFilter.isUserActionable(intent) == false)
    }

    @Test func dropsFollowUpInMVP() {
        let intent = Intent(
            kind: .followUp,
            sourcePhrase: "Follow up with Sam next week.",
            confidence: .medium,
            attribution: .userAction
        )

        #expect(UserActionableFilter.isUserActionable(intent) == false)
    }

    @Test func dropsEntityOnly() {
        let intent = Intent(
            kind: .task,
            sourcePhrase: "Friday",
            confidence: .low,
            attribution: .entityOnly
        )

        #expect(UserActionableFilter.isUserActionable(intent) == false)
    }
}

struct FallbackUnderstandingEngineTests {
    private let engine = FallbackUnderstandingEngine()

    @Test func extractsWorkedExampleActions() async throws {
        let text = """
        Yeah Friday works. Let's meet around 7 at the café near campus. \
        Don't forget to bring the project files. Also remind me Thursday to call Arjun. \
        Arjun will send the files tomorrow. Did you send the file yesterday?
        """

        let result = try await engine.understand(text)
        let filtered = UserActionableFilter.filter(result.intents)

        #expect(result.engine == .fallback)
        #expect(filtered.count == 3)
        #expect(filtered.contains { $0.kind == .meeting })
        #expect(filtered.contains { $0.kind == .task })
        #expect(filtered.contains { $0.kind == .reminder })
    }

    @Test func doesNotFabricateFromQuestions() async throws {
        let result = try await engine.understand("Did you send the file yesterday?")
        let filtered = UserActionableFilter.filter(result.intents)

        #expect(filtered.isEmpty)
    }

    @Test func doesNotFabricateFromOtherPersonCommitments() async throws {
        let result = try await engine.understand("Arjun will send the files tomorrow.")
        let filtered = UserActionableFilter.filter(result.intents)

        #expect(filtered.isEmpty)
    }

    @Test func returnsEmptyForNoActionableContent() async throws {
        let result = try await engine.understand("Maybe we can meet Friday.")
        let filtered = UserActionableFilter.filter(result.intents)

        #expect(filtered.isEmpty)
    }
}

struct UnderstandingPipelineTests {
    private func makePipeline(
        extractor: any TextExtracting = PassthroughTextExtractor(),
        understandingEngine: any UnderstandingEngine = FallbackUnderstandingEngine()
    ) throws -> IntakePipeline {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        return IntakePipeline(store: store, extractor: extractor, understandingEngine: understandingEngine)
    }

    @Test func textIntakeRunsUnderstandingAndFiltering() async throws {
        let pipeline = try makePipeline()
        let text = "Remind me Thursday to call Arjun. Arjun will send the files tomorrow."

        let outcome = try await pipeline.startIntake(from: .pastedText(text))

        #expect(outcome.snapshot.processingState == .readyForReview)
        #expect(outcome.snapshot.extractedText == text)
        #expect(outcome.drafts.count == 1)
        #expect(outcome.drafts[0].actionKind == .reminder)
    }

    @Test func understandingFailureIsRetryable() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let failingPipeline = IntakePipeline(
            store: store,
            extractor: PassthroughTextExtractor(),
            understandingEngine: MockUnderstandingEngine(result: .failure(.extractionFailed))
        )

        let outcome = try await failingPipeline.startIntake(from: .pastedText("Remind me tomorrow."))

        #expect(outcome.snapshot.processingState == .failed)
        #expect(outcome.snapshot.failedStage == .understanding)
        #expect(outcome.drafts.isEmpty)

        let retryPipeline = IntakePipeline(
            store: store,
            extractor: PassthroughTextExtractor(),
            understandingEngine: FallbackUnderstandingEngine()
        )
        let retried = try await retryPipeline.retryUnderstanding(intakeID: outcome.snapshot.id)

        #expect(retried.snapshot.processingState == .readyForReview)
        #expect(retried.drafts.count == 1)
    }

    @Test func compositeFallsBackWhenPrimaryFails() async throws {
        let pipeline = try makePipeline(
            understandingEngine: CompositeUnderstandingEngine(
                primary: MockUnderstandingEngine(result: .failure(.unavailable)),
                fallback: FallbackUnderstandingEngine()
            )
        )

        let outcome = try await pipeline.startIntake(
            from: .pastedText("Don't forget to bring the project files.")
        )

        #expect(outcome.snapshot.processingState == .readyForReview)
        #expect(outcome.drafts.count == 1)
        #expect(outcome.drafts[0].actionKind == .reminder)
    }

    @Test func manualTextRunsUnderstanding() async throws {
        let pipeline = try makePipeline(
            extractor: StubTextExtractor(result: .failure(.emptyResult))
        )

        let failed = try await pipeline.startIntake(from: .pickedImage(Data("fake-image".utf8)))
        let outcome = try await pipeline.applyManualText(
            intakeID: failed.snapshot.id,
            text: "Let's meet Friday at 7."
        )

        #expect(outcome.snapshot.processingState == .readyForReview)
        #expect(outcome.drafts.count == 1)
        #expect(outcome.drafts[0].actionKind == .calendarEvent)
    }

    @Test func readyForReviewIntakeResumesOnLaunch() async throws {
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

        _ = try await pipeline.startIntake(from: .pastedText("Remind me to call Sam."))
        let recovered = await pipeline.recoverSessionsOnLaunch()

        #expect(recovered.count == 1)
        #expect(recovered[0].processingState == .readyForReview)
    }
}
