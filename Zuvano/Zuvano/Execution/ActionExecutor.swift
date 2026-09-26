import Foundation

struct ExecutionResult: Sendable, Equatable {
    nonisolated let nativeIdentifier: String

    nonisolated init(nativeIdentifier: String) {
        self.nativeIdentifier = nativeIdentifier
    }
}

enum ExecutionFailure: Error, Sendable, Equatable {
    case permissionDenied
    case calendarFailed
    case reminderFailed
    case noWritableCalendar
    case noWritableReminderList
    case calendarSaveFailed
    case reminderSaveFailed
    case invalidDraft
    case alreadyInFlight
}

protocol ActionExecutor: Sendable {
    func execute(_ draft: ActionDraftSnapshot) async throws -> ExecutionResult
}

enum DraftExecutionEligibility {
    nonisolated static func canExecute(_ draft: ActionDraftSnapshot) -> Bool {
        guard draft.confirmationState == .confirmed else { return false }
        guard draft.nativeIdentifier == nil else { return false }
        guard draft.executionState == .notStarted || draft.executionState == .failed else {
            return false
        }

        switch DraftValidator.validationConcern(for: draft) {
        case .ready, .ambiguousReady:
            return true
        case .needsTitle, .needsStartTime:
            return false
        }
    }

    nonisolated static func canRetry(_ draft: ActionDraftSnapshot) -> Bool {
        draft.confirmationState == .confirmed
            && draft.executionState == .failed
            && draft.nativeIdentifier == nil
            && canExecute(draft)
    }

    nonisolated static func isTerminal(_ draft: ActionDraftSnapshot, failureDismissed: Bool = false) -> Bool {
        switch draft.confirmationState {
        case .rejected:
            return true
        case .pending:
            return false
        case .confirmed:
            switch draft.executionState {
            case .executed:
                return true
            case .failed:
                return failureDismissed
            case .notStarted, .executing:
                return false
            }
        }
    }
}
