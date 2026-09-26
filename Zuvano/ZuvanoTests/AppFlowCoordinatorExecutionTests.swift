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
        executionState: ExecutionState = .notStarted
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
            executionState: executionState
        )
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
}
