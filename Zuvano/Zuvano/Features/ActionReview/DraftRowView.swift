import SwiftUI

struct DraftRowView: View {
    let draft: ActionDraftSnapshot
    let onEdit: () -> Void
    let onCreate: () -> Void
    let onSkip: () -> Void
    let onRestore: () -> Void

    private var validationConcern: DraftValidationConcern {
        DraftValidator.validationConcern(for: draft)
    }

    private var isSkipped: Bool {
        draft.confirmationState == .rejected
    }

    private var isConfirmed: Bool {
        draft.confirmationState == .confirmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ZuvanoSpacing.footnoteTop) {
            HStack(spacing: ZuvanoSpacing.footnoteTop) {
                Image(systemName: actionSymbol)
                    .foregroundStyle(isSkipped ? ZuvanoColors.secondaryText : ZuvanoColors.primaryText)
                    .accessibilityHidden(true)

                Text(draft.title)
                    .font(.headline)
                    .foregroundStyle(isSkipped ? ZuvanoColors.secondaryText : ZuvanoColors.primaryText)
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

            Text("\"\(draft.sourcePhrase)\"")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .lineLimit(2)

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
                }
            }
        }
        .padding(.vertical, ZuvanoSpacing.footnoteTop)
        .opacity(isSkipped ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(draft.sourcePhrase)
        .accessibilityAction(named: "Edit", onEdit)
        .accessibilityAction(named: isSkipped ? "Restore" : "Skip") {
            if isSkipped { onRestore() } else { onSkip() }
        }
        .accessibilityAction(named: "Create") {
            if DraftValidator.canCreate(draft) { onCreate() }
        }
        .accessibilityHint(createAccessibilityHint)
    }

    private var actionKindLabel: String {
        switch draft.actionKind {
        case .calendarEvent: "Calendar event"
        case .reminder: "Reminder"
        }
    }

    private var actionSymbol: String {
        switch draft.actionKind {
        case .calendarEvent: "calendar"
        case .reminder: "checklist"
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
        if isSkipped || isConfirmed { return nil }
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
        } else if isConfirmed {
            components.append("Selected for creation")
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
