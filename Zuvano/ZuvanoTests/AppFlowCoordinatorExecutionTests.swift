import EventKit
import Foundation
import SwiftData
import Testing
@testable import Zuvano

@MainActor
struct AppFlowCoordinatorExecutionTests {
    private func makeCoordinator(
        executionService: DraftExecutionService
    ) throws -> (AppFlowCoordinator, ActionStore) {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(store: store)
        let coordinator = AppFlowCoordinator(
            pipeline: pipeline,
            store: store,
            executionService: executionService
        )
        return (coordinator, store)
    }

    private func sampleDraft(
        intakeID: UUID,
        id: UUID = UUID(),
        actionKind: ActionKind = .calendarEvent,
        confirmationState: ConfirmationState = .pending,
        executionState: ExecutionState = .notStarted,
        executionError: FailureReason? = nil
    ) -> ActionDraftSnapshot {
        ActionDraftSnapshot(
            id: id,
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
            executionError: executionError
        )
    }

    private func makeCoordinatorWithPipeline(
        pipeline: IntakePipeline,
        store: ActionStore,
        executionService: DraftExecutionService
    ) -> AppFlowCoordinator {
        AppFlowCoordinator(pipeline: pipeline, store: store, executionService: executionService)
    }

    @discardableResult
    private func seedReview(
        coordinator: AppFlowCoordinator,
        store: ActionStore,
        makeDrafts: (UUID) -> [ActionDraftSnapshot]
    ) async throws -> UUID {
        let intake = try await store.createIntake(sourceType: .text, imageData: nil)
        let drafts = makeDrafts(intake.id)
        _ = try await store.updateIntake(id: intake.id, processingState: .readyForReview)
        _ = try await store.replaceDrafts(for: intake.id, drafts: drafts)
        coordinator.activeIntake = try await store.snapshot(for: intake.id)
        coordinator.drafts = try await store.fetchDrafts(for: intake.id)
        coordinator.flow = .actionReview
        return intake.id
    }

    @Test @MainActor func createAllExecutesMultipleDraftsToTerminalStates() async throws {
        let mock = MockEventKitExecutionStore()
        let service = DraftExecutionService(store: mock)
        let (coordinator, store) = try makeCoordinator(executionService: service)

        let intakeID = try await seedReview(
            coordinator: coordinator,
            store: store,
            makeDrafts: { intakeID in
                [
                    sampleDraft(intakeID: intakeID, actionKind: .calendarEvent),
                    sampleDraft(intakeID: intakeID, actionKind: .reminder)
                ]
            }
        )

        await coordinator.createAllReady()

        let loaded = try await store.fetchDrafts(for: intakeID)
        #expect(loaded.count == 2)
        #expect(loaded.allSatisfy { $0.executionState == .executed })
        #expect(loaded.allSatisfy { $0.nativeIdentifier != nil })
        #expect(coordinator.canFinishReview)
    }

    @Test @MainActor func saveFailurePersistsFailedNotExecuting() async throws {
        let mock = MockEventKitExecutionStore()
        mock.saveEventError = NSError(domain: "EKErrorDomain", code: 1)
        let service = DraftExecutionService(store: mock)
        let (coordinator, store) = try makeCoordinator(executionService: service)

        let intakeID = try await seedReview(
            coordinator: coordinator,
            store: store,
            makeDrafts: { intakeID in
                [sampleDraft(intakeID: intakeID, actionKind: .calendarEvent)]
            }
        )

        await coordinator.createAllReady()

        let loaded = try await store.fetchDrafts(for: intakeID)[0]
        #expect(loaded.executionState == .failed)
        #expect(loaded.executionError == .calendarSaveFailed)
        #expect(loaded.nativeIdentifier == nil)
        #expect(DraftExecutionEligibility.canRetry(loaded))
    }

    @Test @MainActor func permissionDeniedAfterPreAlertDoesNotPersistExecuting() async throws {
        let mock = MockEventKitExecutionStore()
        mock.eventAuthorization = .denied
        mock.requestEventsGranted = false
        let service = DraftExecutionService(store: mock)
        let (coordinator, store) = try makeCoordinator(executionService: service)

        _ = try await seedReview(
            coordinator: coordinator,
            store: store,
            makeDrafts: { intakeID in
                [sampleDraft(intakeID: intakeID, actionKind: .calendarEvent)]
            }
        )

        await coordinator.createAllReady()
        #expect(coordinator.showPermissionPreAlert)
        await coordinator.continueAfterPermissionPreAlert()

        let loaded = coordinator.drafts[0]
        #expect(loaded.executionState == .notStarted)
        #expect(loaded.confirmationState == .confirmed)
    }

