import EventKit
import Foundation

/// Runs synchronous EventKit save/commit calls off the main actor (same pattern as source refresh).
enum EventKitSaveWorker: Sendable {
    @concurrent
    nonisolated static func saveEvent(
        store: EKEventStore,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarIdentifier: String
    ) async throws -> String {
        try saveEventSynchronously(
            store: store,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            calendarIdentifier: calendarIdentifier
        )
    }

    @concurrent
    nonisolated static func saveReminder(
        store: EKEventStore,
        title: String,
        dueDateComponents: DateComponents?,
        notes: String?,
        calendarIdentifier: String
    ) async throws -> String {
        try saveReminderSynchronously(
            store: store,
            title: title,
            dueDateComponents: dueDateComponents,
            notes: notes,
            calendarIdentifier: calendarIdentifier
        )
    }

    @concurrent
    nonisolated static func saveCalendar(
        store: EKEventStore,
        title: String,
        entityType: EKEntityType,
        sourceIdentifier: String
    ) async throws -> String {
        try saveCalendarSynchronously(
            store: store,
            title: title,
            entityType: entityType,
            sourceIdentifier: sourceIdentifier
        )
    }

    nonisolated private static func saveEventSynchronously(
        store: EKEventStore,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarIdentifier: String
    ) throws -> String {
        guard let calendar = store.calendars(for: .event).first(where: {
            $0.calendarIdentifier == calendarIdentifier
        }) else {
            throw NSError(domain: "ZuvanoEventKit", code: 4)
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes
        event.calendar = calendar
        try store.save(event, span: .thisEvent)

        guard let identifier = event.eventIdentifier else {
            throw NSError(domain: "ZuvanoEventKit", code: 3)
        }
        return identifier
    }

    nonisolated private static func saveReminderSynchronously(
        store: EKEventStore,
        title: String,
        dueDateComponents: DateComponents?,
        notes: String?,
        calendarIdentifier: String
    ) throws -> String {
        guard let calendar = store.calendars(for: .reminder).first(where: {
            $0.calendarIdentifier == calendarIdentifier
        }) else {
            throw NSError(domain: "ZuvanoEventKit", code: 5)
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.dueDateComponents = dueDateComponents
        reminder.notes = notes
        reminder.calendar = calendar
        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    nonisolated private static func saveCalendarSynchronously(
        store: EKEventStore,
        title: String,
        entityType: EKEntityType,
        sourceIdentifier: String
    ) throws -> String {
        guard let source = store.sources.first(where: { $0.sourceIdentifier == sourceIdentifier }) else {
            throw NSError(domain: "ZuvanoEventKit", code: 1)
        }

        let calendar = EKCalendar(for: entityType, eventStore: store)
        calendar.title = title
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)

        guard calendar.allowsContentModifications else {
            throw NSError(domain: "ZuvanoEventKit", code: 2)
        }

        return calendar.calendarIdentifier
    }
}
