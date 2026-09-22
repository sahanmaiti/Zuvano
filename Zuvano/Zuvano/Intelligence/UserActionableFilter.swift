import Foundation

/// Orchestrator rule from Data Model §8. Not persisted; applied after understanding.
enum UserActionableFilter {
    nonisolated static func filter(_ intents: [Intent]) -> [Intent] {
        intents.filter(isUserActionable)
    }

    nonisolated static func isUserActionable(_ intent: Intent) -> Bool {
        guard intent.attribution == .userAction else { return false }

        // MVP does not draft follow-up intents (product SHOULD, not MUST).
        if intent.kind == .followUp { return false }

        return true
    }
}
