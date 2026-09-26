import SwiftUI

struct DraftRowView: View {
    let draft: ActionDraftSnapshot
    let isPermissionDenied: Bool
    let isFailureDismissed: Bool
    let onEdit: () -> Void
    let onCreate: () -> Void
    let onSkip: () -> Void
    let onRestore: () -> Void
    let onRetry: () -> Void
    let onDismissFailure: () -> Void
    let onOpenSettings: () -> Void

    private var validationConcern: DraftValidationConcern {
        DraftValidator.validationConcern(for: draft)
    }

    private var isSkipped: Bool {
        draft.confirmationState == .rejected
    }

    private var isExecuting: Bool {
        draft.confirmationState == .confirmed && draft.executionState == .executing
    }

    private var isExecuted: Bool {
        draft.confirmationState == .confirmed && draft.executionState == .executed
    }

    private var isFailed: Bool {
        draft.confirmationState == .confirmed && draft.executionState == .failed
    }

    private var isWaitingForAccess: Bool {
        draft.confirmationState == .confirmed
            && draft.executionState == .notStarted
            && isPermissionDenied
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ZuvanoSpacing.footnoteTop) {
            HStack(spacing: ZuvanoSpacing.footnoteTop) {
                Image(systemName: actionSymbol)
                    .foregroundStyle(rowForeground)
                    .accessibilityHidden(true)

                Text(draft.title)
                    .font(.headline)
                    .foregroundStyle(rowForeground)

                Spacer()

                executionStatusAccessory
            }

            if let whenLine = whenDisplayLine {
                Text(whenLine)
                    .zuvanoMetaStyle()
            }

            if let location = draft.location {
                Text(location)
                    .zuvanoMetaStyle()
            }

            if let person = draft.person {
                Text(person)
                    .zuvanoMetaStyle()
            }

            if !isExecuted {
                Text("\"\(draft.sourcePhrase)\"")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            if let footnote = validationFootnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(footnoteColor)
            }

            if isSkipped {
                HStack {
                    Text("Skipped")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore", action: onRestore)
                        .font(.footnote)
                        .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                }
            }

            if isWaitingForAccess {
                HStack {
                    Text(waitingForAccessCopy)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Try Again", action: onCreate)
                        .font(.footnote)
                        .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                    Button("Open Settings", action: onOpenSettings)
                        .font(.footnote)
                        .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                }
            }

            if isFailed {
                VStack(alignment: .leading, spacing: ZuvanoSpacing.footnoteTop) {
                    HStack {
                        Text(isFailureDismissed ? "Couldn't create." : failureCopy)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !isFailureDismissed {
                            Button("Retry", action: onRetry)
                                .font(.footnote)
                                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                            Button("Dismiss", action: onDismissFailure)
                                .font(.footnote)
                                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                        }
                    }
                    if !isFailureDismissed, draft.executionError == .permissionDenied {
                        Button("Open Settings", action: onOpenSettings)
                            .font(.footnote)
                            .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                    }
                }
            }
        }
        .padding(.vertical, ZuvanoSpacing.footnoteTop)
        .opacity(isSkipped ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExecuted && !isExecuting {
                onEdit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(draft.sourcePhrase)
        .accessibilityAction(named: "Edit", onEdit)
        .modifier(DraftRowAccessibilityActions(
            draft: draft,
            isSkipped: isSkipped,
            isExecuted: isExecuted,
            isExecuting: isExecuting,
            onCreate: onCreate,
            onSkip: onSkip,
            onRestore: onRestore,
            onRetry: onRetry,
            onDismissFailure: onDismissFailure
        ))
        .accessibilityHint(createAccessibilityHint)
    }

    @ViewBuilder
    private var executionStatusAccessory: some View {
        if isExecuting {
            HStack(spacing: 6) {
                ProgressView()
                Text("Creating…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Creating")
        } else if isExecuted {
            Label("Created", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        }
    }

    private var rowForeground: Color {
        if isSkipped {
            return ZuvanoColors.secondaryText
        }
        if isExecuted {
            return ZuvanoColors.primaryText
        }
        return ZuvanoColors.primaryText
    }

    private var actionKindLabel: String {
        switch draft.actionKind {
        case .calendarEvent: "Calendar event"
        case .reminder: "Reminder"
        }
    }

    private var actionSymbol: String {
        switch draft.actionKind {
        case .calendarEvent: isExecuted ? "calendar.badge.checkmark" : "calendar"
        case .reminder: isExecuted ? "checkmark.circle" : "checklist"
        }
    }

    private var whenDisplayLine: String? {
        guard let when = draft.when, let start = when.startDate else {
            if draft.actionKind == .calendarEvent {
                return nil
            }
            if let raw = draft.when?.rawExpression {
                return raw
            }
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = when.allDay ? .none : .short

        let formatted = formatter.string(from: start)
        if when.ambiguous || draft.ambiguous {
            return "About \(formatted)"
        }
        return formatted
    }

    private var validationFootnote: String? {
        if isSkipped || isExecuted || isExecuting || isWaitingForAccess || isFailed {
            return nil
        }
        return DraftValidator.validationFootnote(for: draft)
    }

    private var footnoteColor: Color {
        switch validationConcern {
        case .needsStartTime, .needsTitle:
            return .red
        default:
            return .secondary
        }
    }

    private var waitingForAccessCopy: String {
        switch draft.actionKind {
        case .calendarEvent:
            return "Calendar access is off."
        case .reminder:
            return "Reminders access is off."
        }
    }

    private var failureCopy: String {
        if draft.executionError == .interrupted {
            return "Creation was interrupted. Retry when you're ready."
        }

        switch draft.executionError {
        case .permissionDenied:
            switch draft.actionKind {
            case .calendarEvent:
                return "Calendar access is off."
            case .reminder:
                return "Reminders access is off."
            }
        case .noWritableCalendar:
            return "No writable calendar is available. Add or enable a calendar, then retry."
        case .noWritableReminderList:
            return "No writable reminder list is available. Add or enable a list, then retry."
        case .calendarSaveFailed, .calendarFailed:
            return "Calendar could not save this event. Check Calendar and retry."
        case .reminderSaveFailed, .reminderFailed:
            return "Reminders could not save this item. Check Reminders and retry."
        case .invalidInput, .unsupportedInput, .ocrFailed, .aiUnavailable, .aiExtractionFailed,
             .malformedOutput, .draftGenerationFailed, .persistenceFailed, .cancelled, .interrupted, .none:
            break
        }

        switch draft.actionKind {
        case .calendarEvent:
            return "Calendar could not save this event. Check Calendar and retry."
        case .reminder:
            return "Reminders could not save this item. Check Reminders and retry."
        }
    }

    private var accessibilityLabel: String {
        var components = [actionKindLabel, draft.title]
        if let whenLine = whenDisplayLine {
            components.append(whenLine)
        }
        if let footnote = validationFootnote {
            components.append(footnote)
        }
        if isSkipped {
            components.append("Skipped")
        } else if isExecuting {
            components.append("Creating")
        } else if isExecuted {
            components.append("Created")
        } else if isWaitingForAccess {
            components.append("Waiting for access")
        } else if isFailed {
            components.append(failureCopy)
        } else {
            components.append("Proposal")
        }
        return components.joined(separator: ". ")
    }

    private var createAccessibilityHint: String {
        if DraftValidator.canCreate(draft) { return "" }
        return DraftValidator.validationFootnote(for: draft) ?? "Cannot create this action yet."
    }
}

private struct DraftRowAccessibilityActions: ViewModifier {
    let draft: ActionDraftSnapshot
    let isSkipped: Bool
    let isExecuted: Bool
    let isExecuting: Bool
    let onCreate: () -> Void
    let onSkip: () -> Void
    let onRestore: () -> Void
    let onRetry: () -> Void
    let onDismissFailure: () -> Void

    private var canSkipOrRestore: Bool {
        if isSkipped { return true }
        return draft.confirmationState == .pending
            || (draft.confirmationState == .confirmed && draft.executionState == .notStarted)
    }

    func body(content: Content) -> some View {
        content
            .accessibilityActionIf(canSkipOrRestore && isSkipped, named: "Restore", onRestore)
            .accessibilityActionIf(canSkipOrRestore && !isSkipped, named: "Skip", onSkip)
            .accessibilityActionIf(
                DraftValidator.canCreate(draft) && !isExecuted && !isExecuting && !isSkipped,
                named: "Create",
                onCreate
            )
            .accessibilityActionIf(DraftExecutionEligibility.canRetry(draft), named: "Retry", onRetry)
            .accessibilityActionIf(
                draft.confirmationState == .confirmed && draft.executionState == .failed,
                named: "Dismiss failure",
                onDismissFailure
            )
    }
}

private extension View {
    @ViewBuilder
    func accessibilityActionIf(
        _ condition: Bool,
        named name: String,
        _ action: @escaping () -> Void
    ) -> some View {
        if condition {
            self.accessibilityAction(named: name, action)
        } else {
            self
        }
    }
}
