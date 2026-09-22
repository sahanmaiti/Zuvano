import Foundation
import Testing
@testable import Zuvano

struct DraftValidatorTests {
    @Test func calendarWithoutStartIsBlocked() {
        let draft = ActionDraftSnapshot(
            intakeID: UUID(),
            intentKind: .meeting,
            actionKind: .calendarEvent,
            title: "Meeting",
            sourcePhrase: "Let's meet.",
            confidence: .high
        )

        #expect(DraftValidator.canCreate(draft) == false)
        #expect(DraftValidator.validationConcern(for: draft) == .needsStartTime)
    }

    @Test func reminderWithoutDueIsAllowed() {
        let draft = ActionDraftSnapshot(
            intakeID: UUID(),
            intentKind: .task,
            actionKind: .reminder,
            title: "Bring files",
            sourcePhrase: "Don't forget to bring the project files.",
            confidence: .medium
        )

        #expect(DraftValidator.canCreate(draft))
        #expect(DraftValidator.validationConcern(for: draft) == .ready)
    }

    @Test func ambiguousCalendarIsAllowed() {
        let draft = ActionDraftSnapshot(
            intakeID: UUID(),
            intentKind: .meeting,
            actionKind: .calendarEvent,
            title: "Meeting",
            sourcePhrase: "Let's meet around 7.",
            when: ActionDateTime(rawExpression: "around 7", startDate: .now, ambiguous: true),
            confidence: .high,
            ambiguous: true
        )

        #expect(DraftValidator.canCreate(draft))
        #expect(DraftValidator.validationConcern(for: draft) == .ambiguousReady)
    }

    @Test func emptyTitleIsBlocked() {
        let draft = ActionDraftSnapshot(
            intakeID: UUID(),
            intentKind: .reminder,
            actionKind: .reminder,
            title: "   ",
            sourcePhrase: "Remind me.",
            confidence: .medium
        )

        #expect(DraftValidator.canCreate(draft) == false)
        #expect(DraftValidator.validationConcern(for: draft) == .needsTitle)
    }

    @Test func confirmedDraftCannotBeCreatedAgain() {
        let draft = ActionDraftSnapshot(
            intakeID: UUID(),
            intentKind: .reminder,
            actionKind: .reminder,
            title: "Call Arjun",
            sourcePhrase: "Remind me.",
            confidence: .high,
            confirmationState: .confirmed
        )

        #expect(DraftValidator.canCreate(draft) == false)
    }
}
