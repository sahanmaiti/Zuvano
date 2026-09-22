import Foundation
import SwiftData

@Model
final class ActionDraftRecord {
    @Attribute(.unique) var id: UUID
    var intakeID: UUID
    var intentKindRaw: String
    var actionKindRaw: String
    var title: String
    var sourcePhrase: String
    var whenRawExpression: String?
    var whenStartDate: Date?
    var whenEndDate: Date?
    var whenAllDay: Bool
    var whenAmbiguous: Bool
    var location: String?
    var person: String?
    var notes: String?
    var confidenceRaw: String
    var ambiguous: Bool
    var confirmationStateRaw: String
    var executionStateRaw: String
    var nativeIdentifier: String?
    var executionErrorRaw: String?
    var createdAt: Date
    var updatedAt: Date

    var intake: IntakeRecord?

    init(
        id: UUID = UUID(),
        intakeID: UUID,
        intentKind: IntentKind,
        actionKind: ActionKind,
        title: String,
        sourcePhrase: String,
        when: ActionDateTime? = nil,
        location: String? = nil,
        person: String? = nil,
        notes: String? = nil,
        confidence: ConfidenceLevel,
        ambiguous: Bool = false,
        confirmationState: ConfirmationState = .pending,
        executionState: ExecutionState = .notStarted,
        nativeIdentifier: String? = nil,
        executionError: FailureReason? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.intakeID = intakeID
        self.intentKindRaw = intentKind.rawValue
        self.actionKindRaw = actionKind.rawValue
        self.title = title
        self.sourcePhrase = sourcePhrase
        self.whenRawExpression = when?.rawExpression
        self.whenStartDate = when?.startDate
        self.whenEndDate = when?.endDate
        self.whenAllDay = when?.allDay ?? false
        self.whenAmbiguous = when?.ambiguous ?? false
        self.location = location
        self.person = person
        self.notes = notes
        self.confidenceRaw = confidence.rawValue
        self.ambiguous = ambiguous
        self.confirmationStateRaw = confirmationState.rawValue
        self.executionStateRaw = executionState.rawValue
        self.nativeIdentifier = nativeIdentifier
        self.executionErrorRaw = executionError?.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var intentKind: IntentKind {
        get { IntentKind(rawValue: intentKindRaw) ?? .task }
        set { intentKindRaw = newValue.rawValue }
    }

    var actionKind: ActionKind {
        get { ActionKind(rawValue: actionKindRaw) ?? .reminder }
        set { actionKindRaw = newValue.rawValue }
    }

    var confidence: ConfidenceLevel {
        get { ConfidenceLevel(rawValue: confidenceRaw) ?? .medium }
        set { confidenceRaw = newValue.rawValue }
    }

    var confirmationState: ConfirmationState {
        get { ConfirmationState(rawValue: confirmationStateRaw) ?? .pending }
        set { confirmationStateRaw = newValue.rawValue }
    }

    var executionState: ExecutionState {
        get { ExecutionState(rawValue: executionStateRaw) ?? .notStarted }
        set { executionStateRaw = newValue.rawValue }
    }

    var executionError: FailureReason? {
        get { executionErrorRaw.flatMap(FailureReason.init(rawValue:)) }
        set { executionErrorRaw = newValue?.rawValue }
    }

    var when: ActionDateTime? {
        get {
            guard let rawExpression = whenRawExpression else { return nil }
            return ActionDateTime(
                rawExpression: rawExpression,
                startDate: whenStartDate,
                endDate: whenEndDate,
                allDay: whenAllDay,
                ambiguous: whenAmbiguous
            )
        }
        set {
            whenRawExpression = newValue?.rawExpression
            whenStartDate = newValue?.startDate
            whenEndDate = newValue?.endDate
            whenAllDay = newValue?.allDay ?? false
            whenAmbiguous = newValue?.ambiguous ?? false
        }
    }

    func apply(snapshot: ActionDraftSnapshot) {
        title = snapshot.title
        intentKind = snapshot.intentKind
        actionKind = snapshot.actionKind
        sourcePhrase = snapshot.sourcePhrase
        when = snapshot.when
        location = snapshot.location
        person = snapshot.person
        notes = snapshot.notes
        confidence = snapshot.confidence
        ambiguous = snapshot.ambiguous
        confirmationState = snapshot.confirmationState
        executionState = snapshot.executionState
        nativeIdentifier = snapshot.nativeIdentifier
        executionError = snapshot.executionError
        updatedAt = .now
    }

    nonisolated func snapshot() -> ActionDraftSnapshot {
        ActionDraftSnapshot(
            id: id,
            intakeID: intakeID,
            intentKind: intentKind,
            actionKind: actionKind,
            title: title,
            sourcePhrase: sourcePhrase,
            when: when,
            location: location,
            person: person,
            notes: notes,
            confidence: confidence,
            ambiguous: ambiguous,
            confirmationState: confirmationState,
            executionState: executionState,
            nativeIdentifier: nativeIdentifier,
            executionError: executionError,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    nonisolated static func from(snapshot: ActionDraftSnapshot) -> ActionDraftRecord {
        ActionDraftRecord(
            id: snapshot.id,
            intakeID: snapshot.intakeID,
            intentKind: snapshot.intentKind,
            actionKind: snapshot.actionKind,
            title: snapshot.title,
            sourcePhrase: snapshot.sourcePhrase,
            when: snapshot.when,
            location: snapshot.location,
            person: snapshot.person,
            notes: snapshot.notes,
            confidence: snapshot.confidence,
            ambiguous: snapshot.ambiguous,
            confirmationState: snapshot.confirmationState,
            executionState: snapshot.executionState,
            nativeIdentifier: snapshot.nativeIdentifier,
            executionError: snapshot.executionError,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        )
    }
}
