# Zuvano: Data Model

> Authoritative data model for the Zuvano loop. Types are Swift value types / enums persisted with SwiftData where noted. Rationale: [Technical Decisions](./05_TECHNICAL_DECISIONS.md). Behavior: [Feature Specification](./04_FEATURE_SPEC.md).
>
> Intake processing and Action Draft confirmation/execution are **separate**. Intake never executes EventKit.

---

## 1. Data Architecture

The model mirrors the lifecycle. Each stage is a distinct concept; they are **not** collapsed into one object.

```
Source Content
  → Extracted Text
  → Understanding (transient)
  → Intent (transient candidate)
  → User-actionable filter (orchestrator rule, not a persisted entity)
  → ActionDraft
  → Confirmed (ActionDraft.confirmationState)
  → Executed (ActionDraft.executionState + nativeIdentifier)
```

**Persisted (in-flight):** `Intake`, `ActionDraft` (confirmation/execution state, native id), and a **temporary image file** only while OCR has not succeeded.

**Transient:** `Source` in memory, raw OCR intermediates, raw AI response, `UnderstandingResult`, `Intent`s.

**Not retained:** original images after **successful** extraction; extracted conversation text after the intake is discarded or purged at completion; raw AI responses.

**Not an entity:** "Confirmed Action" and "Executed Action" are states on `ActionDraft`.

---

## 2. Entities (Persisted)

### 2.1 Intake

One processing session for one piece of source content. Owns pipeline progress only, not EventKit execution.

| Field | Type | Req | Notes |
|---|---|---|---|
| `id` | UUID | ✓ | primary key |
| `sourceType` | SourceType | ✓ | `image` / `text` / `shareText` / `shareImage` |
| `extractedText` | String? | – | **nil until extraction succeeds**; then retained for review/retry |
| `temporaryImageRef` | String? | – | local file identifier while OCR has not succeeded; otherwise nil |
| `processingState` | ProcessingState | ✓ | pipeline lifecycle only |
| `failedStage` | PipelineStage? | – | set when `processingState == failed`; drives retry |
| `failureReason` | FailureReason? | – | pipeline failure only |
| `createdAt` | Date | ✓ | |
| `updatedAt` | Date | ✓ | |
| `drafts` | [ActionDraft] | ✓ | relationship; **may be empty** |

**Persistence reason:** review, per-stage retry, and recovery after interruption. Not a conversation archive.

**Privacy sensitivity:** HIGH (`extractedText`).

**Creation:** an Intake may be created at import with `extractedText == nil`. Do not persist a fake empty string to satisfy a required field.

### 2.2 ActionDraft

The persisted executable unit. Independent of sibling drafts on the same Intake.

| Field | Type | Req | Notes |
|---|---|---|---|
| `id` | UUID | ✓ | primary key |
| `intakeID` | UUID | ✓ | parent Intake |
| `intentKind` | IntentKind | ✓ | kind that passed the user-actionable filter |
| `actionKind` | ActionKind | ✓ | `calendarEvent` / `reminder` |
| `title` | String | ✓ | editable |
| `sourcePhrase` | String | ✓ | original phrase this came from |
| `when` | ActionDateTime? | – | normalized date/time + ambiguity |
| `location` | String? | – | |
| `person` | String? | – | |
| `notes` | String? | – | |
| `confidence` | ConfidenceLevel | ✓ | high/medium/low |
| `ambiguous` | Bool | ✓ | visible approximation / unresolved ambiguity, not a pipeline state |
| `confirmationState` | ConfirmationState | ✓ | pending / confirmed / rejected |
| `executionState` | ExecutionState | ✓ | notStarted / executing / executed / failed |
| `nativeIdentifier` | String? | – | EventKit item id once created |
| `executionError` | FailureReason? | – | per-draft execution/interrupt failure |
| `createdAt` | Date | ✓ | |
| `updatedAt` | Date | ✓ | |

**Persistence reason:** survives interruption across review → confirm → execute; stores native id for execution idempotency.

**Privacy sensitivity:** HIGH.

---

## 3. Value Types (Transient / Embedded)

### 3.1 Source

Unified in-memory ingestion value. Not a long-lived SwiftData entity.

| Field | Type | Notes |
|---|---|---|
| `type` | SourceType | |
| `text` | String? | for text sources |
| `imageData` | Data? | for image sources in memory |

After a successful extraction, drop `imageData`. If OCR has not succeeded and the Intake is persisted for retry, write bytes to a temp file and store `Intake.temporaryImageRef`; do not keep the image as a required Intake field forever.

