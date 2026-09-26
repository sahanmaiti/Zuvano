import EventKit
import Foundation
import SwiftData
import Testing
@testable import Zuvano

@MainActor
final class MockEventKitExecutionStore: EventKitExecutionStore {
    var eventAuthorization: EKAuthorizationStatus = .fullAccess
    var reminderAuthorization: EKAuthorizationStatus = .fullAccess
    var requestEventsGranted = true
    var requestRemindersGranted = true

    private(set) var syncCallCount = 0
    private(set) var refreshCallCount = 0
    private(set) var createCalendarCallCount = 0
    private(set) var saveEventCallCount = 0
    private(set) var saveReminderCallCount = 0
    private(set) var reconnectCount = 0

    private var preparedEventAuthorization: EKAuthorizationStatus = .notDetermined
    private var preparedReminderAuthorization: EKAuthorizationStatus = .notDetermined

    var eventEnvironment = EventKitContainerEnvironment(
        defaultCalendarIdentifier: "default-event",
        calendars: [
            EventKitCalendarSnapshot(
                calendarIdentifier: "default-event",
                title: "Default",
                allowsContentModifications: true,
                sourceIdentifier: "local",
                sourceTypeRawValue: EKSourceType.local.rawValue
            )
        ],
        sources: [
            EventKitSourceSnapshot(
                sourceIdentifier: "local",
                sourceTypeRawValue: EKSourceType.local.rawValue
            )
        ]
    )

    var reminderEnvironment = EventKitContainerEnvironment(
        defaultCalendarIdentifier: "default-reminder",
        calendars: [
            EventKitCalendarSnapshot(
                calendarIdentifier: "default-reminder",
                title: "Reminders",
                allowsContentModifications: true,
                sourceIdentifier: "local",
                sourceTypeRawValue: EKSourceType.local.rawValue
            )
        ],
        sources: [
            EventKitSourceSnapshot(
                sourceIdentifier: "local",
                sourceTypeRawValue: EKSourceType.local.rawValue
            )
        ]
    )

    var saveEventError: Error?
    var saveReminderError: Error?
    var createCalendarError: Error?
    var createCalendarIdentifier = "created-zuvano"
    var saveEventDelayNanoseconds: UInt64 = 0

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        entityType == .event ? eventAuthorization : reminderAuthorization
    }

    func requestFullAccessToEvents() async throws -> Bool {
        if requestEventsGranted {
            eventAuthorization = .fullAccess
        } else {
            eventAuthorization = .denied
        }
        return requestEventsGranted
    }

    func requestFullAccessToReminders() async throws -> Bool {
        if requestRemindersGranted {
            reminderAuthorization = .fullAccess
        } else {
            reminderAuthorization = .denied
        }
        return requestRemindersGranted
    }

    func syncStoreAfterAuthorizationIfNeeded() async {
        syncCallCount += 1
        let eventTransition = eventAuthorization == .fullAccess && preparedEventAuthorization != .fullAccess
        let reminderTransition = reminderAuthorization == .fullAccess && preparedReminderAuthorization != .fullAccess
        preparedEventAuthorization = eventAuthorization
        preparedReminderAuthorization = reminderAuthorization
        if eventTransition || reminderTransition {
            reconnectCount += 1
        }
    }

    func refreshSourcesIfNecessary() async {
        refreshCallCount += 1
    }

    func containerEnvironment(for entityType: EKEntityType) -> EventKitContainerEnvironment {
        entityType == .event ? eventEnvironment : reminderEnvironment
    }

    func createCalendar(
        title: String,
        entityType: EKEntityType,
        sourceIdentifier: String
    ) async throws -> String {
        createCalendarCallCount += 1
        if let createCalendarError {
            throw createCalendarError
        }
        return createCalendarIdentifier
    }

    func saveEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarIdentifier: String
    ) async throws -> String {
        saveEventCallCount += 1
        if saveEventDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: saveEventDelayNanoseconds)
        }
        if let saveEventError {
            throw saveEventError
        }
        return "event-\(calendarIdentifier)"
    }

    func saveReminder(
        title: String,
        dueDateComponents: DateComponents?,
        notes: String?,
        calendarIdentifier: String
    ) async throws -> String {
        saveReminderCallCount += 1
        if let saveReminderError {
            throw saveReminderError
        }
        return "reminder-\(calendarIdentifier)"
    }
}

