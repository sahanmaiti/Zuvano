import Foundation
import Testing
@testable import Zuvano

struct DraftExecutionFailureMappingTests {
    @Test func permissionDeniedMaps() {
        let reason = DraftExecutionFailureMapping.persistableFailureReason(
            for: ExecutionFailure.permissionDenied,
            actionKind: .calendarEvent
        )
        #expect(reason == .permissionDenied)
    }

    @Test func invalidDraftMapsToGenericCalendarFailure() {
        let reason = DraftExecutionFailureMapping.persistableFailureReason(
            for: ExecutionFailure.invalidDraft,
            actionKind: .calendarEvent
        )
        #expect(reason == .calendarFailed)
    }

    @Test func alreadyInFlightMapsToInterrupted() {
        let reason = DraftExecutionFailureMapping.persistableFailureReason(
            for: ExecutionFailure.alreadyInFlight,
            actionKind: .reminder
        )
        #expect(reason == .interrupted)
    }

    @Test func cancellationMapsToInterrupted() {
        let reason = DraftExecutionFailureMapping.persistableFailureReason(
            for: CancellationError(),
            actionKind: .calendarEvent
        )
        #expect(reason == .interrupted)
    }

    @Test func unknownErrorMapsToGenericFailure() {
        struct Sample: Error {}
        let reason = DraftExecutionFailureMapping.persistableFailureReason(
            for: Sample(),
            actionKind: .reminder
        )
        #expect(reason == .reminderFailed)
    }
}
