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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: actionSymbol)
                .font(.title2)
                .foregroundStyle(rowSymbolColor)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(draft.title)
                        .font(.headline)
                        .foregroundStyle(rowForeground)

                    Spacer(minLength: 8)

                    executionStatusAccessory
                }

                if let whenLine = whenDisplayLine {
                    Label(whenLine, systemImage: "clock")
                        .zuvanoLeadingMetaStyle()
                        .labelStyle(.titleAndIcon)
                }

                if let location = draft.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .zuvanoLeadingMetaStyle()
                        .labelStyle(.titleAndIcon)
                }

                if let person = draft.person {
                    Label(person, systemImage: "person")
                        .zuvanoLeadingMetaStyle()
                        .labelStyle(.titleAndIcon)
                }

                if showsSourcePhrase {
                    Text("\"\(draft.sourcePhrase)\"")
                        .font(.footnote)
                        .foregroundStyle(ZuvanoColors.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let footnote = validationFootnote {
                    Label(footnote, systemImage: validationFootnoteSymbol)
                        .font(.footnote)
                        .foregroundStyle(footnoteColor)
                        .labelStyle(.titleAndIcon)
                }

                if isSkipped {
                    HStack {
                        Text("Skipped")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore", action: onRestore)
                            .font(.footnote.weight(.medium))
                            .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                    }
                }

                if isWaitingForAccess {
                    HStack {
                        Text("Waiting for access")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings", action: onOpenSettings)
                            .font(.footnote.weight(.medium))
                            .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                    }
                }

                if isFailed {
                    VStack(alignment: .leading, spacing: ZuvanoSpacing.footnoteTop) {
                        HStack {
                            Text(isFailureDismissed ? "Couldn't create" : failureHeadline)
                                .font(.footnote)
                                .foregroundStyle(ZuvanoColors.error)
                            Spacer()
                            if !isFailureDismissed {
                                Button("Retry", action: onRetry)
                                    .font(.footnote.weight(.medium))
                                    .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                            }
                        }
                        if !isFailureDismissed, draft.executionError == .permissionDenied {
                            Button("Open Settings", action: onOpenSettings)
                                .font(.footnote.weight(.medium))
                                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isSkipped ? 0.55 : 1)
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

    private var showsSourcePhrase: Bool {
        !isExecuted && !draft.sourcePhrase.isEmpty
    }

    @ViewBuilder
    private var executionStatusAccessory: some View {
        if isExecuting {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Creating…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Creating")
        } else if isExecuted {
            Label("Created", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(ZuvanoColors.success)
                .labelStyle(.titleAndIcon)
        }
    }

    private var rowForeground: Color {
        isSkipped ? ZuvanoColors.secondaryText : ZuvanoColors.primaryText
    }

    private var rowSymbolColor: Color {
        isSkipped ? ZuvanoColors.tertiaryText : ZuvanoColors.secondaryText
    }

    private var actionKindLabel: String {
        switch draft.actionKind {
        case .calendarEvent: "Calendar event"
        case .reminder: "Reminder"
        }
    }

    private var actionSymbol: String {
        switch draft.actionKind {
        case .calendarEvent:
            return "calendar"
        case .reminder:
            return "checklist"
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
            return "No due date"
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

    private var validationFootnoteSymbol: String {
        switch validationConcern {
        case .needsStartTime, .needsTitle:
            return "exclamationmark.circle"
        case .ambiguousReady:
            return "exclamationmark.circle"
        case .ready:
            return "info.circle"
        }
    }

    private var footnoteColor: Color {
        switch validationConcern {
        case .needsStartTime, .needsTitle:
            return ZuvanoColors.error
        case .ambiguousReady:
            return ZuvanoColors.warning
        case .ready:
            return ZuvanoColors.secondaryText
        }
    }

    private var failureHeadline: String {
        guard let error = draft.executionError else {
            return "Couldn't create"
        }
        switch error {
        case .interrupted:
            return "Creation was interrupted. Retry when you're ready."
        case .persistenceFailed:
            return "May already be in Calendar or Reminders. Retry to finish saving."
        case .permissionDenied:
            return draft.actionKind == .calendarEvent
                ? "Calendar access is off."
                : "Reminders access is off."
        case .noWritableCalendar:
            return "No calendar is available for this event."
        case .noWritableReminderList:
            return "No reminder list is available for this reminder."
        case .calendarSaveFailed:
            return "Calendar couldn't save this event."
        case .reminderSaveFailed:
            return "Reminders couldn't save this reminder."
        case .calendarFailed:
            return "Couldn't add this event to Calendar."
        case .reminderFailed:
            return "Couldn't add this reminder to Reminders."
        default:
            return "Couldn't create"
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
            components.append(failureHeadline)
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