### 3.2 ExtractedText

| Field | Type | Notes |
|---|---|---|
| `text` | String | result of OCR or passthrough |
| `method` | ExtractionMethod | direct / ocr |
| `ocrConfidence` | Double? | where available |

Copied onto `Intake.extractedText` only on success.

### 3.3 UnderstandingResult

| Field | Type | Notes |
|---|---|---|
| `intents` | [Intent] | candidate meanings; **not** drafts |
| `engine` | EngineKind | `foundationModels` / `fallback` |

### 3.4 Intent

Transient. **Never persisted. Never sent to EventKit.**

| Field | Type | Notes |
|---|---|---|
| `kind` | IntentKind | |
| `sourcePhrase` | String | original wording |
| `entities` | [IntentEntity] | dates/times/locations/people |
| `confidence` | ConfidenceLevel | |
| `ambiguous` | Bool | ambiguity in the candidate |

The orchestrator applies the **user-actionable filter** to each Intent. Intents that fail the filter are dropped (not drafted). They are not a second persisted list.

### 3.5 IntentEntity

| Field | Type | Notes |
|---|---|---|
| `kind` | EntityKind | dateTime / location / person |
| `rawExpression` | String | e.g. "around 7", "Friday" |
| `normalizedValue` | String? | resolved value (filled by normalizer) |
| `ambiguous` | Bool | |

### 3.6 ActionDateTime

| Field | Type | Notes |
|---|---|---|
| `rawExpression` | String | "around 7", "Friday" |
| `startDate` | Date? | normalized; required for calendar confirm |
| `endDate` | Date? | if inferable |
| `allDay` | Bool | |
| `ambiguous` | Bool | true for "around 7" etc. |

**Approximation vs missing:** `startDate != nil` and `ambiguous == true` is a visible approximation. `startDate == nil` on a calendar draft is a missing required value.

---

## 4. Enums

| Enum | Cases |
|---|---|
| `SourceType` | `image, text, shareText, shareImage` |
| `ExtractionMethod` | `direct, ocr` |
| `EngineKind` | `foundationModels, fallback` |
| `IntentKind` | `task, reminder, meeting, followUp, commitment` |
| `ActionKind` | `calendarEvent, reminder` |
| `EntityKind` | `dateTime, location, person` |
| `ConfidenceLevel` | `high, medium, low` |
| `ProcessingState` | `importing, extracting, understanding, generatingDrafts, readyForReview, failed, discarded` |
| `PipelineStage` | `extraction, understanding, draftGeneration` |
| `ConfirmationState` | `pending, confirmed, rejected` |
| `ExecutionState` | `notStarted, executing, executed, failed` |
| `FailureReason` | see below |

`IntentKind.followUp` may appear in understanding output. **MVP does not require** converting follow-up intents into ActionDrafts (product SHOULD). If a follow-up is drafted in a later increment, it maps to `ActionKind.reminder`.

### 4.1 FailureReason applicability

**Pipeline** (`Intake.failureReason`), when `processingState == failed`:

`invalidInput`, `unsupportedInput`, `ocrFailed`, `aiUnavailable`, `aiExtractionFailed`, `malformedOutput`, `draftGenerationFailed`, `persistenceFailed`, `cancelled`, `interrupted`

**Per-draft execution** (`ActionDraft.executionError`):

`permissionDenied`, `calendarFailed`, `reminderFailed`, `interrupted`

Do **not** use `missingDateTime` or "ambiguous intent" as Intake pipeline failures. Those are validation / review concerns on a draft.

`permissionDenied` does not move the Intake out of `readyForReview`.

---

## 5. Relationships

- `Intake` 1 → * `ActionDraft` (zero or more).
- `ActionDraft` embeds `ActionDateTime` and scalar entity fields (location/person) for MVP simplicity.
- No other persisted entity relationships for MVP.
- User-actionable filtering is a **function**, not a table.

---

## 6. State Machines

### 6.1 Processing lifecycle (`Intake.processingState`)

Covers ingestion through "ready for review" or pipeline failure. **Does not include confirmation or EventKit.**

