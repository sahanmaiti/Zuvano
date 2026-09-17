# Zuvano: Feature Specification

> Authoritative behavioral specification. Behavior only. No visual/layout design. Architecture: [System Architecture](./02_SYSTEM_ARCHITECTURE.md). Types: [Data Model](./03_DATA_MODEL.md). Requirements: [Product Specification](./01_PRODUCT_SPEC.md).
>
> Semantic rule across all features: **AI output is a proposal, never a silent execution.** Nothing reaches EventKit without explicit confirmation of an **Action Draft**. An Intent is not a draft.

---

## F1: Import / Capture Content

- **Purpose:** Receive conversation content into Zuvano.
- **User goal:** "Get this conversation into Zuvano."
- **Preconditions:** App running, or Share Extension invoked.
- **Inputs:** pasted text; image (photo picker); shared text/image via Share Sheet (after handoff).
- **Processing:** Wrap input into a unified `Source`; create an `Intake` with `processingState = importing`, `extractedText = nil`. For image sources, persist a temp file and set `temporaryImageRef` **before** OCR so a kill during extraction can retry.
- **Outputs:** A `Source` / Intake handed to the pipeline.
- **State changes:** Intake created (`importing`), then advances to `extracting`.
- **Dependencies:** none (Share path: F13).
- **Permissions:** Photos access only if picking from library (avoidable by using PhotosPicker).
- **Errors:** `invalidInput`, `unsupportedInput` → Intake `failed`, `failedStage` unset or not retried as extraction unless useful; user can discard.
- **Edge cases:** empty text; unsupported UTType; very large image.
- **Offline:** fully works offline.
- **Acceptance:** Pasted text and a chosen/shared image both produce an Intake and advance to extraction. `extractedText` is still nil until F2 succeeds.

---

## F2: Text Extraction / OCR

- **Purpose:** Obtain text from the source.
- **User goal:** (transparent) give the pipeline readable text.
- **Preconditions:** Intake exists; `processingState == extracting`.
- **Inputs:** `Source` and/or `temporaryImageRef`.
- **Processing:** Text → passthrough. Image → Vision OCR. On **success:** set `extractedText`, delete temp image, nil `temporaryImageRef`. On **OCR failure:** keep temp image; set `failed`, `failedStage = extraction`, `failureReason = ocrFailed`.
- **Outputs:** `ExtractedText` on success.
- **State changes:** `extracting → understanding` on success; `extracting → failed` on error.
- **Dependencies:** Vision.
- **Permissions:** none.
- **Errors:** `ocrFailed`; empty/unreadable image.
- **Edge cases:** blurry/cropped screenshot; image with no text; multiple screens. User may enter text manually; that counts as successful extraction and then discards the image.
- **Offline:** fully works offline.
- **Retry:** re-enters `extracting` only; does not run understanding until text exists.
- **Acceptance:** A clean conversational screenshot yields its text. Failure preserves enough image data for OCR retry or manual entry. Success does not keep the raw image for later stages.

---

## F3: Conversation Understanding

- **Purpose:** Interpret the meaning of the extracted text on-device.
- **User goal:** "Understand what's in this conversation."
- **Preconditions:** `extractedText` non-nil; engine selected.
- **Inputs:** `extractedText`.
- **Processing:** Orchestrator selects `UnderstandingEngine`. Primary = Foundation Models if the **installed SDK** reports availability; otherwise or on error, `FallbackUnderstandingEngine`. Fallback must **not** fabricate intents. If fallback cannot produce a safe result, fail the pipeline (`failedStage = understanding`). Produce `UnderstandingResult` with candidate `Intent`s (not drafts).
- **Outputs:** `UnderstandingResult`.
- **State changes:** `understanding → generatingDrafts` on a safe result (including zero intents). `understanding → failed` only if both engines cannot run safely (`aiUnavailable`, `aiExtractionFailed`, `malformedOutput` after fallback).
- **Dependencies:** Foundation Models (optional), fallback engine.
- **Permissions:** none.
- **Errors:** `aiUnavailable`, `aiExtractionFailed`, `malformedOutput`, after fallback is exhausted.
- **Edge cases:** text with no user-actionable content (still success); ambiguous/hypothetical statements.
- **Offline:** primary and fallback are on-device; fallback works when the model is unavailable.
- **Semantic examples:**
  - "I'll send the file tomorrow." → user commitment/task candidate.
  - "Arjun will send the files tomorrow." → may appear as a candidate; **must not** be drafted (F4/F5).
  - "Did you send the file yesterday?" → not a new task.
  - "Maybe we can meet Friday." → low-confidence / likely not drafted.
  - "Let's meet Friday at 7." → meeting candidate.