    @Test @MainActor func overlappingCreateAllRunsSeriallyWithoutExecutingStuckState() async throws {
        let mock = MockEventKitExecutionStore()
        mock.saveEventDelayNanoseconds = 100_000_000
        let service = DraftExecutionService(store: mock)
        let (coordinator, store) = try makeCoordinator(executionService: service)

        let intakeID = try await seedReview(
            coordinator: coordinator,
            store: store,
            makeDrafts: { intakeID in
                [
                    sampleDraft(intakeID: intakeID, actionKind: .calendarEvent),
                    sampleDraft(intakeID: intakeID, actionKind: .calendarEvent)
                ]
            }
        )

        async let first: Void = coordinator.createAllReady()
        async let second: Void = coordinator.createAllReady()
        _ = await (first, second)

        let loaded = try await store.fetchDrafts(for: intakeID)
        #expect(loaded.allSatisfy { $0.executionState != .executing })
    }

    @Test @MainActor func relaunchRecoveryMarksInterruptedExecution() async throws {
        let store = try ActionStore(
            modelContainer: ModelContainer(
                for: IntakeRecord.self, ActionDraftRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
        let pipeline = IntakePipeline(store: store)

        let intake = try await store.createIntake(sourceType: .text, imageData: nil)
        _ = try await store.updateIntake(id: intake.id, processingState: .readyForReview)
        let stuck = sampleDraft(
            intakeID: intake.id,
            actionKind: .calendarEvent,
            confirmationState: .confirmed,
            executionState: .executing
        )
        _ = try await store.replaceDrafts(for: intake.id, drafts: [stuck])

        let recovered = try await pipeline.recoverDraftExecutionStates(for: intake.id)
        #expect(recovered[0].executionState == .failed)
        #expect(recovered[0].executionError == .interrupted)
        #expect(recovered[0].nativeIdentifier == nil)
    }

    @Test @MainActor func discardDuringProcessingIgnoresLateOutcome() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(
            store: store,
            extractor: PassthroughTextExtractor(),
            understandingEngine: SlowUnderstandingEngine(delayNanoseconds: 300_000_000)
        )
        let coordinator = makeCoordinatorWithPipeline(
            pipeline: pipeline,
            store: store,
            executionService: DraftExecutionService(store: MockEventKitExecutionStore())
        )

        async let processing: Void = coordinator.startIntake(from: .pastedText("Remind me tomorrow."))
        try await Task.sleep(nanoseconds: 50_000_000)
        await coordinator.discardActiveIntake()
        await processing

        #expect(coordinator.flow == .home)
        #expect(coordinator.activeIntake == nil)
        #expect(coordinator.isWorking == false)
        let active = try await store.fetchActiveSnapshots()
        #expect(active.isEmpty)
    }

    @Test @MainActor func failedShareHandoffRecoversExistingIntake() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(store: store)

        let previous = try await store.createIntake(sourceType: .text, imageData: nil)
        _ = try await store.updateIntake(
            id: previous.id,
            processingState: .readyForReview,
            extractedText: .some("Saved conversation.")
        )

        let handoffDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zuvano-handoff-fail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: handoffDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: handoffDirectory) }

        let token = UUID()
        let envelope = handoffDirectory.appendingPathComponent("\(token.uuidString).json")
        try Data("{\"sourceType\":\"not-a-source\"}".utf8).write(to: envelope)

        let coordinator = AppFlowCoordinator(
            pipeline: pipeline,
            store: store,
            executionService: DraftExecutionService(store: MockEventKitExecutionStore()),
            handoffStore: ShareHandoffStore(handoffDirectoryURL: handoffDirectory)
        )

        await coordinator.recoverOnLaunch()

        #expect(coordinator.alertMessage != nil)
        #expect(coordinator.activeIntake?.id == previous.id)
        #expect(coordinator.activeIntake?.extractedText == "Saved conversation.")
        #expect(coordinator.flow == .actionReview)
    }

    @Test @MainActor func secondStartPurgesFirstIntake() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let pipeline = IntakePipeline(
            store: store,
            extractor: PassthroughTextExtractor(),
            understandingEngine: SlowUnderstandingEngine(delayNanoseconds: 400_000_000)
        )
        let coordinator = makeCoordinatorWithPipeline(
            pipeline: pipeline,
            store: store,
            executionService: DraftExecutionService(store: MockEventKitExecutionStore())
        )

        async let first: Void = coordinator.startIntake(from: .pastedText("First conversation."))
        try await Task.sleep(nanoseconds: 50_000_000)
        await coordinator.startIntake(from: .pastedText("Second conversation wins."))
        await first

        #expect(coordinator.activeIntake?.extractedText == "Second conversation wins.")
        let active = try await store.fetchActiveSnapshots()
        #expect(active.count == 1)
        #expect(active[0].extractedText == "Second conversation wins.")
    }

    @Test @MainActor func startIntakePurgesPreviousReadyForReviewIntake() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zuvano-coordinator-purge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: imageDirectory) }

        let store = ActionStore(modelContainer: container)
        await store.setImageStoreDirectory(imageDirectory)

        let pipeline = IntakePipeline(store: store)
        let coordinator = makeCoordinatorWithPipeline(
            pipeline: pipeline,
            store: store,
            executionService: DraftExecutionService(store: MockEventKitExecutionStore())
        )

        let previous = try await store.createIntake(
            sourceType: .image,
            imageData: Data("screenshot".utf8)
        )
        let imageRef = try #require(previous.temporaryImageRef)
        _ = try await store.updateIntake(
            id: previous.id,
            processingState: .readyForReview,
            extractedText: .some("Old conversation text.")
        )

        await coordinator.startIntake(from: .pastedText("New paste."))

        let active = try await store.fetchActiveSnapshots()
        #expect(active.count == 1)
        #expect(active[0].id != previous.id)
        #expect(active[0].extractedText == "New paste.")
        #expect(try await store.snapshot(for: previous.id) == nil)
        #expect(FileManager.default.fileExists(atPath: imageDirectory.appendingPathComponent(imageRef).path) == false)
    }

    @Test @MainActor func nativeIDPersistenceFailureRetryDoesNotCallEventKitAgain() async throws {
        let mock = MockEventKitExecutionStore()
        let service = DraftExecutionService(store: mock)
        let (coordinator, store) = try makeCoordinator(executionService: service)

        var shouldFailExecutedPersist = true
        coordinator.updateDraftOverride = { draft in
            if shouldFailExecutedPersist,
               draft.executionState == .executed,
               draft.nativeIdentifier != nil {
                shouldFailExecutedPersist = false
                struct PersistError: Error {}
                throw PersistError()
            }
            return try await store.updateDraft(draft)
        }

        let draftID = UUID()
        let intakeID = try await seedReview(
            coordinator: coordinator,
            store: store,
            makeDrafts: { intakeID in
                [sampleDraft(intakeID: intakeID, id: draftID, actionKind: .calendarEvent)]
            }
        )

        await coordinator.createAllReady()

        #expect(mock.saveEventCallCount == 1)
        #expect(coordinator.lastExecutionAnnouncement == nil)
        #expect(coordinator.drafts[0].executionError == .persistenceFailed)

        await coordinator.retryExecution(id: draftID)

        #expect(mock.saveEventCallCount == 1)
        let loaded = try await store.fetchDrafts(for: intakeID)[0]
        #expect(loaded.executionState == .executed)
        #expect(loaded.nativeIdentifier != nil)
        #expect(coordinator.lastExecutionAnnouncement != nil)
    }

    @Test @MainActor func overlappingCreateAndRetrySerializeEventKitSaves() async throws {
        let mock = MockEventKitExecutionStore()
        mock.saveEventDelayNanoseconds = 250_000_000
        let service = DraftExecutionService(store: mock)
        let (coordinator, store) = try makeCoordinator(executionService: service)

        let pendingID = UUID()
        let failedID = UUID()
        _ = try await seedReview(
            coordinator: coordinator,
            store: store,
            makeDrafts: { intakeID in
                [
                    sampleDraft(intakeID: intakeID, id: pendingID, actionKind: .calendarEvent),
                    sampleDraft(
                        intakeID: intakeID,
                        id: failedID,
                        actionKind: .calendarEvent,
                        confirmationState: .confirmed,
                        executionState: .failed,
                        executionError: .calendarSaveFailed
                    )
                ]
            }
        )

        async let createAll: Void = coordinator.createAllReady()
        try await Task.sleep(nanoseconds: 20_000_000)
        async let retry: Void = coordinator.retryExecution(id: failedID)
        await (createAll, retry)

        #expect(mock.maxConcurrentSaves == 1)
        #expect(mock.saveEventCallCount == 2)
    }
}

private struct SlowUnderstandingEngine: UnderstandingEngine {
    let delayNanoseconds: UInt64

    nonisolated init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    nonisolated func understand(_ text: String) async throws -> UnderstandingResult {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return try await FallbackUnderstandingEngine().understand(text)
    }
}