```
[*] → importing
importing → extracting
importing → failed          (invalid/unsupported input)
importing → discarded

extracting → understanding  (extraction succeeded; extractedText set; image discarded)
extracting → failed         (failedStage = extraction; retain temp image if OCR failed)
extracting → discarded

understanding → generatingDrafts
understanding → failed      (failedStage = understanding; keep extractedText; no image required)
understanding → discarded

generatingDrafts → readyForReview   (including zero drafts)
generatingDrafts → failed           (failedStage = draftGeneration; keep extractedText)
generatingDrafts → discarded

failed → extracting         (only if failedStage == extraction)
failed → understanding      (only if failedStage == understanding)
failed → generatingDrafts   (only if failedStage == draftGeneration)
failed → discarded

readyForReview → discarded  (user leave/purge/cancel)
```

`readyForReview` is the **only** review state. There is no Intake `ambiguous`, `confirmed`, `executing`, `executed`, `partiallyFailed`, or `actionsDetected`.

**Derived (not stored):**

- **Nothing actionable:** `processingState == readyForReview` && `drafts.isEmpty`
- **All done:** `processingState == readyForReview` && every draft is `rejected` or (`confirmed` && `executed`) or (`failed` && user has dismissed retry). Derived only, not an execution gate.

### 6.2 Confirmation lifecycle (`ActionDraft.confirmationState`)

```
pending → confirmed     (only if validation passes; see §10)
pending → rejected
rejected → pending      (user re-enables)
confirmed → rejected    (only if executionState == notStarted)
confirmed → pending     (optional un-confirm before execution starts)
```

Do not set `confirmed` if required fields are missing. Confirming an **ambiguous but populated** approximation is allowed.

Siblings are independent: one draft may stay `pending` while another is `rejected` and another is `confirmed`.

### 6.3 Execution lifecycle (`ActionDraft.executionState`)

Only drafts with `confirmationState == confirmed` may leave `notStarted` for EventKit.

```
notStarted → executing     (persist this first, then call EventKit)
executing  → executed      (nativeIdentifier set)
executing  → failed        (EventKit error, permission, or recovered interrupt with no native id)
failed     → executing     (explicit user retry only)
```

Intake state does **not** change when a draft executes.

---

## 7. Action Lifecycle (per draft)

```
ActionDraft(pending, notStarted)
  → validate required fields
  → user confirms → (confirmed, notStarted)
  → persist (confirmed, executing) before EventKit
  → EventKit succeeds → (confirmed, executed + nativeIdentifier)
  → EventKit fails → (confirmed, failed + executionError)
  → user retry → (confirmed, executing) …  [same persist-before-EventKit rules]
```

Eligibility to call EventKit:

`confirmationState == confirmed`  
&& `executionState ∈ {notStarted, failed}`  
&& `nativeIdentifier == nil`  
&& required fields valid for `actionKind`

Never execute `pending` or `rejected` drafts. Never infer eligibility from Intake state.

---

## 8. User-actionable filter

Applied by the orchestrator **after** understanding and **before** normalization and ActionDraft mapping. **Does not create a persisted type.** Order: understand → filter → normalize remaining intents → map to drafts.

An Intent may become an ActionDraft **only if** it is an action the **user** can take.

**Do not draft:**

- Other people's commitments ("Arjun will send the files tomorrow")
- Historical statements ("Remember that we met Friday")
- Questions ("Did you send the file yesterday?")
- Hypotheticals that are not a user action ("I might go to Delhi next week")
- Entity-only information (a date or person with no user action)
- Follow-up intents in MVP unless the SHOULD-HAVE follow-up mapping is explicitly implemented later

**May draft:**

- User commitments ("I'll send the file tomorrow") → typically Reminder
- Requests of the user ("Don't forget to bring the files") → Reminder
- Meetings the user is attending ("Let's meet Friday around 7") → Calendar event
- User-requested reminders ("Remind me Thursday to call Arjun") → Reminder

Zero passing intents → `readyForReview` with empty `drafts`. **Not** `failed`.

---

## 9. Persistence Strategy

- SwiftData store for `Intake` + `ActionDraft`.
- Persist at: import (minimal Intake), extraction success or OCR failure (text and/or temp image), after draft generation, on every confirmation/execution change **including persist-`executing` before EventKit**.
- Temporary image file: named uniquely (Intake id); delete on successful OCR, discard, cancel, or purge.
- Share-handoff files: same cleanup after the main app ingests (or fails to ingest). See [Architecture §20](./02_SYSTEM_ARCHITECTURE.md).
- Do **not** persist raw AI responses.
- Do **not** hash screenshots or `extractedText` for duplicate-source detection.
- Executed drafts keep `nativeIdentifier` while the Intake remains in-flight.

### 9.1 Terminal retention / deletion

