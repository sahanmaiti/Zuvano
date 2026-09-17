# Zuvano: Technical Decisions

> Records of major architecture/technology decisions. Rationale and alternatives are documented so a coding agent can implement without guessing. Architecture: [System Architecture](./02_SYSTEM_ARCHITECTURE.md). Data: [Data Model](./03_DATA_MODEL.md).
>
> Capability claims marked **REQUIRES SDK VALIDATION** or **REQUIRES DEVICE VALIDATION** must be verified against the installed Xcode SDK / real hardware before relying on them. Do not treat unverified Foundation Models type or method names as facts.

---

## TD-01: UI Framework: SwiftUI

- **Status:** Accepted
- **Context:** Native iOS app for a hackathon; speed and modern APIs matter.
- **Decision:** Use SwiftUI for all UI.
- **Alternatives:** UIKit; UIKit+SwiftUI hybrid.
- **Why:** Fastest path to a native, modern iPhone UI; integrates with Observation and Swift Concurrency. UI is designed later, so SwiftUI keeps layout flexible.
- **Consequences:** Business logic must stay out of views; use `@Observable` view models.
- **Revisit when:** A capability is unavailable in SwiftUI (unlikely for MVP).

## TD-02: State Management: Observation

- **Status:** Accepted
- **Context:** UI must reflect pipeline lifecycle states reactively.
- **Decision:** Use the Observation framework (`@Observable`) for view models/orchestrator state.
- **Alternatives:** Combine; manual `ObservableObject`.
- **Why:** Modern, less boilerplate, fine-grained updates.
- **Consequences:** Target iOS 17+ semantics; compatible with iOS 26/27 target.
- **Revisit when:** none expected.

## TD-03: Concurrency: Swift Concurrency + Swift 6 strict concurrency

- **Status:** Accepted
- **Context:** AI, OCR, and EventKit calls are async; state must be safe across actors.
- **Decision:** Use `async/await`, actors/`@MainActor`, and enable Swift 6 strict concurrency. Crossing types are `Sendable`.
- **Alternatives:** GCD; looser Swift 5 mode.
- **Why:** Safety and clarity for a concurrent pipeline; catches data races at compile time.
- **Consequences:** Some friction making types `Sendable`; worth it. Serialize EventKit per draft id.
- **Revisit when:** none expected.

## TD-04: Architecture Pattern: Modular pipeline with a single orchestrator

- **Status:** Accepted
- **Context:** Need clear boundaries without enterprise over-engineering.
- **Decision:** Focused modules (ingestion, extraction, intelligence, normalization, execution, permissions, persistence, domain types) coordinated by one pipeline orchestrator. The orchestrator owns the user-actionable filter and ActionDraft creation. Unidirectional dependencies. No DI framework, no event bus, no use-case-per-feature layer.
- **Alternatives:** MVVM-only; heavy Clean Architecture; event bus.
- **Why:** Matches the linear conversation→action loop; keeps it hackathon-buildable and testable.
- **Consequences:** One place owns pipeline lifecycle; draft confirmation/execution stay on ActionDraft.
- **Revisit when:** feature scope grows substantially post-hackathon.

## TD-05: Dependency Injection: Manual constructor injection, no framework

- **Status:** Accepted
- **Context:** Services must be mockable for tests and swappable (AI engine, executors).
- **Decision:** Inject protocol conformances via initializers. No DI container.
- **Alternatives:** A DI framework; service locators; singletons.
- **Why:** Simple, explicit, testable, zero dependency cost.
- **Consequences:** Wiring is manual but small in scope.
- **Revisit when:** object graph becomes large.

## TD-06: On-Device AI: Foundation Models as primary engine

- **Status:** Accepted
- **Context:** Privacy + offline requirements demand on-device intelligence.
- **Decision:** Use Apple Foundation Models (iOS 26+) as the primary understanding engine, runtime-gated on availability using the **installed SDK**. **REQUIRES SDK VALIDATION** for the exact availability API, structured-output/tool API, and token limits. Do not freeze unverified type names in architecture or code until validated.
- **Alternatives:** External LLM API (rejected (violates privacy/offline)/offline); NaturalLanguage-only (insufficient semantics; also out of MVP).
- **Why:** On-device, private, offline, no API keys; matches the product thesis.
- **Consequences:** Must handle unavailability and limited context; prompts must be compact; structured output must be validated; fallback required.
- **Revisit when:** Foundation Models proves unreliable for extraction on device.

## TD-07: AI Fallback Strategy

- **Status:** Accepted
- **Context:** Foundation Models may be unavailable or fail; the app must stay safe/usable.
- **Decision:** Provide a deterministic `FallbackUnderstandingEngine`. It does not fabricate intent. Flow: primary unavailable/fails → fallback → if fallback cannot produce a safe result, Intake fails at `understanding` and is retryable. Prefer zero intents or a manual-entry scaffold over invented actions.
- **Alternatives:** Hard-fail with no path forward; ship a bundled tiny model.
- **Why:** Graceful degradation is a product requirement.
- **Consequences:** Fallback quality is limited; empty actionable is a valid result, not a crash.
- **Revisit when:** a better offline heuristic is identified.

