import Foundation
import SwiftData
import Testing
@testable import Zuvano

struct DraftGenerationTests {
    private func makePipeline() throws -> (IntakePipeline, ActionStore) {
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
        return (pipeline, store)
    }

    @Test func workedExampleProducesThreeDrafts() async throws {
        let (pipeline, _) = try makePipeline()
        let text = """
        Yeah Friday works. Let's meet around 7 at the café near campus. \
        Don't forget to bring the project files. Also remind me Thursday to call Arjun. \
        Arjun will send the files tomorrow. Did you send the file yesterday?
        """

        let outcome = try await pipeline.startIntake(from: .pastedText(text))

        #expect(outcome.snapshot.processingState == .readyForReview)
        #expect(outcome.drafts.count == 3)
        #expect(outcome.drafts.contains { $0.actionKind == .calendarEvent })
        #expect(outcome.drafts.filter { $0.actionKind == .reminder }.count == 2)
    }

    @Test func emptyIntentsProduceZeroDrafts() async throws {
        let (pipeline, _) = try makePipeline()

        let outcome = try await pipeline.startIntake(
            from: .pastedText("Did you send the file yesterday?")
        )

        #expect(outcome.snapshot.processingState == .readyForReview)
        #expect(outcome.drafts.isEmpty)
    }

    @Test func draftsArePersisted() async throws {
        let (pipeline, store) = try makePipeline()

        let outcome = try await pipeline.startIntake(
            from: .pastedText("Remind me Thursday to call Arjun.")
        )

        let loaded = try await store.fetchDrafts(for: outcome.snapshot.id)
        #expect(loaded.count == 1)
        #expect(loaded[0].actionKind == .reminder)
    }

    @Test func calendarAndReminderInSameIntake() async throws {
        let (pipeline, _) = try makePipeline()
        let text = "Let's meet Friday at 7. Also remind me to call Sam."

        let outcome = try await pipeline.startIntake(from: .pastedText(text))

        #expect(outcome.drafts.count >= 2)
        #expect(outcome.drafts.contains { $0.actionKind == .calendarEvent })
        #expect(outcome.drafts.contains { $0.actionKind == .reminder })
    }

    @Test func readyForReviewRecoveryLoadsDraftsWithoutReunderstanding() async throws {
        let (pipeline, store) = try makePipeline()

        let outcome = try await pipeline.startIntake(
            from: .pastedText("Remind me to call Sam.")
        )
        let intakeID = outcome.snapshot.id

        let recovered = await pipeline.recoverSessionsOnLaunch()
        #expect(recovered.count == 1)
        #expect(recovered[0].processingState == .readyForReview)

        let drafts = try await store.fetchDrafts(for: intakeID)
        #expect(drafts.count == 1)
    }

    @Test func draftMapperMapsMeetingToCalendar() {
        let intent = Intent(
            kind: .meeting,
            sourcePhrase: "Let's meet Friday.",
            confidence: .high,
            attribution: .userAction
        )
        let intakeID = UUID()
        let drafts = DraftMapper.map([intent], intakeID: intakeID)

        #expect(drafts.count == 1)
        #expect(drafts[0].actionKind == .calendarEvent)
        #expect(drafts[0].intakeID == intakeID)
    }

    @Test func draftMapperMapsTaskToReminder() {
        let intent = Intent(
            kind: .task,
            sourcePhrase: "Don't forget to bring the project files.",
            confidence: .medium,
            attribution: .userAction
        )
        let drafts = DraftMapper.map([intent], intakeID: UUID())

        #expect(drafts.count == 1)
        #expect(drafts[0].actionKind == .reminder)
    }
}
