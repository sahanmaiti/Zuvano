import Foundation

/// Deterministic non-AI engine. Does not fabricate intents; only emits high-confidence
/// pattern matches with explicit user-action attribution.
struct FallbackUnderstandingEngine: UnderstandingEngine {
    nonisolated func understand(_ text: String) async throws -> UnderstandingResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return UnderstandingResult(intents: [], engine: .fallback)
        }

        let sentences = Self.splitSentences(from: trimmed)
        var intents: [Intent] = []

        for sentence in sentences {
            if let intent = Self.intent(from: sentence) {
                intents.append(intent)
            }
        }

        return UnderstandingResult(intents: intents, engine: .fallback)
    }

    nonisolated private static func splitSentences(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    nonisolated private static func intent(from sentence: String) -> Intent? {
        let normalized = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let lower = normalized.lowercased()

        if isQuestion(lower) { return nil }
        if isHistorical(lower) { return nil }
        if isHypothetical(lower) { return nil }
        if isOtherPersonCommitment(normalized, lower: lower) { return nil }
        if isEntityOnly(normalized) { return nil }

        if lower.contains("remind me") {
            return Intent(
                kind: .reminder,
                sourcePhrase: normalized,
                entities: extractEntities(from: normalized),
                confidence: .medium,
                ambiguous: containsAmbiguousTime(lower),
                attribution: .userAction
            )
        }

        if lower.contains("don't forget") || lower.contains("do not forget") {
            return Intent(
                kind: .task,
                sourcePhrase: normalized,
                entities: extractEntities(from: normalized),
                confidence: .medium,
                ambiguous: containsAmbiguousTime(lower),
                attribution: .userAction
            )
        }

        if lower.contains("let's meet") || lower.contains("lets meet") || lower.contains("meet at") {
            return Intent(
                kind: .meeting,
                sourcePhrase: normalized,
                entities: extractEntities(from: normalized),
                confidence: .medium,
                ambiguous: containsAmbiguousTime(lower),
                attribution: .userAction
            )
        }

        if lower.hasPrefix("i'll ") || lower.hasPrefix("i will ") {
            return Intent(
                kind: .commitment,
                sourcePhrase: normalized,
                entities: extractEntities(from: normalized),
                confidence: .medium,
                ambiguous: containsAmbiguousTime(lower),
                attribution: .userAction
            )
        }

        return nil
    }

    nonisolated private static func isQuestion(_ lower: String) -> Bool {
        lower.hasSuffix("?") || lower.hasPrefix("did you") || lower.hasPrefix("can you")
            || lower.hasPrefix("could you") || lower.hasPrefix("will you")
    }

    nonisolated private static func isHistorical(_ lower: String) -> Bool {
        lower.hasPrefix("remember that") || lower.contains("we met") && lower.contains("last")
            || lower.contains("yesterday") && (lower.contains("did you") || lower.contains("sent"))
    }

    nonisolated private static func isHypothetical(_ lower: String) -> Bool {
        lower.hasPrefix("i might") || lower.hasPrefix("maybe we") || lower.hasPrefix("perhaps ")
            || lower.contains("might go")
    }

    nonisolated private static func isOtherPersonCommitment(_ sentence: String, lower: String) -> Bool {
        let otherPersonPattern = #"(?i)^[A-Z][a-z]+ will "#
        if sentence.range(of: otherPersonPattern, options: .regularExpression) != nil {
            return true
        }

        if lower.contains(" will send") && !lower.hasPrefix("i'll") && !lower.hasPrefix("i will") {
            return true
        }

        return false
    }

    nonisolated private static func isEntityOnly(_ sentence: String) -> Bool {
        let wordCount = sentence.split(whereSeparator: \.isWhitespace).count
        let hasActionVerb = sentence.range(
            of: #"(?i)\b(meet|call|send|bring|remind|forget|schedule|book)\b"#,
            options: .regularExpression
        ) != nil
        return wordCount <= 3 && !hasActionVerb
    }

    nonisolated private static func containsAmbiguousTime(_ lower: String) -> Bool {
        lower.contains("around ") || lower.contains("about ") || lower.contains("~")
    }

    nonisolated private static func extractEntities(from sentence: String) -> [IntentEntity] {
        var entities: [IntentEntity] = []

        let weekdayPattern = #"(?i)\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|today)\b"#
        if let match = sentence.range(of: weekdayPattern, options: .regularExpression) {
            entities.append(IntentEntity(kind: .dateTime, rawExpression: String(sentence[match])))
        }

        let timePattern = #"(?i)\b(?:around|about|at)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b"#
        if let match = sentence.range(of: timePattern, options: .regularExpression) {
            let expression = String(sentence[match])
            entities.append(IntentEntity(kind: .dateTime, rawExpression: expression, ambiguous: true))
        }

        let locationPattern = #"(?i)\bat the ([^.?!]+)"#
        if let match = sentence.range(of: locationPattern, options: .regularExpression) {
            let expression = String(sentence[match].dropFirst(7))
            entities.append(IntentEntity(kind: .location, rawExpression: expression.trimmingCharacters(in: .whitespaces)))
        }

        let callPattern = #"(?i)\bcall ([A-Z][a-z]+)"#
        if let match = sentence.range(of: callPattern, options: .regularExpression) {
            let name = String(sentence[match].dropFirst(5))
            entities.append(IntentEntity(kind: .person, rawExpression: name.trimmingCharacters(in: .whitespaces)))
        }

        return entities
    }
}
