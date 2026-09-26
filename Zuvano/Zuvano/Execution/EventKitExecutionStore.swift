import EventKit
import Foundation
import OSLog

/// `refreshSourcesIfNecessary()` is synchronous and waits on the calendar daemon.
/// Calling it on the main actor deadlocks, because EventKit delivers that reply on the main thread.
enum EventKitSourceRefresh: Sendable {
    @concurrent
    nonisolated static func refresh(_ store: EKEventStore) async {
        store.refreshSourcesIfNecessary()
    }
}

struct EventKitContainerEnvironment: Sendable {
    nonisolated let defaultCalendarIdentifier: String?
    nonisolated let calendars: [EventKitCalendarSnapshot]
    nonisolated let sources: [EventKitSourceSnapshot]

    nonisolated init(
        defaultCalendarIdentifier: String?,
        calendars: [EventKitCalendarSnapshot],
        sources: [EventKitSourceSnapshot]
    ) {
        self.defaultCalendarIdentifier = defaultCalendarIdentifier
        self.calendars = calendars
        self.sources = sources
    }
}

enum EventKitExecutionDiagnostics {
    private nonisolated(unsafe) static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.zuvano.app",
        category: "DraftExecution"
    )

    nonisolated static func boundary(_ name: String, draftID: UUID? = nil, entity: String? = nil) {
        if let draftID {
            logger.debug("boundary \(name, privacy: .public) draft=\(draftID.uuidString, privacy: .private) entity=\(entity ?? "-", privacy: .public)")
        } else {
            logger.debug("boundary \(name, privacy: .public) entity=\(entity ?? "-", privacy: .public)")
        }
    }
}

@MainActor
protocol EventKitExecutionStore: AnyObject {
    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus
    func requestFullAccessToEvents() async throws -> Bool
    func requestFullAccessToReminders() async throws -> Bool
    func syncStoreAfterAuthorizationIfNeeded() async
    func refreshSourcesIfNecessary() async
    func containerEnvironment(for entityType: EKEntityType) -> EventKitContainerEnvironment
    func createCalendar(
        title: String,
        entityType: EKEntityType,
        sourceIdentifier: String
    ) async throws -> String
    func saveEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarIdentifier: String
    ) async throws -> String
    func saveReminder(
        title: String,
        dueDateComponents: DateComponents?,
        notes: String?,
        calendarIdentifier: String
    ) async throws -> String
}

@MainActor
final class LiveEventKitExecutionStore: EventKitExecutionStore {
    private var eventStore: EKEventStore
    private var preparedEventAuthorization: EKAuthorizationStatus
    private var preparedReminderAuthorization: EKAuthorizationStatus

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        self.preparedEventAuthorization = EKEventStore.authorizationStatus(for: .event)
        self.preparedReminderAuthorization = EKEventStore.authorizationStatus(for: .reminder)
    }

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: entityType)
    }

    func requestFullAccessToEvents() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }

    func requestFullAccessToReminders() async throws -> Bool {
        try await eventStore.requestFullAccessToReminders()
    }

    func syncStoreAfterAuthorizationIfNeeded() async {
        EventKitExecutionDiagnostics.boundary("syncStore.begin")
        let currentEvent = EKEventStore.authorizationStatus(for: .event)
        let currentReminder = EKEventStore.authorizationStatus(for: .reminder)

        let eventTransitionToGranted = currentEvent == .fullAccess && preparedEventAuthorization != .fullAccess
        let reminderTransitionToGranted = currentReminder == .fullAccess && preparedReminderAuthorization != .fullAccess

        preparedEventAuthorization = currentEvent
        preparedReminderAuthorization = currentReminder

        if eventTransitionToGranted || reminderTransitionToGranted {
            eventStore = EKEventStore()
            await refreshSourcesIfNecessary()
        }
        EventKitExecutionDiagnostics.boundary("syncStore.end")
    }

    func refreshSourcesIfNecessary() async {
        EventKitExecutionDiagnostics.boundary("refreshSources.begin")
        nonisolated(unsafe) let store = eventStore
        await EventKitSourceRefresh.refresh(store)
        EventKitExecutionDiagnostics.boundary("refreshSources.end")
    }

    func containerEnvironment(for entityType: EKEntityType) -> EventKitContainerEnvironment {
        let defaultID: String?
        switch entityType {
        case .event:
            defaultID = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        case .reminder:
            defaultID = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
        default:
            defaultID = nil
        }

        let calendars = eventStore.calendars(for: entityType).map { calendar in
            EventKitCalendarSnapshot(
                calendarIdentifier: calendar.calendarIdentifier,
                title: calendar.title,
                allowsContentModifications: calendar.allowsContentModifications,
                sourceIdentifier: calendar.source.sourceIdentifier,
                sourceTypeRawValue: calendar.source.sourceType.rawValue
            )
        }

        let sources = eventStore.sources.map { source in
            EventKitSourceSnapshot(
                sourceIdentifier: source.sourceIdentifier,
                sourceTypeRawValue: source.sourceType.rawValue
            )
        }

        return EventKitContainerEnvironment(
            defaultCalendarIdentifier: defaultID,
            calendars: calendars,
            sources: sources
        )
    }

    func createCalendar(
        title: String,
        entityType: EKEntityType,
        sourceIdentifier: String
    ) async throws -> String {
        EventKitExecutionDiagnostics.boundary("createCalendar.begin", entity: entityType == .event ? "event" : "reminder")
        nonisolated(unsafe) let store = eventStore
        let identifier = try await EventKitSaveWorker.saveCalendar(
            store: store,
            title: title,
            entityType: entityType,
            sourceIdentifier: sourceIdentifier
        )
        EventKitExecutionDiagnostics.boundary("createCalendar.end", entity: entityType == .event ? "event" : "reminder")
        return identifier
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
        EventKitExecutionDiagnostics.boundary("saveEvent.begin", entity: "event")
        nonisolated(unsafe) let store = eventStore
        let identifier = try await EventKitSaveWorker.saveEvent(
            store: store,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            calendarIdentifier: calendarIdentifier
        )
        EventKitExecutionDiagnostics.boundary("saveEvent.end", entity: "event")
        return identifier
    }

    func saveReminder(
        title: String,
        dueDateComponents: DateComponents?,
        notes: String?,
        calendarIdentifier: String
    ) async throws -> String {
        EventKitExecutionDiagnostics.boundary("saveReminder.begin", entity: "reminder")
        nonisolated(unsafe) let store = eventStore
        let identifier = try await EventKitSaveWorker.saveReminder(
            store: store,
            title: title,
            dueDateComponents: dueDateComponents,
            notes: notes,
            calendarIdentifier: calendarIdentifier
        )
        EventKitExecutionDiagnostics.boundary("saveReminder.end", entity: "reminder")
        return identifier
    }
}
