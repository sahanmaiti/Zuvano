# Zuvano: Project Context

> **Master context document.** Read this first. It should be sufficient to understand Zuvano without access to any prior conversation.
>
> Document set: [Product Specification](./01_PRODUCT_SPEC.md) · [Feature Specification](./04_FEATURE_SPEC.md) · [System Architecture](./02_SYSTEM_ARCHITECTURE.md) · [Data Model](./03_DATA_MODEL.md) · [Technical Decisions](./05_TECHNICAL_DECISIONS.md)
>
> If documents disagree, resolve in this order: **Product requirements → Feature behavior → Architecture → Technical decisions.** Technical convenience must never silently change the product.

---

## 1. Product Identity

| | |
|---|---|
| Name | **Zuvano** |
| Platform | iOS (iPhone only) |
| Target OS | iOS 27 (built against the iOS 26+ SDK; deployment target iOS 26.0) |
| Language | Swift |
| UI framework | SwiftUI |
| Type | Native iOS application |
| Context | ACoding Hackathon 2026 |
| Category | On-device conversation → intent → native action |

## 2. One-Sentence Definition

> Zuvano turns unstructured conversational content into structured, user-confirmable native iOS actions.

## 3. Product Thesis

> **Conversations contain implicit intent. Zuvano turns that implicit intent into explicit, user-confirmable actions.**

Conversations are full of commitments, dates, meetings, reminders, locations, people, and follow-ups, but that intent is buried in natural language. Zuvano reads user-provided content, extracts candidate meaning, proposes concrete actions **the user can take**, and only after the user reviews and confirms turns those proposals into real native iOS objects (Calendar events, Reminders).

The core loop is:

```
CONVERSATION
  → EXTRACTION
  → UNDERSTANDING
  → INTENT
  → USER-ACTIONABLE FILTER
  → ACTION DRAFT
  → USER REVIEW
  → EXPLICIT CONFIRMATION
  → NATIVE EXECUTION
  → RESULT
```

**Everything in the architecture must support this loop.** An Intent is not an Action Draft. An Action Draft is not an execution.

## 4. Problem

People receive conversations that contain things they must act on: a meeting to attend, a task to do, a reminder to set. Today they must read the conversation, mentally parse each actionable item, and manually create each Calendar event / Reminder themselves. This is slow, error-prone, and items get dropped.

## 5. Solution

The user gives Zuvano the conversation (a screenshot, copied text, or shared content). Zuvano uses on-device intelligence to understand it, keeps only intents that are actions **for the user**, and proposes drafts. The user reviews the proposed actions, edits or rejects them, and confirms. Zuvano then creates the corresponding native iOS Calendar events and Reminders.

The user stays in control. **Nothing is created until they confirm.**

## 6. Core Loop

| Step | Description |
|---|---|
| 1. Conversation | User provides conversation content (image, text, shared item) |
| 2. Extraction | Text is extracted (OCR for images; passthrough for text) |
| 3. Understanding | On-device model interprets meaning |
| 4. Intent | Candidate meanings are identified |
| 5. User-actionable filter | Only actions the user can take become draft candidates |
| 6. Action drafts | Structured, editable action proposals are generated |
| 7. Review | User inspects each proposed action |
| 8. Explicit confirmation | User confirms / edits / rejects each independently; required fields are valid before confirm |
| 9. Native execution | Confirmed drafts become Calendar events / Reminders via EventKit |
| 10. Result | Success / failure reported per action |

## 7. Target User

A person who receives conversational commitments (students, professionals, anyone coordinating with others) and wants to turn them into real Calendar/Reminder items quickly without manual re-entry. They value speed, privacy, and control.

## 8. Core Use Cases

1. Screenshot a chat → share to Zuvano → get proposed meeting + reminders → confirm → events created.
2. Copy a message → paste into Zuvano → review extracted task → confirm → Reminder created.
3. Share text from another app via the Share Sheet → Zuvano extracts a meeting → confirm → Calendar event created.

## 9. Supported Input Types

