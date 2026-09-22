import Foundation
import FoundationModels

@Generable
enum GenerableIntentKind: String {
    case task
    case reminder
    case meeting
    case followUp
    case commitment
}

@Generable
enum GenerableAttribution: String {
    case userAction
    case otherPerson
    case question
    case historical
    case hypothetical
    case entityOnly
}

@Generable
enum GenerableConfidence: String {
    case high
    case medium
    case low
}

@Generable
enum GenerableEntityKind: String {
    case dateTime
    case location
    case person
}

@Generable
struct GenerableIntentEntity {
    @Guide(description: "Entity kind: dateTime, location, or person")
    var kind: GenerableEntityKind

    @Guide(description: "Original wording from the conversation")
    var rawExpression: String

    @Guide(description: "Whether the entity value is ambiguous, such as around 7")
    var ambiguous: Bool
}

@Generable
struct GenerableIntentCandidate {
    @Guide(description: "Intent kind: task, reminder, meeting, followUp, or commitment")
    var kind: GenerableIntentKind

    @Guide(description: "Exact phrase from the conversation this came from")
    var sourcePhrase: String

    @Guide(description: "Who the statement applies to and whether it is a user action")
    var attribution: GenerableAttribution

    @Guide(description: "Confidence in this interpretation")
    var confidence: GenerableConfidence

    @Guide(description: "Whether timing or details are ambiguous")
    var ambiguous: Bool

    @Guide(description: "Extracted dates, times, locations, and people")
    var entities: [GenerableIntentEntity]
}

@Generable
struct GenerableIntentExtraction {
    @Guide(description: "Candidate intents extracted from the conversation")
    var intents: [GenerableIntentCandidate]
}