Zuvano is **not** a conversation archive. Persist only what active review, retry, and execution recovery need.

**Purge** (delete temp image; empty or delete `extractedText`; delete the Intake and its drafts) when:

1. User discards/cancels the intake (`processingState → discarded`, then purge).
2. User leaves a `readyForReview` intake with **zero** drafts.
3. User leaves after every draft is terminal: `rejected`, or `executed`, or `failed` with retry dismissed.

Native Calendar/Reminder items **remain** in EventKit. Zuvano does not need to keep conversation text afterward.

While any draft is `pending`, `executing`, or `failed` with retry still available, keep `extractedText` (and keep the temp image **only** if `failedStage == extraction`).

---

## 10. Validation

Performed **before** `confirmationState` becomes `confirmed`. If validation fails, the draft stays `pending` and surfaces a validation error. Do not execute.

| ActionKind | Required to confirm |
|---|---|
| `calendarEvent` | non-empty `title`; non-nil `when.startDate` |
| `reminder` | non-empty `title`; due date **optional** |

`ambiguous == true` does **not** block confirmation if required values are present and shown. It also does **not** bypass required-field checks.

`actionKind` must be one the executor supports.

---

## 11. Migration Strategy

MVP is greenfield. Keep the schema minimal. Do not build a migration framework for the hackathon.

---

## 12. Privacy-Sensitive Fields

`Intake.extractedText`, `ActionDraft.title/location/person/notes/sourcePhrase`, and temporary image bytes are HIGH sensitivity.

Rules: no backend transmission, no logging of values, in-flight retention only, images dropped after successful extraction, purge on discard/completion.

Zuvano does not upload content. EventKit items may sync via the user's accounts. The SwiftData store may be backed up with the device unless excluded; exclude it or disclose it; do not claim encryption theater.

---

## 13. Native System Identifiers

`ActionDraft.nativeIdentifier` stores the EventKit identifier of the created Calendar event / Reminder. It is an **execution-idempotency** mechanism for **that draft**. It is **not** duplicate-source intelligence and is **not** used to match new screenshots or conversation text.

Do not read the user's existing Calendar/Reminder library to find duplicates.

---

## 14. Failure / Retry

| Failed work | Retry enters | Artifacts required |
|---|---|---|
| OCR / extraction | `extracting` (`failedStage = extraction`) | temp image (or original in-memory Source if never persisted) |
| Understanding | `understanding` (`failedStage = understanding`) | `extractedText`, not the image |
| Draft generation / normalization / mapping | `generatingDrafts` (`failedStage = draftGeneration`) | `extractedText`. If candidate `Intent`s are still in memory, reuse them. If not, the orchestrator may re-run understanding **inside this retry** using `extractedText`. Never OCR. |
| EventKit | that ActionDraft `failed → executing` | the draft; `nativeIdentifier` must be nil |

Never restart from import when later artifacts exist. Never auto-advance from retry into EventKit.

Empty user-actionable results are not a failure.

---

## 15. Duplicate / Idempotency (execution only)

No screenshot hashing. No content hashing. No Calendar scan.

| Scenario | Guard |
|---|---|
| Double-confirm / double-tap | Execution only starts if eligible (§7); at most one in-flight EventKit call per `draft.id` |
| EventKit save succeeds | Persist `executed` + `nativeIdentifier`; presence of `nativeIdentifier` blocks another create |
| App killed after persist `executing`, before EventKit | On launch: `executing` + no `nativeIdentifier` → set `failed` + `interrupted`. **Do not auto-execute.** User must retry. |
| App killed after EventKit success, before persist id | Residual duplicate risk if the user retries. **Accepted.** Do not scan EventKit for title/date matches. |
| App killed after EventKit success and id was persisted, state still `executing` | On launch: `executing` + `nativeIdentifier` → set `executed`. Do not create another item. |
| Retry failed execution | Only drafts in `failed` with `nativeIdentifier == nil`, explicit user retry |

Launch recovery must never auto-call EventKit.

---

## 16. Temporary image rules

1. Image may be retained only while extraction has **not** succeeded (`temporaryImageRef` or in-memory `Source.imageData`).
2. Successful OCR/passthrough: write `extractedText`, delete temp image, nil `temporaryImageRef`.
3. Later pipeline failures use `extractedText`.
4. Failed OCR: keep temp image so OCR can be retried or the user can enter text manually (manual text sets `extractedText` and then deletes the image).
5. Discard/cancel/purge: delete temp image.