| Input | MVP | Notes |
|---|---|---|
| Screenshot / image of conversation | ✅ MUST | OCR via Vision |
| Copied/pasted text | ✅ MUST | Direct text |
| Share Sheet text | ✅ MUST | Share Extension captures and hands off |
| Share Sheet image | ✅ MUST | Share Extension + OCR in the **main app** |
| Email body text (user-shared) | SHOULD | Via Share Sheet / paste (same as text; no special source type required) |
| Direct messaging-app integration | ❌ OUT | No private APIs, no scraping |

## 10. Worked Example

**Input conversation:**

> "Yeah Friday works. Let's meet around 7 at the café near campus. Don't forget to bring the project files. Also remind me Thursday to call Arjun."

**Extracted action drafts (after user-actionable filter):**

| # | When | What | Type |
|---|---|---|---|
| 1 | Friday · ~7:00 PM | Meet at café near campus | Meeting / Calendar event |
| 2 | Thursday | Call Arjun | Reminder |
| 3 | Friday | Bring project files | Task / Reminder |

These three come from **one** conversation, not three manual entries. "Around 7" becomes a **visible** ~7:00 PM proposal (`ambiguous == true`, `startDate` set). The user may edit it or confirm the approximation. A Calendar event with **no** start date cannot be confirmed.