## TD-08: AI Abstraction: UnderstandingEngine protocol

- **Status:** Accepted
- **Context:** AI must be mockable/replaceable and must never execute directly.
- **Decision:** All understanding goes through `UnderstandingEngine`. Output is candidate `Intent`s. The orchestrator converts **only user-actionable** intents into reviewable `ActionDraft`s. Nothing is executed from AI output.
- **Alternatives:** Call Foundation Models inline in the orchestrator; map every intent to a draft.
- **Why:** Testability, the proposals-not-executions guarantee, and the product rule that other people's commitments are not user actions.
- **Consequences:** One extra protocol, justified. Filter lives in the orchestrator, not in EventKit.
- **Revisit when:** none expected.

## TD-09: OCR: Vision framework

- **Status:** Accepted
- **Context:** Screenshots of conversations need text extraction.
- **Decision:** Use Vision text recognition for OCR. VisionKit where it helps capture UX. **REQUIRES SDK VALIDATION** for exact API choice. Retain a temp image only until OCR succeeds; retry OCR from that file; later stages use `extractedText`.
- **Alternatives:** Third-party OCR; no OCR (text-only MVP).
- **Why:** Native, on-device, private, offline.
- **Consequences:** Quality depends on image quality; handle empty/failed OCR without dropping retry artifacts.
- **Revisit when:** real screenshot quality proves insufficient.

## TD-10: NaturalLanguage framework

- **Status:** Proposed (**OUT OF MVP**)
- **Context:** May assist entity/date detection as a signal.
- **Decision:** Do not implement NaturalLanguage in MVP. Optionally consider later as a supporting signal inside normalization, not as the primary understanding engine.
- **Alternatives:** Rely solely on Foundation Models (MVP choice).
- **Why:** Avoid a second NLP path during the hackathon.
- **Consequences:** Normalization uses explicit rules + model-provided expressions.
- **Revisit when:** normalization accuracy is evaluated on device post-MVP.

## TD-11: Structured AI Output

- **Status:** Accepted
- **Context:** Free-form AI text is unreliable to parse and hard to validate.
- **Decision:** Instruct Foundation Models to return structured intents/entities (via whatever structured-output/tool mechanism the **installed SDK** provides), then validate against the schema. Treat malformed output as `malformedOutput` and fall back. **REQUIRES SDK VALIDATION** for the exact mechanism.
- **Alternatives:** Parse free-form text with regex/heuristics.
- **Why:** Reliability and testability of intent extraction.
- **Consequences:** Must validate and handle schema violations; fallback must not fabricate.
- **Revisit when:** the SDK's structured-output capabilities are confirmed.

## TD-12: Date/Time Normalization: dedicated pure normalizer

- **Status:** Accepted
- **Context:** Relative/ambiguous dates ("Friday", "around 7") must be resolved and kept editable.
- **Decision:** A pure, deterministic `IntentNormalizer` resolves expressions against a provided `Date`, preserving the raw expression, normalized value, and an ambiguity flag. It does **not** create ActionDrafts. Visible approximations may be confirmed; missing Calendar `startDate` may not.
- **Alternatives:** Let the AI emit final dates directly; ad-hoc parsing.
- **Why:** Deterministic, testable, and keeps ambiguity visible to the user.
- **Consequences:** Needs a good rule set for common relative expressions.
- **Revisit when:** broader expression coverage is needed.

## TD-13: Persistence: SwiftData

- **Status:** Accepted
- **Context:** Persist in-flight Intakes and ActionDrafts (confirmation/execution state, native ids) for review, retry, and execution recovery, not a conversation archive.
- **Decision:** Use SwiftData. Model per [Data Model](./03_DATA_MODEL.md). Purge extracted text and temp images on discard/completion. Temp files for OCR-failure images and Share handoff. No content hashing.
- **Alternatives:** Core Data; raw files/UserDefaults.
- **Why:** Modern, Swift-native, sufficient for MVP in-flight state.
- **Consequences:** Schema kept minimal; in-memory container for tests; exclude store from backup or disclose backup behavior.
- **Revisit when:** persistence needs exceed SwiftData comfortably.

## TD-14: Calendar/Reminder Integration: EventKit

- **Status:** Accepted
- **Context:** Confirmed Action Drafts must become real Calendar events / Reminders.
- **Decision:** Use EventKit. `CalendarService` creates `EKEvent`s; `ReminderService` creates `EKReminder`s; both behind `ActionExecutor`. Persist `executing` before the save; persist `nativeIdentifier` after success. Launch recovery must not auto-execute `executing` without an id. Do not read existing items for duplicates. Confirm access-request APIs against the SDK. **REQUIRES SDK VALIDATION.**
- **Alternatives:** Open the Calendar/Reminders apps with URLs (no programmatic creation); third-party.
- **Why:** Native programmatic creation is the product's point.
- **Consequences:** Handle permissions and failures; native id is execution-idempotency only; residual crash-window duplicate risk is accepted.
- **Revisit when:** none expected.

