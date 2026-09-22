import Foundation

/// Pure, deterministic date/time and entity resolution. Does not create ActionDrafts.
enum IntentNormalizer {
    nonisolated static func normalize(
        _ intents: [Intent],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [Intent] {
        intents.map { normalizeIntent($0, referenceDate: referenceDate, calendar: calendar) }
    }

    nonisolated private static func normalizeIntent(
        _ intent: Intent,
        referenceDate: Date,
        calendar: Calendar
    ) -> Intent {
        var weekdayDate: Date?
        var timeResult: (date: Date, ambiguous: Bool)?
        var normalizedEntities: [IntentEntity] = []

        for entity in intent.entities {
            switch entity.kind {
            case .dateTime:
                if let weekday = resolveWeekday(entity.rawExpression, referenceDate: referenceDate, calendar: calendar) {
                    weekdayDate = weekday
                    normalizedEntities.append(IntentEntity(
                        id: entity.id,
                        kind: .dateTime,
                        rawExpression: entity.rawExpression,
                        normalizedValue: iso8601(weekday, calendar: calendar),
                        ambiguous: false
                    ))
                } else if let resolved = resolveTime(
                    entity.rawExpression,
                    on: weekdayDate,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) {
                    timeResult = resolved
                    normalizedEntities.append(IntentEntity(
                        id: entity.id,
                        kind: .dateTime,
                        rawExpression: entity.rawExpression,
                        normalizedValue: iso8601(resolved.date, calendar: calendar),
                        ambiguous: resolved.ambiguous
                    ))
                } else {
                    normalizedEntities.append(entity)
                }

            case .location, .person:
                normalizedEntities.append(IntentEntity(
                    id: entity.id,
                    kind: entity.kind,
                    rawExpression: entity.rawExpression,
                    normalizedValue: entity.rawExpression,
                    ambiguous: entity.ambiguous
                ))
            }
        }

        let isAmbiguous = intent.ambiguous || (timeResult?.ambiguous ?? false)
            || normalizedEntities.contains(where: { $0.kind == .dateTime && $0.ambiguous })

        return Intent(
            id: intent.id,
            kind: intent.kind,
            sourcePhrase: intent.sourcePhrase,
            entities: normalizedEntities,
            confidence: intent.confidence,
            ambiguous: isAmbiguous,
            attribution: intent.attribution
        )
    }

    nonisolated private static func resolveWeekday(
        _ expression: String,
        referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        let lower = expression.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lower == "today" {
            return calendar.startOfDay(for: referenceDate)
        }
        if lower == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate))
        }

        let weekdays: [(String, Int)] = [
            ("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4),
            ("thursday", 5), ("friday", 6), ("saturday", 7)
        ]

        for (name, weekday) in weekdays where lower.contains(name) {
            return nextWeekday(weekday, from: referenceDate, calendar: calendar)
        }

        return nil
    }

    nonisolated private static func nextWeekday(_ weekday: Int, from date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = weekday
        let candidate = calendar.date(from: components) ?? date
        let startOfCandidate = calendar.startOfDay(for: candidate)
        let startOfToday = calendar.startOfDay(for: date)
        if startOfCandidate < startOfToday {
            return calendar.date(byAdding: .day, value: 7, to: startOfCandidate) ?? startOfCandidate
        }
        return startOfCandidate
    }

    nonisolated private static func resolveTime(
        _ expression: String,
        on baseDate: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> (date: Date, ambiguous: Bool)? {
        let lower = expression.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isAmbiguous = lower.contains("around") || lower.contains("about") || lower.contains("~")

        let timePattern = #/(?:around|about|at|~)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/#
        guard let match = lower.firstMatch(of: timePattern) else { return nil }

        let hourStr = String(match.1)
        let minuteStr = match.2.map(String.init) ?? "0"
        let ampm = match.3.map(String.init)

        guard var hour = Int(hourStr), let minute = Int(minuteStr) else { return nil }

        if let ampm {
            if ampm == "pm" && hour < 12 { hour += 12 }
            if ampm == "am" && hour == 12 { hour = 0 }
        } else if hour <= 12 {
            hour += 12
        }

        let base = baseDate ?? calendar.startOfDay(for: referenceDate)
        var components = calendar.dateComponents([.year, .month, .day], from: base)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let resolved = calendar.date(from: components) else { return nil }
        return (resolved, isAmbiguous)
    }

    nonisolated private static func iso8601(_ date: Date, calendar: Calendar) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
}
