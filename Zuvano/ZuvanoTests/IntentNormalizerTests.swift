import Foundation
import Testing
@testable import Zuvano

struct IntentNormalizerTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    private var referenceDate: Date {
        // Wednesday, September 17, 2025
        var components = DateComponents()
        components.year = 2025
        components.month = 9
        components.day = 17
        components.hour = 12
        return calendar.date(from: components)!
    }

    @Test func resolvesWeekday() {
        let intent = Intent(
            kind: .meeting,
            sourcePhrase: "Let's meet Friday.",
            entities: [IntentEntity(kind: .dateTime, rawExpression: "Friday")],
            confidence: .high,
            attribution: .userAction
        )

        let normalized = IntentNormalizer.normalize([intent], referenceDate: referenceDate, calendar: calendar)

        #expect(normalized.count == 1)
        let dateEntity = normalized[0].entities.first { $0.kind == .dateTime }
        #expect(dateEntity?.normalizedValue != nil)
    }

    @Test func resolvesAmbiguousTime() {
        let intent = Intent(
            kind: .meeting,
            sourcePhrase: "Let's meet around 7.",
            entities: [
                IntentEntity(kind: .dateTime, rawExpression: "Friday"),
                IntentEntity(kind: .dateTime, rawExpression: "around 7", ambiguous: true)
            ],
            confidence: .high,
            ambiguous: true,
            attribution: .userAction
        )

        let normalized = IntentNormalizer.normalize([intent], referenceDate: referenceDate, calendar: calendar)

        #expect(normalized.count == 1)
        #expect(normalized[0].ambiguous)
        let timeEntity = normalized[0].entities.last { $0.kind == .dateTime && $0.ambiguous }
        #expect(timeEntity?.normalizedValue != nil)
    }

    @Test func doesNotInventStartDateForUnresolvable() {
        let intent = Intent(
            kind: .task,
            sourcePhrase: "Bring the files.",
            entities: [],
            confidence: .medium,
            attribution: .userAction
        )

        let normalized = IntentNormalizer.normalize([intent], referenceDate: referenceDate, calendar: calendar)

        #expect(normalized[0].entities.isEmpty)
    }

    @Test func resolvesTomorrow() {
        let intent = Intent(
            kind: .reminder,
            sourcePhrase: "Remind me tomorrow.",
            entities: [IntentEntity(kind: .dateTime, rawExpression: "tomorrow")],
            confidence: .medium,
            attribution: .userAction
        )

        let normalized = IntentNormalizer.normalize([intent], referenceDate: referenceDate, calendar: calendar)

        let dateEntity = normalized[0].entities.first { $0.kind == .dateTime }
        #expect(dateEntity?.normalizedValue != nil)
    }
}
