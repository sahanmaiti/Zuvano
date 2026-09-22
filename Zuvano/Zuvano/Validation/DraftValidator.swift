import Foundation

enum DraftValidator {
    nonisolated static func validationConcern(for draft: ActionDraftSnapshot) -> DraftValidationConcern {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .needsTitle
        }

        switch draft.actionKind {
        case .calendarEvent:
            guard draft.when?.startDate != nil else {
                return .needsStartTime
            }
            if draft.ambiguous || draft.when?.ambiguous == true {
                return .ambiguousReady
            }
            return .ready

        case .reminder:
            if draft.ambiguous || draft.when?.ambiguous == true {
                return .ambiguousReady
            }
            return .ready
        }
    }

    nonisolated static func canCreate(_ draft: ActionDraftSnapshot) -> Bool {
        guard draft.confirmationState == .pending else { return false }
        switch validationConcern(for: draft) {
        case .ready, .ambiguousReady:
            return true
        case .needsTitle, .needsStartTime:
            return false
        }
    }

    nonisolated static func validationFootnote(for draft: ActionDraftSnapshot) -> String? {
        switch validationConcern(for: draft) {
        case .needsStartTime:
            return "Add a start time to create this event."
        case .needsTitle:
            return "Add a title to create this action."
        case .ambiguousReady:
            if let when = draft.when, let start = when.startDate {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.dateStyle = .none
                let timeStr = formatter.string(from: start)
                return "About \(timeStr), check before creating."
            }
            return "Check details before creating."
        case .ready:
            return nil
        }
    }
}