- **Retry:** re-enters `understanding` using `extractedText`. Does not re-OCR.
- **Acceptance:** The worked example yields meeting + reminder + task candidates. Questions/historical statements are not turned into actions.

---

## F4: Intent Extraction

- **Purpose:** Identify candidate intents and entities from understanding. This is a **slice of F3 output**, not a second AI engine.
- **User goal:** "Find what I need to act on."
- **Preconditions:** Understanding produced a result.
- **Inputs:** `UnderstandingResult`.
- **Processing:** Emit `Intent`s with kind, source phrase, entities, confidence, `ambiguous`. Apply the **user-actionable filter** (authoritative rules in [Data Model §8](./03_DATA_MODEL.md)): other people's commitments, historical statements, questions, non-action hypotheticals, entity-only hits, and (in MVP) follow-up unless SHOULD-HAVE is implemented; **do not pass**.
- **Outputs:** `[Intent]` that passed the filter (possibly empty).
- **State changes:** runs during Intake `generatingDrafts`; empty pass-through is valid.
- **Dependencies:** F3.
- **Permissions:** none.
- **Errors:** none at this layer for "nothing actionable." Malformed structured output is handled in F3.
- **Edge cases:** overlapping intents; commitments attributed to others (drop).
- **Offline:** works offline.
- **Acceptance:** Intents carry their original phrase. Non-user actions are not passed to F5.

---

## F5: Action Draft Generation

- **Purpose:** Convert **user-actionable** intents into concrete, editable action proposals.
- **User goal:** "Give me things I can review and confirm."
- **Preconditions:** Filter complete (list may be empty).
- **Inputs:** filtered `[Intent]` + current date.
- **Processing:** `IntentNormalizer` resolves relative dates/times, locations, people on each Intent (raw expression + normalized value + ambiguity). It does **not** create ActionDrafts. The **orchestrator** maps each **filtered, normalized** intent to an `ActionDraft` (`actionKind` = calendarEvent or reminder; `confirmationState = pending`; `executionState = notStarted`; `ambiguous` copied from unresolved approximation). Persist drafts. Follow-up → draft is **not** required in MVP.
- **Outputs:** `[ActionDraft]` (possibly empty).
- **State changes:** `generatingDrafts → readyForReview` (even if zero drafts). On mapping/normalization failure: `failed`, `failedStage = draftGeneration`, keep `extractedText`.
- **Dependencies:** F4, Normalizer, ActionStore.
- **Permissions:** none.
- **Errors:** `draftGenerationFailed`. Missing dates stay on the draft as editable/missing, not an Intake failure.
- **Edge cases:** "around 7" → visible ~7 PM, `ambiguous = true`, `startDate` set when the normalizer can propose a time; "Friday" relative date; no date at all (calendar drafts cannot confirm until a start exists).
- **Offline:** works offline.
- **Retry:** re-enter `generatingDrafts`. If candidate intents are gone from memory, re-run understanding as part of that retry using `extractedText`. Never OCR.
- **Acceptance:** The worked example produces a Friday ~7 PM meeting, a Thursday "Call Arjun" reminder, and a Friday "Bring project files" task; each editable, with ambiguity preserved. Zero user-actionable intents shows "nothing actionable," not an error.

---

## F6: Action Review

- **Purpose:** Let the user inspect all proposed actions.
- **User goal:** "See what Zuvano thinks before it does anything."
- **Preconditions:** Intake `processingState == readyForReview`.
- **Inputs:** `[ActionDraft]` (possibly empty).
- **Processing:** Present drafts with fields and ambiguity flags. Empty list: "nothing actionable found." No execution.
- **Outputs:** user decisions feed F7/F8/F9.
- **State changes:** Intake stays `readyForReview`. Draft states change only when the user acts.
- **Dependencies:** F5.
- **Permissions:** none.
- **Errors:** none.
- **Edge cases:** zero drafts; many drafts; mixed pending/rejected/confirmed siblings.
- **Offline:** works offline.
- **Acceptance:** Every draft is visible with its fields and ambiguity before any execution is possible. Empty result is valid.

---

## F7: Action Editing