struct DraftExecutionServiceTests {
    private func sampleDraft(
        actionKind: ActionKind = .calendarEvent,
        confirmationState: ConfirmationState = .confirmed,
        executionState: ExecutionState = .notStarted
    ) -> ActionDraftSnapshot {
        ActionDraftSnapshot(
            intakeID: UUID(),
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

    @Test @MainActor func permissionDeniedMapsToPermissionDenied() async {
        let mock = MockEventKitExecutionStore()
        mock.eventAuthorization = .denied
        mock.requestEventsGranted = false
        let service = DraftExecutionService(store: mock)

        let outcome = await service.ensurePermissions(for: [.calendarEvent])
        #expect(outcome.deniedKinds.contains(.calendar))

        let draft = sampleDraft()
        do {
            _ = try await service.execute(draft)
            Issue.record("Expected permissionDenied")
        } catch ExecutionFailure.permissionDenied {
            #expect(service.failureReason(for: ExecutionFailure.permissionDenied, actionKind: .calendarEvent) == .permissionDenied)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(mock.saveEventCallCount == 0)
    }

    @Test @MainActor func grantedPermissionSyncsStoreAfterTransition() async {
        let mock = MockEventKitExecutionStore()
        mock.eventAuthorization = .notDetermined
        mock.requestEventsGranted = true
        let service = DraftExecutionService(store: mock)

        _ = await service.ensurePermissions(for: [.calendarEvent])

        #expect(mock.syncCallCount >= 1)
        #expect(mock.reconnectCount == 1)
    }

    @Test @MainActor func executeUsesWritableDefaultCalendar() async throws {
        let mock = MockEventKitExecutionStore()
        let service = DraftExecutionService(store: mock)
        let draft = sampleDraft(actionKind: .calendarEvent)

        let result = try await service.execute(draft)

        #expect(result.nativeIdentifier == "event-default-event")
        #expect(mock.saveEventCallCount == 1)
        #expect(mock.createCalendarCallCount == 0)
    }

    @Test @MainActor func executeCompletesWhenDraftAlreadyMarkedExecuting() async throws {
        let mock = MockEventKitExecutionStore()
        let service = DraftExecutionService(store: mock)
        let draft = sampleDraft(actionKind: .calendarEvent, executionState: .executing)

        let result = try await service.execute(draft)

        #expect(result.nativeIdentifier == "event-default-event")
        #expect(DraftExecutionEligibility.canExecute(draft) == false)
    }

    @Test @MainActor func executeUsesFallbackWhenDefaultNotWritable() async throws {
        let mock = MockEventKitExecutionStore()
        mock.eventEnvironment = EventKitContainerEnvironment(
            defaultCalendarIdentifier: "readonly-default",
            calendars: [
                EventKitCalendarSnapshot(
                    calendarIdentifier: "readonly-default",
                    title: "Default",
                    allowsContentModifications: false,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                ),
                EventKitCalendarSnapshot(
                    calendarIdentifier: "writable-other",
                    title: "Work",
                    allowsContentModifications: true,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ],
            sources: mock.eventEnvironment.sources
        )
        let service = DraftExecutionService(store: mock)
        let result = try await service.execute(sampleDraft(actionKind: .calendarEvent))
        #expect(result.nativeIdentifier == "event-writable-other")
    }

    @Test @MainActor func noWritableCalendarThrowsTypedFailure() async {
        let mock = MockEventKitExecutionStore()
        mock.eventEnvironment = EventKitContainerEnvironment(
            defaultCalendarIdentifier: nil,
            calendars: [],
            sources: []
        )
        let service = DraftExecutionService(store: mock)

        do {
            _ = try await service.execute(sampleDraft(actionKind: .calendarEvent))
            Issue.record("Expected noWritableCalendar")
        } catch ExecutionFailure.noWritableCalendar {
            #expect(service.failureReason(for: ExecutionFailure.noWritableCalendar, actionKind: .calendarEvent) == .noWritableCalendar)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test @MainActor func noWritableReminderListThrowsTypedFailure() async {
        let mock = MockEventKitExecutionStore()
        mock.reminderEnvironment = EventKitContainerEnvironment(
            defaultCalendarIdentifier: nil,
            calendars: [],
            sources: []
        )
        let service = DraftExecutionService(store: mock)

        do {
            _ = try await service.execute(sampleDraft(actionKind: .reminder))
            Issue.record("Expected noWritableReminderList")
        } catch ExecutionFailure.noWritableReminderList {
            #expect(service.failureReason(for: ExecutionFailure.noWritableReminderList, actionKind: .reminder) == .noWritableReminderList)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test @MainActor func reusesExistingWritableZuvanoCalendar() async throws {
        let mock = MockEventKitExecutionStore()
        mock.eventEnvironment = EventKitContainerEnvironment(
            defaultCalendarIdentifier: nil,
            calendars: [
                EventKitCalendarSnapshot(
                    calendarIdentifier: "zuvano-existing",
                    title: EventKitCalendarResolution.fallbackCalendarTitle,
                    allowsContentModifications: true,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ],
            sources: mock.eventEnvironment.sources
        )
        let service = DraftExecutionService(store: mock)
        _ = try await service.execute(sampleDraft(actionKind: .calendarEvent))
        #expect(mock.createCalendarCallCount == 0)
    }

    @Test @MainActor func createsZuvanoCalendarWhenNeeded() async throws {
        let mock = MockEventKitExecutionStore()
        mock.eventEnvironment = EventKitContainerEnvironment(
            defaultCalendarIdentifier: nil,
            calendars: [],
            sources: [
                EventKitSourceSnapshot(
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ]
        )
        let service = DraftExecutionService(store: mock)
        _ = try await service.execute(sampleDraft(actionKind: .calendarEvent))
        #expect(mock.createCalendarCallCount == 1)
    }

    @Test @MainActor func calendarSaveErrorMapsToCalendarSaveFailed() async {
        let mock = MockEventKitExecutionStore()
        mock.saveEventError = NSError(domain: "EKErrorDomain", code: 1)
        let service = DraftExecutionService(store: mock)

        do {
            _ = try await service.execute(sampleDraft(actionKind: .calendarEvent))
            Issue.record("Expected calendarSaveFailed")
        } catch ExecutionFailure.calendarSaveFailed {
            #expect(service.failureReason(for: ExecutionFailure.calendarSaveFailed, actionKind: .calendarEvent) == .calendarSaveFailed)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test @MainActor func reminderSaveErrorMapsToReminderSaveFailed() async {
        let mock = MockEventKitExecutionStore()
        mock.saveReminderError = NSError(domain: "EKErrorDomain", code: 2)
        let service = DraftExecutionService(store: mock)

        do {
            _ = try await service.execute(sampleDraft(actionKind: .reminder))
            Issue.record("Expected reminderSaveFailed")
        } catch ExecutionFailure.reminderSaveFailed {
            #expect(service.failureReason(for: ExecutionFailure.reminderSaveFailed, actionKind: .reminder) == .reminderSaveFailed)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test @MainActor func alreadyInFlightFailureReasonIsNil() {
        let service = DraftExecutionService(store: MockEventKitExecutionStore())
        #expect(service.failureReason(for: ExecutionFailure.alreadyInFlight, actionKind: .calendarEvent) == nil)
    }

    @Test @MainActor func failedDraftRemainsRetryable() async throws {
        let mock = MockEventKitExecutionStore()
        mock.saveEventError = NSError(domain: "EKErrorDomain", code: 9)
        let service = DraftExecutionService(store: mock)
        let draft = sampleDraft(actionKind: .calendarEvent)

        do {
            _ = try await service.execute(draft)
        } catch {
            // expected
        }

        let failed = draft.updating(executionState: .failed)
        #expect(DraftExecutionEligibility.canRetry(failed))

        mock.saveEventError = nil
        let result = try await service.execute(failed)
        #expect(result.nativeIdentifier == "event-default-event")
    }

    @Test func legacyFailureReasonRawValuesStillDecode() async throws {
        let container = try ModelContainer(
            for: IntakeRecord.self, ActionDraftRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ActionStore(modelContainer: container)
        let intake = try await store.createIntake(sourceType: .text, imageData: nil)

        let calendarFailed = ActionDraftSnapshot(
            intakeID: intake.id,
            intentKind: .meeting,
            actionKind: .calendarEvent,
            title: "Legacy",
            sourcePhrase: "phrase",
            confidence: .high,
            confirmationState: .confirmed,
            executionState: .failed,
            executionError: .calendarFailed
        )
        _ = try await store.replaceDrafts(for: intake.id, drafts: [calendarFailed])
        let loaded = try await store.fetchDrafts(for: intake.id)
        #expect(loaded[0].executionError == .calendarFailed)
    }
}
