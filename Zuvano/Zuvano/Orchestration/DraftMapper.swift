import Foundation

/// Maps normalized intents to ActionDraft snapshots. Owned by the orchestrator.
enum DraftMapper {
    nonisolated static func map(_ intents: [Intent], intakeID: UUID) -> [ActionDraftSnapshot] {
        intents.compactMap { mapIntent($0, intakeID: intakeID) }
    }

    nonisolated private static func mapIntent(_ intent: Intent, intakeID: UUID) -> ActionDraftSnapshot? {
        let actionKind = actionKind(for: intent.kind)
        let when = buildDateTime(from: intent)
        let location = intent.entities.first(where: { $0.kind == .location })?.rawExpression
        let person = intent.entities.first(where: { $0.kind == .person })?.rawExpression

        return ActionDraftSnapshot(
            intakeID: intakeID,
            intentKind: intent.kind,
            actionKind: actionKind,
            title: deriveTitle(from: intent),
            sourcePhrase: intent.sourcePhrase,
            when: when,
            location: location,
            person: person,
            confidence: intent.confidence,
            ambiguous: intent.ambiguous || (when?.ambiguous ?? false)
        )
    }

    nonisolated private static func actionKind(for intentKind: IntentKind) -> ActionKind {
        switch intentKind {
        case .meeting:
            .calendarEvent
        case .task, .reminder, .commitment, .followUp:
            .reminder
        }
    }

    nonisolated private static func deriveTitle(from intent: Intent) -> String {
        let phrase = intent.sourcePhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return "Untitled" }

        switch intent.kind {
        case .reminder:
            if let remainder = stripPrefix(from: phrase, pattern: #"(?i)remind me (?:to )?"#) {
                return capitalizeFirst(remainder)
            }
        case .task:
            if let remainder = stripPrefix(from: phrase, pattern: #"(?i)don'?t forget (?:to )?"#) {
                return capitalizeFirst(remainder)
            }
        case .meeting:
            if phrase.lowercased().contains("meet") {
                return "Meeting"
            }
        default:
            break
        }

        return capitalizeFirst(phrase)
    }

    nonisolated private static func capitalizeFirst(_ string: String) -> String {
        guard let first = string.first else { return string }
        return first.uppercased() + string.dropFirst()
    }

    nonisolated private static func stripPrefix(from phrase: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: phrase, range: NSRange(phrase.startIndex..., in: phrase)),
              let range = Range(match.range, in: phrase) else {
            return nil
        }
        let remainder = String(phrase[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder.isEmpty ? nil : remainder
    }

    nonisolated private static func buildDateTime(from intent: Intent) -> ActionDateTime? {
        let dateTimeEntities = intent.entities.filter { $0.kind == .dateTime }
        guard !dateTimeEntities.isEmpty else { return nil }

        let rawExpressions = dateTimeEntities.map(\.rawExpression).joined(separator: ", ")
        let isAmbiguous = dateTimeEntities.contains(where: \.ambiguous) || intent.ambiguous

        var startDate: Date?
        for entity in dateTimeEntities.reversed() {
            if let normalized = entity.normalizedValue,
               let parsed = parseISO8601(normalized) {
                startDate = parsed
                break
            }
        }

        return ActionDateTime(
            rawExpression: rawExpressions,
            startDate: startDate,
            ambiguous: isAmbiguous
        )
    }

    nonisolated private static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
