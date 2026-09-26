import EventKit
import Foundation
import OSLog

@MainActor
final class DraftExecutionService {
    private let store: EventKitExecutionStore
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.zuvano.app",
        category: "DraftExecution"
    )
    private var inFlightDraftIDs: Set<UUID> = []
    private static let defaultEventDuration: TimeInterval = 3600

    init() {
        self.store = LiveEventKitExecutionStore()
    }

    init(store: EventKitExecutionStore) {
        self.store = store
    }

    init(eventStore: EKEventStore) {
        self.store = LiveEventKitExecutionStore(eventStore: eventStore)
    }

    func ensurePermissions(for actionKinds: Set<ActionKind>) async -> PermissionOutcome {
        var denied = Set<PermissionKind>()

        if actionKinds.contains(.calendarEvent) {
            if !calendarAccessGranted() {
                do {
                    let granted = try await store.requestFullAccessToEvents()
                    if !granted {
                        logger.error("Calendar access request returned granted=false (status: \(self.store.authorizationStatus(for: .event).rawValue))")
                        denied.insert(.calendar)
                    }
                } catch {
                    let nsError = error as NSError
                    logger.error("Calendar access request threw: domain=\(nsError.domain, privacy: .public) code=\(nsError.code) userInfo=\(String(describing: nsError.userInfo), privacy: .private)")
                    denied.insert(.calendar)
                }
            }
        }

        if actionKinds.contains(.reminder) {
            if !remindersAccessGranted() {
                do {
                    let granted = try await store.requestFullAccessToReminders()
                    if !granted {
                        logger.error("Reminders access request returned granted=false (status: \(self.store.authorizationStatus(for: .reminder).rawValue))")
                        denied.insert(.reminders)
                    }
                } catch {
                    let nsError = error as NSError
                    logger.error("Reminders access request threw: domain=\(nsError.domain, privacy: .public) code=\(nsError.code) userInfo=\(String(describing: nsError.userInfo), privacy: .private)")
                    denied.insert(.reminders)
                }
            }
        }

        await store.syncStoreAfterAuthorizationIfNeeded()
        return PermissionOutcome(deniedKinds: denied)
    }

    func currentDeniedKinds(for actionKinds: Set<ActionKind>) -> Set<PermissionKind> {
        var denied = Set<PermissionKind>()
        if actionKinds.contains(.calendarEvent), !calendarAccessGranted() {
            denied.insert(.calendar)
        }
        if actionKinds.contains(.reminder), !remindersAccessGranted() {
            denied.insert(.reminders)
        }
        return denied
    }

    func persistableFailureReason(for error: Error, actionKind: ActionKind) -> FailureReason {
        DraftExecutionFailureMapping.persistableFailureReason(for: error, actionKind: actionKind)
    }

    func execute(_ draft: ActionDraftSnapshot) async throws -> ExecutionResult {
        guard isRunnableExecutionState(draft) else {
            throw ExecutionFailure.invalidDraft
        }
        guard passesExecutionValidation(draft) else {
            throw ExecutionFailure.invalidDraft
        }

        guard !inFlightDraftIDs.contains(draft.id) else {
            throw ExecutionFailure.alreadyInFlight
        }

        inFlightDraftIDs.insert(draft.id)
        defer { inFlightDraftIDs.remove(draft.id) }

        EventKitExecutionDiagnostics.boundary("execute.begin", draftID: draft.id, entity: draft.actionKind == .calendarEvent ? "event" : "reminder")
        defer { EventKitExecutionDiagnostics.boundary("execute.end", draftID: draft.id, entity: draft.actionKind == .calendarEvent ? "event" : "reminder") }

        try Task.checkCancellation()

        EventKitExecutionDiagnostics.boundary("syncStore.before", draftID: draft.id)
        await store.syncStoreAfterAuthorizationIfNeeded()
        EventKitExecutionDiagnostics.boundary("syncStore.after", draftID: draft.id)

        switch draft.actionKind {
        case .calendarEvent:
            guard calendarAccessGranted() else { throw ExecutionFailure.permissionDenied }
            return try await createCalendarEvent(from: draft)
        case .reminder:
            guard remindersAccessGranted() else { throw ExecutionFailure.permissionDenied }
            return try await createReminder(from: draft)
        }
    }

    func failureReason(for error: Error, actionKind: ActionKind) -> FailureReason? {
        if let failure = error as? ExecutionFailure {
            switch failure {
            case .permissionDenied:
                return .permissionDenied
            case .calendarFailed:
                return .calendarFailed
            case .reminderFailed:
                return .reminderFailed
            case .noWritableCalendar:
                return .noWritableCalendar
            case .noWritableReminderList:
                return .noWritableReminderList
            case .calendarSaveFailed:
                return .calendarSaveFailed
            case .reminderSaveFailed:
                return .reminderSaveFailed
            case .invalidDraft, .alreadyInFlight:
                return nil
            }
        }
        return actionKind == .calendarEvent ? .calendarFailed : .reminderFailed
    }

    nonisolated static func permissionKind(for actionKind: ActionKind) -> PermissionKind {
        switch actionKind {
        case .calendarEvent: .calendar
        case .reminder: .reminders
        }
    }

    /// Coordinator may persist `.executing` before calling `execute`; UI eligibility still treats `.executing` as non-runnable.
    private func isRunnableExecutionState(_ draft: ActionDraftSnapshot) -> Bool {
        guard draft.confirmationState == .confirmed, draft.nativeIdentifier == nil else { return false }
        switch draft.executionState {
        case .notStarted, .failed, .executing:
            return true
        case .executed:
            return false
        }
    }

    private func passesExecutionValidation(_ draft: ActionDraftSnapshot) -> Bool {
        switch DraftValidator.validationConcern(for: draft) {
        case .ready, .ambiguousReady:
            return true
        case .needsTitle, .needsStartTime:
            return false
        }
    }

    private func calendarAccessGranted() -> Bool {
        store.authorizationStatus(for: .event) == .fullAccess
    }

    private func remindersAccessGranted() -> Bool {
        store.authorizationStatus(for: .reminder) == .fullAccess
    }

    private func resolvedCalendar(for entityType: EKEntityType, draftID: UUID) async throws -> String {
        EventKitExecutionDiagnostics.boundary("refreshSources.before", draftID: draftID, entity: entityType == .event ? "event" : "reminder")
        await store.refreshSourcesIfNecessary()
        EventKitExecutionDiagnostics.boundary("refreshSources.after", draftID: draftID, entity: entityType == .event ? "event" : "reminder")

        let environment = store.containerEnvironment(for: entityType)

        EventKitExecutionDiagnostics.boundary("resolution.begin", draftID: draftID, entity: entityType == .event ? "event" : "reminder")
        defer { EventKitExecutionDiagnostics.boundary("resolution.end", draftID: draftID, entity: entityType == .event ? "event" : "reminder") }

        let decision = EventKitCalendarResolution.writableContainerDecision(
            entityType: entityType,
            defaultCalendarIdentifier: environment.defaultCalendarIdentifier,
            calendars: environment.calendars,
            sources: environment.sources
        )

        switch decision {
        case .useCalendar(let identifier):
            guard environment.calendars.contains(where: {
                $0.calendarIdentifier == identifier && $0.allowsContentModifications
            }) else {
                logNoWritableContainer(entityType: entityType, environment: environment)
                throw noWritableFailure(for: entityType)
            }
            return identifier

        case .attemptCreate(let sourceIdentifiers):
            for sourceIdentifier in sourceIdentifiers {
                do {
                    let identifier = try await store.createCalendar(
                        title: EventKitCalendarResolution.fallbackCalendarTitle,
                        entityType: entityType,
                        sourceIdentifier: sourceIdentifier
                    )
                    logger.info("Created fallback calendar container (entityType=\(entityType == .event ? "event" : "reminder", privacy: .public))")
                    return identifier
                } catch {
                    let nsError = error as NSError
                    logger.error("saveCalendar failed (entityType=\(entityType == .event ? "event" : "reminder", privacy: .public), sourceIdentifier=\(sourceIdentifier, privacy: .private)): domain=\(nsError.domain, privacy: .public) code=\(nsError.code) userInfo=\(String(describing: nsError.userInfo), privacy: .private)")
                }
            }
            logNoWritableContainer(entityType: entityType, environment: environment)
            throw noWritableFailure(for: entityType)

        case .noWritableContainer:
            logNoWritableContainer(entityType: entityType, environment: environment)
            throw noWritableFailure(for: entityType)
        }
    }

    private func noWritableFailure(for entityType: EKEntityType) -> ExecutionFailure {
        entityType == .event ? .noWritableCalendar : .noWritableReminderList
    }

    private func logNoWritableContainer(entityType: EKEntityType, environment: EventKitContainerEnvironment) {
        let authStatus = store.authorizationStatus(for: entityType).rawValue
        logger.error("""
        No writable container (entityType=\(entityType == .event ? "event" : "reminder", privacy: .public), authStatus=\(authStatus), sources=\(environment.sources.count), calendars=\(environment.calendars.count), defaultExists=\(environment.defaultCalendarIdentifier != nil))
        """)
        for calendar in environment.calendars {
            logger.error("Candidate calendar title=\(calendar.title, privacy: .private) id=\(calendar.calendarIdentifier, privacy: .private) sourceType=\(calendar.sourceTypeRawValue) sourceId=\(calendar.sourceIdentifier, privacy: .private) writable=\(calendar.allowsContentModifications)")
        }
    }

    private func createCalendarEvent(from draft: ActionDraftSnapshot) async throws -> ExecutionResult {
        guard let startDate = draft.when?.startDate else {
            throw ExecutionFailure.invalidDraft
        }

        let calendarIdentifier = try await resolvedCalendar(for: .event, draftID: draft.id)
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let endDate = draft.when?.endDate ?? startDate.addingTimeInterval(Self.defaultEventDuration)

        var location: String?
        if let raw = draft.location?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            location = raw
        }

        var noteParts: [String] = []
        if let notes = draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            noteParts.append(notes)
        }
        if let person = draft.person?.trimmingCharacters(in: .whitespacesAndNewlines), !person.isEmpty {
            noteParts.append("With: \(person)")
        }
        let notes = noteParts.isEmpty ? nil : noteParts.joined(separator: "\n")

        do {
            let identifier = try await store.saveEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: draft.when?.allDay ?? false,
                location: location,
                notes: notes,
                calendarIdentifier: calendarIdentifier
            )
            return ExecutionResult(nativeIdentifier: identifier)
        } catch {
            let nsError = error as NSError
            logger.error("Calendar save failed. domain=\(nsError.domain, privacy: .public) code=\(nsError.code) userInfo=\(String(describing: nsError.userInfo), privacy: .private)")
            throw ExecutionFailure.calendarSaveFailed
        }
    }

    private func createReminder(from draft: ActionDraftSnapshot) async throws -> ExecutionResult {
        let calendarIdentifier = try await resolvedCalendar(for: .reminder, draftID: draft.id)
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

        var dueDateComponents: DateComponents?
        if let startDate = draft.when?.startDate {
            dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: startDate
            )
        }

        var noteParts: [String] = []
        if let notes = draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            noteParts.append(notes)
        }
        if let person = draft.person?.trimmingCharacters(in: .whitespacesAndNewlines), !person.isEmpty {
            noteParts.append("With: \(person)")
        }
        let notes = noteParts.isEmpty ? nil : noteParts.joined(separator: "\n")

        do {
            let identifier = try await store.saveReminder(
                title: title,
                dueDateComponents: dueDateComponents,
                notes: notes,
                calendarIdentifier: calendarIdentifier
            )
            return ExecutionResult(nativeIdentifier: identifier)
        } catch {
            let nsError = error as NSError
            logger.error("Reminder save failed. domain=\(nsError.domain, privacy: .public) code=\(nsError.code) userInfo=\(String(describing: nsError.userInfo), privacy: .private)")
            throw ExecutionFailure.reminderSaveFailed
        }
    }
}