- **Purpose:** Let the user correct a draft.
- **User goal:** "Fix what Zuvano got wrong."
- **Preconditions:** Draft `confirmationState == pending` (or rejected restored to pending). Intake `readyForReview`.
- **Inputs:** edited fields (title, date, time, location, action type, person, notes).
- **Processing:** Update the `ActionDraft`; re-validate. Clearing a missing required field keeps the draft unconfirmable. Resolving an approximation may set `ambiguous = false`.
- **Outputs:** updated `ActionDraft`.
- **State changes:** draft fields updated. Intake unchanged.
- **Dependencies:** F5/F6.
- **Permissions:** none.
- **Errors:** validation errors for empty/invalid values (draft stays pending).
- **Edge cases:** clearing an ambiguous time (calendar becomes not confirmable if `startDate` nil); changing reminder → calendar event (startDate required).
- **Offline:** works offline.
- **Acceptance:** Editing a field persists it and the edited value is what would execute after confirm.

---

## F8: Action Rejection

- **Purpose:** Let the user discard a proposed action.
- **User goal:** "Don't create this."
- **Preconditions:** Draft `pending` (or confirmed but `executionState == notStarted`).
- **Inputs:** rejection per draft.
- **Processing:** Set `confirmationState = rejected`. Rejected drafts are never executed. Can be restored to `pending`. Sibling drafts are unaffected.
- **Outputs:** updated draft.
- **State changes:** `confirmationState → rejected`. Intake unchanged.
- **Dependencies:** F6.
- **Permissions:** none.
- **Errors:** none.
- **Edge cases:** rejecting all drafts; rejecting one of many.
- **Offline:** works offline.
- **Acceptance:** Rejected drafts produce no Calendar/Reminder items.

---

## F9: Action Confirmation

- **Purpose:** Explicitly approve drafts for execution.
- **User goal:** "Yes, create these."
- **Preconditions:** Draft `confirmationState == pending`; Intake `readyForReview`.
- **Inputs:** confirmation per draft, or batch confirm of **selected** drafts only.
- **Processing:** Validate required fields **first**. If invalid, stay `pending` and show the error. If valid, set `confirmationState = confirmed`. Request needed permissions **before** persisting `executing`. If denied, the draft stays `confirmed` + `notStarted`; presentation shows `permissionRequired`; Intake stays `readyForReview`. If granted, hand **that draft** (or each selected valid draft) to execution independently. Confirming an ambiguous draft is allowed **only if** required values are present and visible (e.g. ~7:00 PM shown).
- **Outputs:** confirmed drafts eligible for execution.
- **State changes:** per-draft `confirmationState → confirmed`. Intake stays `readyForReview`. There is no Intake `confirmed` or Intake `executing`.
- **Dependencies:** F6/F7, PermissionManager, F10/F11.
- **Permissions:** Calendar and/or Reminder access as required for the confirmed action kinds only.
- **Errors:** validation errors (no confirm). `permissionDenied` does not mark `executing` and does not auto-retry EventKit.
- **Edge cases:** confirming one of three drafts; double-confirm (idempotent: already confirmed + notStarted still eligible once); mixed approximations and missing dates.
- **Offline:** works offline.
- **Acceptance:** Only `.confirmed` drafts execute; confirmation is required, explicit, and per-draft.

---

## F10: Calendar Execution

- **Purpose:** Create a native Calendar event from a confirmed draft.
- **User goal:** "Put this meeting in my Calendar."
- **Preconditions:** Draft confirmed; `actionKind == calendarEvent`; required fields valid; Calendar permission granted; `nativeIdentifier == nil`; `executionState ∈ {notStarted, failed}`.
- **Inputs:** confirmed `ActionDraft`.
- **Processing:** Persist `executionState = executing` **first**. `CalendarService` builds an `EKEvent` (title, start/end, location, notes) and saves it. On success, persist `executed` + `nativeIdentifier`. On failure, persist `failed` + `executionError`. Missing end time: default duration. Do not read other events to detect duplicates.
- **Outputs:** `ExecutionResult` with `nativeIdentifier` or error.
- **State changes:** that draft `executing → executed | failed`. Intake unchanged. Other drafts unchanged.
- **Dependencies:** EventKit, PermissionManager.
- **Permissions:** Calendar write access (prefer write-only if the SDK provides it).
- **Errors:** `permissionDenied`, `calendarFailed`. Missing start date is a **validation** error in F9, not an EventKit surprise.
- **Edge cases:** retry after failure (explicit); interrupt recovery (F12); default duration.
- **Offline:** works offline.
- **Acceptance:** A confirmed meeting draft appears as a real Calendar event; failure is reported and retryable on **that** draft without treating siblings as executed.

