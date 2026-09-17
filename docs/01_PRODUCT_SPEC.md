# Zuvano: Product Specification

> Authoritative product requirements. Read [Project Context](./00_PROJECT_CONTEXT.md) first. Behavior is detailed in the [Feature Specification](./04_FEATURE_SPEC.md); mechanism in the [System Architecture](./02_SYSTEM_ARCHITECTURE.md).
>
> Priority labels: **MUST HAVE** · **SHOULD HAVE** · **NICE TO HAVE** · **OUT OF SCOPE**.

---

## 1. Product Overview

Zuvano is a native iOS app that reads user-provided conversational content, uses on-device intelligence to extract actionable intent **for the user**, and, after explicit user review and confirmation, creates native iOS Calendar events and Reminders.

## 2. Problem Statement

Actionable commitments arrive buried inside natural-language conversations. Turning them into Calendar events and Reminders is manual, slow, and error-prone, so items are forgotten or dropped.

## 3. Product Thesis

> Conversations contain implicit intent. Zuvano turns that implicit intent into explicit, user-confirmable actions.

## 4. Target Users

People who receive commitments through conversation (students, professionals, coordinators) and want to capture them as real system items quickly, privately, and with control.

## 5. User Jobs

| Job | Statement |
|---|---|
| Capture | "Turn this conversation into things I must do." |
| Trust | "Let me see and correct what Zuvano thinks before it acts." |
| Execute | "Put the confirmed items into my Calendar and Reminders." |
| Recover | "If something fails, don't lose my content; let me retry from where it failed." |

## 6. Core User Journey

1. User encounters a conversation with actionable content.
2. User shares/imports it into Zuvano.
3. Zuvano processes on-device, filters to user-actionable intents, and presents structured proposed actions (or "nothing actionable").
4. User reviews, edits, rejects, and confirms independently per draft.
5. Zuvano creates native Calendar events / Reminders for confirmed drafts only.
6. User sees the items exist in the native systems.

## 7. Core Product Loop

```
CONVERSATION → EXTRACTION → UNDERSTANDING → INTENT → USER-ACTIONABLE FILTER
  → ACTION DRAFT → REVIEW → EXPLICIT CONFIRMATION → NATIVE EXECUTION → RESULT
```

This is the spine of the product and of the [System Architecture](./02_SYSTEM_ARCHITECTURE.md).

## 8. Supported Inputs

| Input | Priority |
|---|---|
| Screenshot / image of conversation | **MUST HAVE** |
| Copied / pasted text | **MUST HAVE** |
| Share Sheet text | **MUST HAVE** |
| Share Sheet image | **MUST HAVE** |
| Email body text (user-shared) | **SHOULD HAVE** (share/paste as text) |
| Other text-bearing shared content | **NICE TO HAVE** |
| Direct messaging-app integration | **OUT OF SCOPE** |

The user always explicitly provides content. Zuvano never reads private conversations from other apps, never scrapes, and never monitors.

## 9. Understanding Requirements

- Distinguish actionable statements from statements that merely mention actions.
- Handle relative/ambiguous dates ("Friday", "around 7", "next week", "tomorrow").
- Recognize people, locations, dates, times, commitments.
- Preserve ambiguity as a **visible approximation** rather than silently hiding it.
- **MUST** distinguish (examples):
  - "I'll send the file tomorrow." → user commitment/task candidate → may become a draft.
  - "Arjun will send the files tomorrow." → other person's commitment → **not** a draft.
  - "Did you send the file yesterday?" → **not** a new task.
  - "I might go to Delhi next week." → hypothetical; low-confidence / probably not a user action.
  - "Don't forget to bring the files." → task/reminder candidate (user is asked to act).
  - "Remember that we met Friday." → historical, not an action.
- Empty user-actionable results are a **valid outcome** ("nothing actionable found"), not a pipeline failure.

## 10. Intent Types

Task, Reminder, Meeting/Event, Follow-up, Commitment; plus entities: Date/Time, Location, Person.

Not every entity is an executable action. **Not every Intent becomes an Action Draft.** Only user-actionable intents may become drafts.