## TD-15: Permission Handling: lazy, purpose-explained

- **Status:** Accepted
- **Context:** Calendar/Reminder access needs user consent.
- **Decision:** `PermissionManager` requests access at first execution need, only for needed action kinds, with explanation; denial leaves drafts intact (`readyForReview`). Provide Info.plist usage descriptions. Prefer write-only variants if the SDK has them.
- **Alternatives:** Request all permissions at launch; full calendar read for "smart" duplicates (rejected).
- **Why:** Better UX and trust; request only what's needed.
- **Consequences:** Execution may pause waiting on permission.
- **Revisit when:** none expected.

## TD-16: Share Sheet Processing Location

- **Status:** Accepted (MVP)
- **Context:** Share Extensions have memory limits; on-device inference is too heavy for the extension.
- **Decision:** The Share Extension captures the `Source` into an App Group temp file and hands off to the main app, which runs OCR, understanding, review, and EventKit. Cleanup after ingest. No Foundation Models or EventKit in the extension. **REQUIRES DEVICE VALIDATION** for handoff UX.
- **Alternatives:** Run the whole pipeline in the extension (rejected for MVP).
- **Why:** Avoids extension memory limits and keeps one pipeline path.
- **Consequences:** Hand-off UX must open the main app to show review.
- **Revisit when:** post-MVP device testing shows in-extension processing is reliable (still not required).

## TD-17: App Intents / Siri / Shortcuts

- **Status:** Rejected (for MVP)
- **Context:** Potential future integration.
- **Decision:** Not in MVP. Keep the pipeline entry point a single callable function so App Intents can wrap it later.
- **Alternatives:** Implement now.
- **Why:** Protects the core-loop scope.
- **Consequences:** Deferred; extension point preserved.
- **Revisit when:** MVP is stable.

## TD-18: Local-First / Privacy Architecture

- **Status:** Accepted
- **Context:** Privacy is a core requirement.
- **Decision:** No backend, no external AI API, no API keys, no telemetry. All Zuvano processing on-device. No conversation content logged. Raw images dropped after successful extraction; temp retain on OCR failure only. In-flight retention only; purge text/images on discard or completion. Do not claim Zuvano never writes to EventKit sync or device backup.
- **Alternatives:** Cloud processing; analytics; browsable intake history (rejected).
- **Why:** Matches the product's privacy thesis, offline goal, and "not an archive" non-goal.
- **Consequences:** All capability must come from on-device APIs; EventKit items may still sync via Apple accounts.
- **Revisit when:** none expected.

## TD-19: Logging Policy

- **Status:** Accepted
- **Context:** Must debug without leaking personal content.
- **Decision:** Log state transitions and error codes only; never log conversation text, names, locations, or draft contents.
- **Alternatives:** Verbose logging.
- **Why:** Privacy requirement.
- **Consequences:** Debugging relies on state/error signals.
- **Revisit when:** none expected.

## TD-20: Testing Strategy

- **Status:** Accepted
- **Context:** Must be testable without live AI or real Calendar.
- **Decision:** Use protocol seams to mock `UnderstandingEngine`, `ActionExecutor`, and an in-memory SwiftData store. Focus tests on the core loop including **user-actionable filter**, confirmation gating, per-stage retry, validation before confirm, and interrupt recovery (stale `executing` without native id must **not** auto-execute).
- **Alternatives:** UI-only testing; skip tests.
- **Why:** Reliability and safety guarantees are the product.
- **Consequences:** Requires keeping seams clean.
- **Revisit when:** none expected.

## TD-21: Third-Party Dependencies

- **Status:** Accepted
- **Context:** Hackathon; reliability and native fit.
- **Decision:** Zero third-party dependencies for the MVP. Use only Apple frameworks.
- **Alternatives:** Add libraries for OCR/parsing/DI.
- **Why:** Native APIs cover the needs; avoids integration risk.
- **Consequences:** Slightly more code, less risk.
- **Revisit when:** a clear, high-value dependency appears.

## TD-22: Deployment Target

- **Status:** Accepted
- **Context:** Need iOS 26+ for Foundation Models; product target is iOS 27.
- **Decision:** Deployment target iOS 26.0 minimum, developed/run against iOS 27. Runtime-gate all iOS-26+ capabilities using the installed SDK.
- **Alternatives:** Target older iOS and skip Foundation Models.
- **Why:** Foundation Models is central to the thesis.
- **Consequences:** Requires recent hardware/OS; handle unavailability via fallback.
- **Revisit when:** device support matrix is decided.