---

## F11: Reminder Execution

- **Purpose:** Create a native Reminder from a confirmed draft.
- **User goal:** "Put this in my Reminders."
- **Preconditions:** Draft confirmed; `actionKind == reminder`; title valid; Reminder permission granted; `nativeIdentifier == nil`; `executionState ∈ {notStarted, failed}`.
- **Inputs:** confirmed `ActionDraft`.
- **Processing:** Persist `executing` first. `ReminderService` builds an `EKReminder` (title, optional due date/time, notes) and saves it. Persist `executed` + id or `failed`.
- **Outputs:** `ExecutionResult` with `nativeIdentifier` or error.
- **State changes:** that draft only.
- **Dependencies:** EventKit, PermissionManager.
- **Permissions:** Reminders write access (prefer write-only if the SDK provides it).
- **Errors:** `permissionDenied`, `reminderFailed`.
- **Edge cases:** no due date (allowed); retry/idempotency; interrupt recovery.
- **Offline:** works offline.
- **Acceptance:** A confirmed task/reminder draft appears as a real Reminder.

---

## F12: Processing / Recovery

- **Purpose:** Keep needed content safe across failures and interruptions; never auto-execute.
- **User goal:** "Don't lose my stuff if something breaks; let me retry the step that failed."
- **Preconditions:** any pipeline or execution stage.
- **Inputs:** failure or process death.
- **Processing:**
  - Pipeline fail: set `failed` + `failedStage` + `failureReason`; preserve `extractedText` if it exists; preserve temp image only if extraction has not succeeded.
  - Retry: re-enter **that** stage (F2/F3/F5 or per-draft F10/F11). Never restart import/OCR if `extractedText` exists.
  - Launch recovery for drafts: `executing` + `nativeIdentifier` → `executed` (no EventKit). `executing` + no id → `failed` + `interrupted`; **do not** call EventKit until explicit retry.
  - Discard/cancel: `discarded`, then purge temp image, handoff files, and extracted text per [Data Model §9.1](./03_DATA_MODEL.md).
- **Outputs:** recoverable state or purged intake.
- **State changes:** as above. `interrupted` is a `FailureReason`, not a `ProcessingState`.
- **Dependencies:** ActionStore.
- **Permissions:** none.
- **Errors:** pipeline and execution `FailureReason` cases.
- **Edge cases:** app killed mid-OCR; mid-understanding; mid-EventKit; AI unavailable.
- **Offline:** works offline.
- **Acceptance:** After any failure, needed content is intact and retryable from the failed stage. Nothing is silently lost or auto-executed.

---

## F13: Share Sheet

- **Purpose:** Ingest text/image from the iOS Share Sheet.
- **User goal:** "Share this into Zuvano from anywhere."
- **Preconditions:** Share Extension installed; content shared.
- **Inputs:** shared text or image UTTypes.
- **Processing:** Extension **captures only**: write a `Source` payload to an App Group temporary file (unique name, no conversation body in URL queries or the general pasteboard). Open the main app. Main app ingests the file into F1, then **deletes** the handoff file (also delete on ingest failure). The extension does **not** run Foundation Models, OCR pipeline beyond capture, or EventKit.
- **Outputs:** an Intake in the main app.
- **State changes:** Intake created in the main app.
- **Dependencies:** F1.
- **Permissions:** none.
- **Errors:** `unsupportedInput`.
- **Edge cases:** extension memory limits; leftover files if the app never opens; delete stale handoff files on next launch. (*REQUIRES DEVICE VALIDATION* for handoff UX.
- **Offline:** works offline.
- **Acceptance:** Sharing text or an image from another app produces reviewable drafts (or "nothing actionable") in the main app.

---

## F14: App Intents / Shortcuts

- **Purpose:** (Future) expose the pipeline to Siri/Shortcuts.
- **User goal:** "Trigger Zuvano hands-free."
- **Preconditions:** MVP pipeline stable.
- **Inputs:** TBD.
- **Processing:** Wrap the existing pipeline entry point.
- **Outputs:** TBD.
- **State changes:** TBD.
- **Dependencies:** F1–F11.
- **Permissions:** as required.
- **Errors:** TBD.
- **Edge cases:** TBD.
- **Offline:** TBD.
- **Acceptance:** OUT OF SCOPE for MVP. Included only to confirm the architecture keeps a single wrappable entry point.