## 11. Action Types

| Action | MVP | Native target |
|---|---|---|
| Calendar event | **MUST HAVE** | EventKit `EKEvent` |
| Reminder | **MUST HAVE** | EventKit `EKReminder` |
| Task (as Reminder) | **MUST HAVE** | EventKit `EKReminder` |
| Follow-up (as Reminder) | **SHOULD HAVE** | EventKit `EKReminder` |
| Recurring actions | **OUT OF SCOPE** | n/a |
| Notes / contacts / messages | **OUT OF SCOPE** | n/a |

Follow-up drafting/execution is **not** required for MVP. Architecture and features must not silently promote it to MUST.

## 12. Review and Confirmation

- **MUST HAVE.** AI produces *proposals*, never silent executions.
- The user can **confirm**, **reject**, or **edit** each draft independently. Drafts from one conversation need not share confirmation or execution state.
- Editable fields include title, date, time, location, action type, person, notes.
- Required fields must be valid **before** a draft becomes confirmed/executable.
- **Approximation:** a filled-in, visible value marked ambiguous (e.g. ~7:00 PM for "around 7") may be confirmed as-is.
- **Missing required value:** a Calendar event with no start date/time cannot be confirmed or executed. Reminders may omit a due date.
- Nothing executes before confirmation. See [Feature Spec F6–F11](./04_FEATURE_SPEC.md).

## 13. Native Action Execution

- **MUST HAVE.** Confirmed Action Drafts are created via EventKit. Intents are never sent to EventKit.
- Permissions are requested at the point of need, with explanation. Prefer write-only access if the SDK provides it. Do not read existing Calendar/Reminder items for duplicate detection.
- Execution results (success / failure + native identifier) are reported per action.
- A failed execution must not destroy the user's content and must be retryable **for that draft**.
- Execution idempotency: persist `executing` before EventKit; persist `nativeIdentifier` after success; never auto-execute a recovered `executing` draft with no native id. See [Data Model](./03_DATA_MODEL.md).

## 14. MVP Scope (MUST HAVE)

1. Import image / pasted text / shared text / shared image.
2. OCR images (temp image until success; then discard).
3. On-device understanding + intent extraction.
4. User-actionable filter before drafts.
5. Structured, editable action drafts.
6. Review / edit / reject per draft.
7. Confirm only after required-field validation.
8. Create Calendar events and Reminders for confirmed drafts.
9. Permission handling and clear failure reporting.
10. On-device, offline-capable core loop (primary AI or fallback).
11. Graceful AI-unavailable fallback (no silent fabrication).
12. Retry from the failed stage; in-flight recovery after interruption.
13. Execution idempotency via native identifier (not source hashing).

## 15. Should-Have Scope

- Email body ingestion via share/paste (no separate pipeline).
- Follow-up intent mapping to Reminder.
- Better ambiguity surfacing.

Persisted **browsable intake history** is **not** a should-have. Persistence is in-flight recovery only.

## 16. Nice-to-Have Scope

- Richer Share Sheet content types.

## 17. Future Scope (NOT MVP)

App Intents / Siri / Shortcuts, recurring actions, cross-conversation context, action history / conversation archive, conflict/duplicate intelligence, screenshot hashing, smart follow-up tracking, person↔action relationships, widgets, richer notification workflows, NaturalLanguage as a supporting engine. The architecture may leave a single pipeline entry point without implementing these.

## 18. Explicit Non-Goals

Zuvano is not a chatbot, messaging app, notes app, generic task manager, calendar replacement, general assistant, conversation archive, retrieval/memory system, social network, background monitor, web app, or cloud AI wrapper. No custom backend, no external LLM API, no API keys, no telemetry.