**Not drafted from this kind of conversation:** "Arjun will send the files tomorrow" (other person's commitment), "Did you send the file yesterday?" (question), "Remember that we met Friday" (historical).

## 11. Intent Types (semantic)

Task, Reminder, Meeting/Event, Follow-up, Commitment, plus extracted entities: Date/Time, Location, Person.

> **An Intent does not automatically become an Action Draft.** Only an intent that represents an action **the user can take** may become an executable Action Draft.
>
> Other people's commitments, historical statements, questions, hypotheticals that are not a user action, and entity-only information must not become executable drafts. The model separates *what was said* from *what the user could do*.

Follow-up as an executable Reminder is **SHOULD HAVE**, not MVP MUST. Understanding may notice a follow-up; MVP must not treat follow-up drafting as required.

## 12. Action Types (executable, MVP)

| Action | Native framework | MVP |
|---|---|---|
| Calendar event | EventKit (`EKEvent`) | MUST |
| Reminder | EventKit (`EKReminder`) | MUST |
| Task (as Reminder) | EventKit (`EKReminder`) | MUST |
| Follow-up (as Reminder) | EventKit (`EKReminder`) | SHOULD, not required in MVP |

Commitments that **are** user-actionable map to a Reminder in the MVP. Commitments that are not the user's action are not drafted.

## 13. Review & Confirmation Principle

**Non-negotiable.** AI output is a *proposal*, never an execution. Zuvano must not create any Calendar event or Reminder without explicit user confirmation of an **Action Draft**. The user may confirm, edit, or reject each draft independently. Multiple drafts from one Intake may be pending, rejected, confirmed, executed, or failed at the same time. See [Feature Specification §F6–F11](./04_FEATURE_SPEC.md).

## 14. Native iOS Integration Concept

A **confirmed Action Draft** is converted into a real system object via EventKit. Zuvano requests the minimal required permissions at the point of need, explains why, and reports the created item (and its native identifier) back to the user. AI never talks to EventKit.

## 15. Privacy Model

- **On-device processing.** Zuvano does not send conversation content to any backend or external LLM.
- **No external LLM API, no API keys, no telemetry** in the core flow.
- **In-flight persistence only**: enough to review, retry, and recover execution; not a conversation archive. See [Data Model](./03_DATA_MODEL.md).
- **No logging of personal content.**
- Confirmed Calendar/Reminder items may sync via the user's Apple accounts; that is EventKit, not Zuvano uploading content.
- The local store may be included in device backup unless excluded; do not claim "never leaves the device" for persisted text. Prefer excluding the store or disclosing this. After an intake is discarded or completed, sensitive extracted text is emptied/deleted.

## 16. Offline / Local-First Philosophy

The entire core loop should work in Airplane Mode using on-device models and the non-AI fallback. Any capability that genuinely needs network is documented honestly, not hidden.

## 17. MVP Boundaries

**In:** reliable ingestion (image/text/share), OCR, on-device understanding + intent extraction, **user-actionable filter**, action drafts, review/edit/reject, confirmation, Calendar + Reminder execution, permission handling, graceful failure, per-stage retry, execution idempotency, privacy.

**Out:** Siri/Shortcuts/App Intents, recurring actions, cross-conversation context, conflict/duplicate **intelligence**, screenshot/content hashing, widgets, richer notification flows, messaging-app integrations, browsable intake history, NaturalLanguage as a required engine. (See [Product Specification, Future Scope](./01_PRODUCT_SPEC.md).)

## 18. Explicit Non-Goals

Zuvano is NOT: a chatbot, messaging client, notes app, generic task manager, calendar replacement, general assistant, conversation archive, retrieval/memory system, social network, background monitor, web app, or cloud AI wrapper. It never reads private conversations from other apps, never scrapes, never monitors in the background, never reads existing Calendar/Reminder items to detect duplicates.

## 19. Key Architectural Principles

- **Lifecycle separation:** conversation → extracted text → understanding → intent → **user-actionable filter** → action draft → confirmed draft → executed draft are distinct. See [Data Model](./03_DATA_MODEL.md).
- **Intake vs drafts:** Intake processing state is ingestion → ready for review / failed / discarded. Confirmation and EventKit execution live **only** on Action Drafts. "All done" is derived from drafts, not an Intake execution gate.
- **Human in the loop:** AI proposes, human confirms, system executes.
- **On-device, local-first.**
- **Simple, modular, testable, native.** One orchestrator, focused services, protocol seams only where justified. No enterprise over-engineering.
- **AI swappable:** the understanding layer sits behind a protocol. See [System Architecture](./02_SYSTEM_ARCHITECTURE.md).
- **Graceful degradation:** the app stays safe and usable when AI or permissions are unavailable. Primary engine → fallback → retryable failure. Never fabricate actions silently.
- **Retry from the failed stage**, not a blind full-pipeline restart.

## 20. Terminology

| Term | Meaning |
|---|---|
| **Source Content** | The raw user-provided input (image, text, shared item) |
| **Extracted Text** | Text obtained from the source (OCR or direct). Exists only after extraction succeeds. |
| **Understanding** | Semantic interpretation of the extracted text |
| **Intent** | A candidate meaning identified in the conversation. **Not** an Action Draft. |
| **User-actionable intent** | An Intent that represents an action the **user** can take |
| **Intent Entity** | A date, time, location, or person extracted from the text |
| **Action Draft** | A concrete, editable proposal for a native action, created only from a user-actionable intent |
| **Confirmed Action** | An Action Draft the user has approved **and** that passed required-field validation |
| **Executed Action** | A confirmed Action Draft successfully created natively (`nativeIdentifier` set) |
| **Ambiguity** | Uncertainty (e.g. "around 7") that must remain visible on the draft as an approximation |
| **Missing required value** | A field the action kind needs (e.g. Calendar `startDate`) that is absent: blocks confirmation |
| **Intake** | One processing session for one piece of source content. Does not execute EventKit. |
| **Failed stage** | The pipeline stage to retry (`extraction`, `understanding`, or `draftGeneration`) |

## 21. Key Assumptions

- **ASSUMPTION:** Foundation Models (iOS 26+) is the primary on-device understanding engine; availability is hardware/Apple-Intelligence gated and must be checked at runtime using the **installed SDK's** availability API. (*REQUIRES SDK VALIDATION* for the exact API name.
- **ASSUMPTION:** Vision/VisionKit OCR is sufficient for conversational screenshots. (*REQUIRES DEVICE VALIDATION* for real-world screenshot quality.
- **ASSUMPTION:** EventKit Calendar/Reminder write access is grantable at runtime with standard permission prompts. Write-only variants if present. (*REQUIRES SDK VALIDATION.*
- **ASSUMPTION:** A small on-device model can extract structured intents with prompting + structured output. (*REQUIRES DEVICE VALIDATION.*

## 22. Open Questions

- Exact Foundation Models structured-output schema & token limits (*REQUIRES SDK VALIDATION.*
- Best OCR strategy for low-quality / cropped screenshots.
- Whether a heuristic (non-AI) fallback produces useful results, or only a degraded "manual entry" experience. MVP default: do not fabricate intents; prefer a low-confidence scaffold or empty actionable result over invented actions.
- Share Extension memory; in-extension inference is **out of MVP**; handoff only. *REQUIRES DEVICE VALIDATION* for handoff UX.
