import Foundation
import SwiftData
import Testing
@testable import Zuvano

final class MockActionExecutor: ActionExecutor, @unchecked Sendable {
    nonisolated(unsafe) var result: Result<ExecutionResult, Error> = .success(ExecutionResult(nativeIdentifier: "mock-id"))
    nonisolated(unsafe) private(set) var executedDraftIDs: [UUID] = []
    nonisolated(unsafe) private(set) var executeCallCount = 0
    nonisolated(unsafe) var delayNanoseconds: UInt64 = 0

    nonisolated init() {}

    nonisolated func execute(_ draft: ActionDraftSnapshot) async throws -> ExecutionResult {
        executeCallCount += 1
        executedDraftIDs.append(draft.id)
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try result.get()
    }
}

struct ExecutionTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func sampleDraft(
        intakeID: UUID,
        actionKind: ActionKind = .reminder,
        confirmationState: ConfirmationState = .pending,
        executionState: ExecutionState = .notStarted,
        nativeIdentifier: String? = nil
    ) -> ActionDraftSnapshot {
        ActionDraftSnapshot(
            intakeID: intakeID,
            intentKind: actionKind == .calendarEvent ? .meeting : .reminder,
            actionKind: actionKind,
            title: actionKind == .calendarEvent ? "Meeting" : "Call Sam",
            sourcePhrase: "Sample phrase",
            when: ActionDateTime(
                rawExpression: "Friday 7 PM",
                startDate: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            confidence: .high,
            confirmationState: confirmationState,
            executionState: executionState,
            nativeIdentifier: nativeIdentifier
        )
    }

    @Test func launchRecoveryMarksExecutingWithIdentifierAsExecuted() async throws {
        let container = try makeContainer()
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(store: store)

        let intake = try await store.createIntake(sourceType: .text, imageData: nil)
        _ = try await store.updateIntake(id: intake.id, processingState: .readyForReview)

        let draft = sampleDraft(
            intakeID: intake.id,
            confirmationState: .confirmed,
            executionState: .executing,
            nativeIdentifier: "event-123"
        )
        _ = try await store.replaceDrafts(for: intake.id, drafts: [draft])

        let recovered = try await pipeline.recoverDraftExecutionStates(for: intake.id)

        #expect(recovered.count == 1)
        #expect(recovered[0].executionState == .executed)
        #expect(recovered[0].nativeIdentifier == "event-123")
    }

    @Test func launchRecoveryMarksExecutingWithoutIdentifierAsFailedInterrupted() async throws {
        let container = try makeContainer()
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(store: store)

        let intake = try await store.createIntake(sourceType: .text, imageData: nil)
        _ = try await store.updateIntake(id: intake.id, processingState: .readyForReview)

        let draft = sampleDraft(
            intakeID: intake.id,
            confirmationState: .confirmed,
            executionState: .executing
        )
        _ = try await store.replaceDrafts(for: intake.id, drafts: [draft])

        let recovered = try await pipeline.recoverDraftExecutionStates(for: intake.id)

        #expect(recovered.count == 1)
        #expect(recovered[0].executionState == .failed)
        #expect(recovered[0].executionError == .interrupted)
        #expect(recovered[0].nativeIdentifier == nil)
    }

    @Test func launchRecoveryDoesNotCallEventKit() async throws {
        let container = try makeContainer()
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(store: store)

        let intake = try await store.createIntake(sourceType: .text, imageData: nil)
        _ = try await store.updateIntake(id: intake.id, processingState: .readyForReview)

        let draft = sampleDraft(
            intakeID: intake.id,
            confirmationState: .confirmed,
            executionState: .executing
        )
        _ = try await store.replaceDrafts(for: intake.id, drafts: [draft])

        _ = try await pipeline.recoverDraftExecutionStates(for: intake.id)

        let loaded = try await store.fetchDrafts(for: intake.id)
        #expect(loaded[0].executionState == .failed)
        #expect(loaded[0].executionError == .interrupted)
    }

    @Test func executionEligibilityRequiresConfirmedDraftWithoutNativeIdentifier() {
        let draft = sampleDraft(intakeID: UUID(), confirmationState: .pending)
        #expect(DraftExecutionEligibility.canExecute(draft) == false)

        let confirmed = draft.updating(confirmationState: .confirmed)
        #expect(DraftExecutionEligibility.canExecute(confirmed) == true)

        let executed = confirmed.updating(
            executionState: .executed,
            nativeIdentifier: .some("id")
        )
        #expect(DraftExecutionEligibility.canExecute(executed) == false)
    }

    @Test func terminalStatesMatchDataModel() {
        let skipped = sampleDraft(intakeID: UUID(), confirmationState: .rejected)
        #expect(DraftExecutionEligibility.isTerminal(skipped))

        let created = sampleDraft(intakeID: UUID(), confirmationState: .confirmed, executionState: .executed)
        #expect(DraftExecutionEligibility.isTerminal(created))

        let failed = sampleDraft(intakeID: UUID(), confirmationState: .confirmed, executionState: .failed)
        #expect(DraftExecutionEligibility.isTerminal(failed) == false)
        #expect(DraftExecutionEligibility.isTerminal(failed, failureDismissed: true))

        let pending = sampleDraft(intakeID: UUID())
        #expect(DraftExecutionEligibility.isTerminal(pending) == false)

        let executing = sampleDraft(intakeID: UUID(), confirmationState: .confirmed, executionState: .executing)
        #expect(DraftExecutionEligibility.isTerminal(executing) == false)
    }

    @Test func mockExecutorRecordsExecution() async throws {
        let mock = MockActionExecutor()
        mock.result = .success(ExecutionResult(nativeIdentifier: "abc"))
        let draft = sampleDraft(intakeID: UUID(), confirmationState: .confirmed)

        let result = try await mock.execute(draft)

        #expect(result.nativeIdentifier == "abc")
        #expect(mock.executeCallCount == 1)
        #expect(mock.executedDraftIDs == [draft.id])
    }

    @Test func permissionDeniedLeavesDraftConfirmedNotStarted() {
        let confirmedNotStarted = sampleDraft(
            intakeID: UUID(),
            confirmationState: .confirmed,
            executionState: .notStarted
        )
        #expect(confirmedNotStarted.executionState == .notStarted)
        #expect(DraftExecutionEligibility.canExecute(confirmedNotStarted))
    }

    @Test func retryRequiresFailedWithoutNativeIdentifier() {
        let failed = sampleDraft(
            intakeID: UUID(),
            confirmationState: .confirmed,
            executionState: .failed
        )
        #expect(DraftExecutionEligibility.canRetry(failed))

        let failedWithID = failed.updating(nativeIdentifier: .some("existing"))
        #expect(DraftExecutionEligibility.canRetry(failedWithID) == false)
    }

    @Test func persistExecutingBeforeSuccessIsEligibleState() {
        let executing = sampleDraft(
            intakeID: UUID(),
            confirmationState: .confirmed,
            executionState: .executing
        )
        #expect(DraftExecutionEligibility.canExecute(executing) == false)
        #expect(DraftExecutionEligibility.isTerminal(executing) == false)
    }
}
