import Foundation
import FoundationModels

struct FoundationModelsUnderstandingEngine: UnderstandingEngine {
    nonisolated func understand(_ text: String) async throws -> UnderstandingResult {
        guard FoundationModelsAvailability.isAvailable else {
            throw UnderstandingError.unavailable
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return UnderstandingResult(intents: [], engine: .foundationModels)
        }

        let session = LanguageModelSession {
            """
            You extract structured candidate intents from conversational text.
            Identify meetings, reminders, tasks, commitments, and follow-ups.
            Mark attribution precisely: userAction only when the user must act.
            Mark otherPerson for someone else's commitments.
            Mark question, historical, hypothetical, or entityOnly when applicable.
            Preserve exact source phrases. Extract date, time, location, and person entities.
            """
        }

        do {
            let response = try await session.respond(
                to: Prompt {
                    "Extract candidate intents from this conversation:\n\n\(trimmed)"
                },
                generating: GenerableIntentExtraction.self
            )

            let intents = try Self.mapValidatedIntents(from: response.content)
            return UnderstandingResult(intents: intents, engine: .foundationModels)
        } catch let error as UnderstandingError {
            throw error
        } catch {
            throw UnderstandingError.extractionFailed
        }
    }

    nonisolated private static func mapValidatedIntents(
        from extraction: GenerableIntentExtraction
    ) throws -> [Intent] {
        var intents: [Intent] = []

        for candidate in extraction.intents {
            let phrase = candidate.sourcePhrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty else { continue }

            guard let kind = mapKind(candidate.kind),
                  let attribution = mapAttribution(candidate.attribution),
                  let confidence = mapConfidence(candidate.confidence) else {
                throw UnderstandingError.malformedOutput
            }

            let entities = candidate.entities.compactMap(mapEntity)

            intents.append(
                Intent(
                    kind: kind,
                    sourcePhrase: phrase,
                    entities: entities,
                    confidence: confidence,
                    ambiguous: candidate.ambiguous,
                    attribution: attribution
                )
            )
        }

        return intents
    }

    nonisolated private static func mapKind(_ kind: GenerableIntentKind) -> IntentKind? {
        switch kind {
        case .task: .task
        case .reminder: .reminder
        case .meeting: .meeting
        case .followUp: .followUp
        case .commitment: .commitment
        }
    }

    nonisolated private static func mapAttribution(_ attribution: GenerableAttribution) -> IntentAttribution? {
        switch attribution {
        case .userAction: .userAction
        case .otherPerson: .otherPerson
        case .question: .question
        case .historical: .historical
        case .hypothetical: .hypothetical
        case .entityOnly: .entityOnly
        }
    }

    nonisolated private static func mapConfidence(_ confidence: GenerableConfidence) -> ConfidenceLevel? {
        switch confidence {
        case .high: .high
        case .medium: .medium
        case .low: .low
        }
    }

    nonisolated private static func mapEntity(_ entity: GenerableIntentEntity) -> IntentEntity? {
        let expression = entity.rawExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expression.isEmpty else { return nil }

        let kind: EntityKind
        switch entity.kind {
        case .dateTime: kind = .dateTime
        case .location: kind = .location
        case .person: kind = .person
        }

        return IntentEntity(
            kind: kind,
            rawExpression: expression,
            ambiguous: entity.ambiguous
        )
    }
}

enum FoundationModelsAvailability {
    nonisolated static var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            let candidates = [Locale.current] + Locale.preferredLanguages.map(Locale.init(identifier:))
            return candidates.contains(where: SystemLanguageModel.default.supportsLocale)
        default:
            return false
        }
    }
}
