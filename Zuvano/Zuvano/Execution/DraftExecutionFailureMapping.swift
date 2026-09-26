import Foundation

enum DraftExecutionFailureMapping {
    nonisolated static func persistableFailureReason(for error: Error, actionKind: ActionKind) -> FailureReason {
        if error is CancellationError {
            return .interrupted
        }

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
            case .invalidDraft:
                return genericFailure(for: actionKind)
            case .alreadyInFlight:
                return .interrupted
            }
        }

        return genericFailure(for: actionKind)
    }

    nonisolated static func genericFailure(for actionKind: ActionKind) -> FailureReason {
        actionKind == .calendarEvent ? .calendarFailed : .reminderFailed
    }
}