## 19. Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-1 | Accept image, pasted text, shared text, shared image as input | MUST |
| FR-2 | Extract text from images via OCR | MUST |
| FR-3 | Understand conversational text on-device | MUST |
| FR-4 | Extract structured intents and entities | MUST |
| FR-5 | Create editable action drafts **only** from user-actionable intents | MUST |
| FR-6 | Allow confirm/reject/edit per draft independently | MUST |
| FR-7 | Create Calendar events from confirmed drafts | MUST |
| FR-8 | Create Reminders from confirmed drafts | MUST |
| FR-9 | Request and handle permissions | MUST |
| FR-10 | Report success/failure per action | MUST |
| FR-11 | Preserve visible ambiguity for user resolution or confirm-as-approximation | MUST |
| FR-12 | Remain safe/usable when AI unavailable; fallback then retryable fail | MUST |
| FR-13 | Retry the failed stage without losing needed content | MUST |
| FR-14 | Guard against duplicate **execution** via native identifier + interrupt recovery | MUST |
| FR-15 | App Intents / Shortcuts | FUTURE |
| FR-16 | Follow-up as Reminder | SHOULD |
| FR-17 | Duplicate-source / screenshot hashing / calendar content matching | OUT |

## 20. Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-1 | On-device processing for the core loop |
| NFR-2 | Offline-capable core loop (Airplane Mode demo) |
| NFR-3 | Zuvano does not transmit conversation content to a backend |
| NFR-4 | No logging of personal content |
| NFR-5 | Responsive UI during processing (async pipeline) |
| NFR-6 | Hackathon-buildable: minimal dependencies, native APIs |
| NFR-7 | Testable without live AI (protocol boundaries) |

## 21. Privacy Requirements

- No backend, no external AI API, no API keys, no telemetry.
- Conversation content is not transmitted by Zuvano off-device to an AI or app backend.
- Confirmed EventKit items may sync through the user's Calendar/Reminders accounts.
- Persist only in-flight Intake/drafts needed for review, retry, and execution recovery.
- After discard, cancel, or terminal completion of an intake, delete temporary images and empty/delete extracted conversation text. Do not ship a browsable archive.
- Retain a raw image **only** while OCR has not succeeded; discard it after successful extraction (later failures retry from `extractedText`).
- Abandoned/cancelled processing must clean up temporary image data and share-handoff files.
- No unsupported encryption claims; use technically precise language.

## 22. Accessibility Requirements

- All review/confirm controls must be reachable via VoiceOver.
- Dynamic Type support for review content.
- Error and confirmation states conveyed in text, not color alone.
- *(Detailed a11y spec is part of the later UI/UX phase.)*

## 23. Performance Expectations

- Text extraction: near-instant for text; a few seconds for OCR.
- Understanding: bounded, with a visible processing state and timeout.
- UI never blocks on AI; processing is asynchronous.
- *REQUIRES DEVICE VALIDATION* for real on-device inference latency.

## 24. Reliability Expectations

- AI failure never destroys extracted text or source needed for retry.
- Retry the **failed stage** (OCR / understanding / draft generation / per-draft EventKit). Do not blindly restart the pipeline.
- Interrupted processing can be resumed from the failed stage or safely discarded.
- Failed executions are reported and retryable per draft.
- Execution idempotency: see [Data Model §15](./03_DATA_MODEL.md). Residual duplicate risk in the EventKit-success / persist-fail crash window is accepted. Do not scan Calendar/Reminders for content matches.

## 25. Assumptions

- Foundation Models (iOS 26+) is the primary on-device engine; runtime-gated via the installed SDK. Exact API names *REQUIRE SDK VALIDATION.*
- Vision OCR handles conversational screenshots.
- EventKit grants write access at runtime.
- On-device structured extraction is reliable enough with good prompting. (*REQUIRES DEVICE VALIDATION.*

## 26. Open Questions

- Exact Foundation Models structured-output API and token limits (*REQUIRES SDK VALIDATION.*
- How capable is a non-AI heuristic fallback? Default: do not fabricate intents.
- Share Extension handoff UX (*REQUIRES DEVICE VALIDATION.* In-extension inference is out of MVP.

## 27. Success Criteria

- A judge can understand the product within seconds of the demo.
- One shared conversation yields multiple correct, reviewable action drafts **for the user**.
- Confirmed drafts appear as real Calendar events / Reminders.
- The core loop works in Airplane Mode.
- No action is ever created without confirmation of an Action Draft.
- Other people's commitments and non-actions are not drafted.
