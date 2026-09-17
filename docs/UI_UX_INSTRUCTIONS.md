# Zuvano: UI/UX Instructions

> **Authoritative UI/UX specification for implementation.** Behavior and data rules remain governed by the product document set. If this file disagrees with product requirements, resolve: **Product → Feature → Architecture → Data Model → Technical Decisions → this UI/UX document.**
>
> Related: [Project Context](./00_PROJECT_CONTEXT.md) · [Product Spec](./01_PRODUCT_SPEC.md) · [Feature Spec](./04_FEATURE_SPEC.md) · [System Architecture](./02_SYSTEM_ARCHITECTURE.md) · [Data Model](./03_DATA_MODEL.md) · [Technical Decisions](./05_TECHNICAL_DECISIONS.md)
>
> **Scope of this document:** visual design, interaction design, information architecture, accessibility, motion, and copy. **Not** SwiftUI source code, view files, or component implementations.

---

## 0. Platform & constraints

| | |
|---|---|
| Platform | iPhone only |
| Framework | SwiftUI |
| Deployment | iOS 26.0 |
| Development / test | iOS 27 |
| Dependencies | Apple frameworks only (no third-party UI) |
| Design references | Apple HIG; Liquid Glass used only on the functional layer |

Zuvano is **not**: a chatbot, memory/retrieval app, messaging client, calendar replacement, generic task manager, AI dashboard, SaaS console, conversation archive, or floating-orb assistant.

**Core experience:**

```
Conversation → Understanding → Intent → User Review → Explicit Create → Native iOS Action
```

Preserve the distinction at all times:

| Concept | UI meaning |
|---|---|
| AI interpretation | Invisible process; may surface calm status copy only |
| Intent | Never shown as a first-class list of “intents” |
| Action Draft | Visible **proposal** the user can edit, skip, or create |
| Confirmed Action | Internal state on the path to EventKit, not a success badge |
| Executed Action | Only state that may look **created** in Calendar / Reminders |

**Trust boundary (non-negotiable):**

> Zuvano suggests → I review/edit → I **create** → iOS writes the Calendar event or Reminder.

Never imply that an action already exists in Calendar or Reminders until `executionState == executed`.

---

## 1. UX philosophy

Zuvano should feel **native, calm, intelligent, precise, trustworthy, lightweight, premium, purposeful, and human**.

Design for a person who shared a conversation and wants to leave with the right Calendar events and Reminders, quickly, privately, and in control.

**Principles**

1. **One job.** Turn conversation content into confirmable native actions.
2. **Agency.** The user decides what is created. AI never creates.
3. **Proposals, not products.** Drafts look provisional until EventKit succeeds.
4. **Clarity over cleverness.** Plain language. No model jargon.
5. **Familiarity.** Prefer system lists, forms, sheets, buttons, and materials.
6. **Restraint.** Every surface must earn its place. No decorative AI chrome.
7. **Recoverability.** Failures are local, explained, and retryable from the failed step.
8. **Privacy posture.** On-device processing; no conversation archive UI.

---

## 2. Core interaction principles

1. **Capture is explicit.** Paste, photo, or Share Sheet; never background reading of other apps.
2. **Processing is temporary.** Full-screen progress is a short modality, then Review.
3. **Review is the product.** Action Review is the primary surface after capture.
4. **Create is the irreversible verb.** Buttons that write to EventKit use **Create** / **Add to Calendar** / **Add Reminder**, not soft “Confirm.”
5. **One create gesture per draft.** User taps Create → validate → `confirmed` → permission if needed → execute. Do not strand drafts in a long-lived “Confirmed” UI state unless blocked on permission.
6. **Independent drafts.** Each draft can be pending, skipped, creating, created, or failed independently.
7. **Approximation ≠ missing.** “About 7:00 PM” may be created if the concrete time is visible. A Calendar draft with no start date cannot.
8. **Done does not destroy work.** Done / leave / purge only when the intake is terminal (see §20–22 and Data Model §9.1).
9. **No auto-execute on launch recovery.** Interrupted drafts need an explicit Retry.
10. **Status is never color-only.** Always pair color with text, symbol, and accessibility value.

---

## 3. Information architecture

```
Home / Capture
  └─ Processing (modal full-screen within stack)
       └─ Action Review          ← primary product surface
            ├─ Edit Draft (sheet)
            ├─ Source Text (sheet, optional peek)
            ├─ Permission pre-alert → system alert
            └─ Per-draft execution feedback (inline)
```

**Out of IA (MVP)**

- Tab bar
- Conversation history / archive browser
- Chat thread
- Intent browser
- Confidence / model debug screens
- Settings beyond what the system Settings app provides for permissions (optional minimal About later; not required for MVP)
- Calendar browsing / conflict UI

---

## 4. Navigation architecture

| Decision | Choice |
|---|---|
| Root | `NavigationStack` |
| Tabs | **None** for MVP |
| Capture → Processing | Replace / push Processing as the active root destination for the intake |
| Processing → Review | Transition to Action Review (animated; Reduce Motion → crossfade / instant) |
| Edit Draft | **Sheet** with Form (not a deep push hierarchy) |
| Source text peek | Sheet |
| Return Home | Explicit Done (when terminal) or Discard (with confirmation) |

**Rules**

- Prefer sheets for narrowly scoped tasks (edit, source peek).
- Do not nest modal-on-modal except a system alert over the permission pre-alert, or a discard confirmation over Review.
- Share Extension opens the main app into Processing for the handed-off intake, not into a chat UI.

---

## 5. Screen inventory

| ID | Screen | Purpose |
|---|---|---|
| S1 | Home / Capture | Idle entry; start an intake |
| S2 | Processing | OCR / understanding / draft generation progress |
| S3 | Action Review | Inspect, edit, skip, create drafts |
| S4 | Edit Draft | Correct fields before create |
| S5 | Source Text | Read-only peek at extracted text for this intake |
| S6 | Nothing Actionable | Empty valid result |
| S7 | Pipeline Failure | Failed stage with Retry / Discard / Manual text |
| S8 | Permission Pre-alert | Brief explanation before system Calendar/Reminders prompt |
| S9 | Share Extension | Capture-only; open main app |

Alerts / confirmation dialogs are not separate “screens” but are specified in §42–43.

---

## 6. Screen hierarchy

**Primary:** Action Review (after a successful pipeline).

**Secondary:** Home / Capture (entry and return).

**Transient:** Processing, Edit sheet, Source sheet, permission pre-alert, system alerts.

**Terminal outcomes on Review:** all drafts skipped; all created; mix resolved (created / skipped / failed-with-retry-dismissed) → Done returns Home and purges per Data Model.

---

## 7. State architecture (presentation)

Map product/data states to UI without inventing extra product states.

### 7.1 App / intake presentation states

| UI state | When | Screen |
|---|---|---|
| `idle` | No active intake | S1 Home |
| `processing` | Intake `importing`…`generatingDrafts` | S2 |
| `review` | Intake `readyForReview` with ≥1 draft | S3 |
| `emptyActionable` | Intake `readyForReview` && drafts empty | S6 |
| `pipelineFailed` | Intake `failed` | S7 |
| `permissionNeeded` | Presentation flag; Intake remains `readyForReview` | Banner / inline on S3 |

### 7.2 Draft presentation states (per row)

| UI label | Underlying | Visual |
|---|---|---|
| Proposal | `pending` + `notStarted` | Provisional row; Create available if valid |
| Needs attention | `pending` + invalid required fields | Inline validation; Create disabled for that draft |
| About… | `ambiguous == true` with values present | Human footnote; Create allowed |
| Skipped | `rejected` | Dimmed; Restore available |
| Creating… | `confirmed` + `executing` | Progress on row; not success |
| Waiting for access | `confirmed` + `notStarted` + permission denied | Inline + Open Settings |
| Created | `confirmed` + `executed` | Success text + SF Symbol check **only here** |
| Couldn’t create | `confirmed` + `failed` | Error + Retry |

**Do not** show a long-lived “Confirmed” badge that implies completion without EventKit success.

### 7.3 Selection mode (batch create)

- Enter **Select** from the toolbar.
- Use **leading** selection controls (system edit/select style), **never trailing checkmarks** on proposals.
- Trailing checkmarks / filled success tints are reserved for **Created** (`executed`) only.
- Exit Select mode after create attempt or Cancel.

---

## 8. Empty states

### Home (S1)

- Title: **Zuvano**
- Short line: **Turn a conversation into Calendar events and Reminders.**
- Primary actions: **Paste**, **Choose Photo**
- Secondary hint: **Or share text or a screenshot to Zuvano from another app.**
- No chatbot greeting, no suggested prompts grid, no “Ask anything.”

### Nothing Actionable (S6)

- `ContentUnavailableView` pattern.
- Title: **Nothing to create**
- Description: **Zuvano didn’t find anything for you to add to Calendar or Reminders.**
- Action: **Done** (terminal; purge intake)

### All skipped

- On Review: short status that every proposal was skipped.
- Action: **Done**

---

## 9. Loading / processing states (S2)

Full-screen calm progress. One status line that updates by phase:

| Phase | Copy |
|---|---|
| Importing / extracting (text) | **Reading text…** |
| Extracting (image) | **Reading the screenshot…** |
| Understanding | **Understanding the conversation…** |
| Generating drafts | **Preparing actions…** |

**Rules**

- No chat bubbles, typing indicators, token streams, orb, shimmer “AI” brand marks, or fake transcript.
- Show a determinate spinner/progress only if duration is known; otherwise indeterminate system `ProgressView`.
- **Cancel** in the toolbar → if work would be lost, confirmation dialog → Discard.
- VoiceOver: announce phase changes politely (live update), not only a static “Loading.”

---

## 10. No-actionable-content state

Valid outcome, **not** an error (Feature Spec F5/F6; Data Model “nothing actionable”).

- Use S6 empty state.
- Do not offer Retry as if the pipeline failed (unless the user wants to start over with new content from Home after Done).
- Do not say “AI failed.”

---

## 11. Action Review experience (S3): core UX

**User question this screen answers:**

> “What did Zuvano find that I might want to do?”

### Layout

- Native inset grouped `List`.
- Optional header: short context (**3 proposed actions**) and a text button **View source** when `extractedText` exists.
- Rows = Action Drafts only (never raw Intents).
- Sticky toolbar / bottom bar for primary create actions when appropriate (system toolbar preferred).

### What each draft communicates

| Field | How shown |
|---|---|
| What | Primary title |
| When | Secondary line; prefix **About** when `ambiguous` |
| Where | Secondary / tertiary if present |
| Who | Secondary / tertiary if present |
| Action type | Leading SF Symbol + accessibility label (Calendar event / Reminder) |
| Source context | Short quoted `sourcePhrase` in secondary style; full phrase in accessibility value if truncated |
| Ambiguity | Footnote: **About 7:00 PM, check before creating.** |
| Missing required | Footnote in destructive/secondary emphasis: **Add a start time to create this event.** |
| Editable | Tap row or Edit control → S4 |
| Create / Skip | See §14 and row actions below |
| Execution state | Trailing **text + symbol**; never color alone |

### Row interaction model

| Gesture | Result |
|---|---|
| Tap row | Open Edit Draft sheet |
| Swipe trailing | **Skip** |
| Swipe leading | **Edit** (optional if tap already edits) |
| Context menu | Create (if valid), Edit, Skip / Restore, View source |
| Toolbar Select | Enter selection mode for batch create |

**Do not** put Create + Edit + Skip as three equally prominent buttons on every row. Prefer:

- Tap → Edit
- Swipe / menu → Skip
- Toolbar → **Create All Ready** / **Create Selected**
- Single-draft intakes may show a prominent **Create** on the row or as the sole toolbar primary

### Selection / batch

- **Create All Ready** creates every draft that is pending, valid, and not skipped.
- If some drafts are invalid, do **not** silently skip them without explanation. Prefer:
  - Button title **Create 3 Ready**, and
  - Subtitle or alert: **2 need a start time.**
- **Create Selected** only in Select mode; selection chrome is leading, not trailing checkmarks.

---

## 12. Action Draft presentation

**Visual language of a proposal**

- Standard list row background (content layer, no Liquid Glass).
- Leading symbol in secondary/primary label color, not a neon glow.
- Title: `headline` / body emphasized.
- Meta: `subheadline` / `footnote`, secondary label color.
- Source phrase: footnote, tertiary / secondary; quote marks optional.

**Created row**

- Trailing: **Created** with `checkmark.circle.fill` (or calendar/reminder equivalent).
- May use a subtle success tint **only** on the status accessory, not a whole-card celebration.
- Row remains readable; do not remove the draft until Done/purge.

**Skipped row**

- Reduced opacity or secondary styling.
- Label **Skipped**; affordance **Restore**.

**Failed row**

- **Couldn’t create** + short reason + **Retry**.

---

## 13. Action editing experience (S4)

**Presentation:** modal sheet, Form.

**Fields**

| Field | Control |
|---|---|
| Title | TextField |
| Type | Picker: **Calendar Event** / **Reminder** |
| Starts | DatePicker (required for Calendar Event) |
| Ends | DatePicker optional (Calendar); default duration applied if missing at create time |
| Due | DatePicker optional (Reminder) |
| Location | TextField |
| Person | TextField |
| Notes | TextField / TextEditor |
| Original phrasing | Read-only footnote when ambiguous or helpful (`rawExpression`) |

**Rules**

- Save / Done on the sheet **updates the draft only**; never executes EventKit.
- Changing Reminder → Calendar Event: require start date before Create becomes available.
- Clearing start on a Calendar draft: Create disabled; show validation.
- Resolving ambiguity (user picks an exact time): set `ambiguous = false`.
- Validate on save and again before Create (Feature Spec F7/F9).

---

## 14. Confirmation / Create experience

Treat Create as the trust boundary.

### User-facing verbs

| Do say | Don’t say |
|---|---|
| **Create**, **Add to Calendar**, **Add Reminder**, **Create 3 Items** | Confirm, Approve, Accept, Run AI, Execute |
| **Skip** | Delete forever (unless discarding whole intake) |
| **Restore** | Undelete |

Internal docs may still say “confirmation”; UI copy uses **Create**.

### Create path (single draft)

1. Validate required fields.
2. If invalid → stay proposal; show why.
3. Set confirmed → request permission if needed → persist `executing` → EventKit.
4. Update row to Creating… then Created or Couldn’t create.

### Ambiguous create

- Allowed when required values are present and **visible**.
- Optional lightweight confirmation dialog only if useful: **Create using About 7:00 PM?**. Buttons: **Create**, **Edit**, **Cancel**. Prefer not to interrupt if the About footnote is already clear on the row.

### Permission denied

- Draft stays confirmed + notStarted (not executing).
- Show **Waiting for access** + **Open Settings**.
- Do not mark as Created.

---

## 15. Calendar action UX

- Leading symbol: `calendar` / `calendar.badge.plus`.
- Create copy when only calendar drafts: **Add to Calendar** / **Create Event**.
- Require visible start date/time.
- Default duration if end missing (product behavior); do not ask unless editing.
- After Created: status **Created**; optional menu **Open in Calendar** if a system URL/API is available without reading other events for duplicates.
- Never browse or match existing events for “duplicate intelligence.”

---

## 16. Reminder action UX

- Leading symbol: `checklist` / `reminder.bell`.
- Create copy when only reminders: **Add Reminder** / **Create Reminder**.
- Due date optional; show **No due date** as secondary if absent.
- After Created: **Created**; optional **Open in Reminders** if available.
- Never read existing reminders for duplicate detection.

### Mixed batch

Toolbar label should name both stores when needed, e.g. **Create 2 Events & 1 Reminder**.

---

## 17. Permission UX

**When:** First Create that needs Calendar and/or Reminders access (lazy).

**Pre-alert (optional but recommended when first requesting)**

- Short explanation of benefit.
- **One** button: **Continue** (not Allow).
- Opens the system permission alert.
- Purpose strings (Info.plist) must be specific, e.g.:
  - Calendar: **Zuvano adds events you approve to Calendar.**
  - Reminders: **Zuvano adds reminders you approve to Reminders.**

**Denied**

- Inline on Review + Open Settings.
- Drafts remain editable/skippable.
- Do not re-prompt in a loop.

**Photos**

- Prefer `PhotosPicker` (no library permission) for Choose Photo.

---

## 18. Error UX

| Kind | Presentation |
|---|---|
| Field validation | Inline under field / row footnote |
| Pipeline failure | S7 with Retry + Discard (+ Manual text for OCR) |
| Per-draft EventKit failure | Row status + Retry |
| Permission denied | Inline + Settings |
| Unsupported / invalid input | S7 or Home alert; Discard |

**Copy rules:** no blame, no “Oops,” no “We,” explain next step (HIG Writing).

---

## 19. Retry UX

| Failure | UI action | Re-enters |
|---|---|---|
| OCR | **Try Again** / **Enter Text** | extraction |
| Understanding | **Try Again** | understanding |
| Draft generation | **Try Again** | draft generation |
| EventKit | **Retry** on that row | that draft only |

Never Restart from scratch if `extractedText` already exists, unless the user Discards and starts a new capture.

---

## 20. Interrupted / recovery UX

On launch, if a draft is `executing`:

- With `nativeIdentifier` → mark Created (no EventKit call).
- Without → mark Couldn’t create / interrupted; copy: **Creation was interrupted. Retry when you’re ready.**
- **Never** auto-Retry EventKit.

If an intake was mid-processing and recovered as `failed`, show S7 with the correct failed stage.

---

## 21. Partial execution UX

- Keep the user on Action Review.
- Created rows stay Created; failed rows offer Retry; pending remain creatable.
- Toolbar reflects remaining ready drafts.
- **Done** stays disabled until every draft is terminal: Created, Skipped, or Failed with retry dismissed (user chooses **Dismiss** / Done path that accepts leaving failures), matching Data Model §9.1.
- Offer **Discard Remaining** only with confirmation if pending drafts would be lost.

---

## 22. Success UX

- Prefer quiet inline **Created** status over modal celebration.
- Light haptic on successful create (see §44).
- Accessibility announcement: e.g. **Added Meet at café to Calendar.**
- When all terminal: primary **Done** returns to Home and purges intake content per privacy rules.
- Optional: **Create Another** as secondary that Goes Home without implying archive.

---

## 23. Share Sheet UX (S9)

- Extension UI: minimal: system share sheet + brief **Opening Zuvano…** if a custom view is required.
- No understanding UI, no draft list, no EventKit in the extension.
- Main app opens into Processing for the handed-off intake.
- If handoff fails: Home alert **Couldn’t open that share. Try pasting the text instead.**

---

## 24. Image / OCR UX

- Choose Photo / shared image → Processing **Reading the screenshot…**
- OCR failure (S7):
  - Title: **Couldn’t read the screenshot**
  - Actions: **Try Again**, **Enter Text**, **Discard**
- Manual text: TextEditor → continues as successful extraction (image discarded).
- Do not keep showing the raw screenshot after successful OCR on Review (privacy); optional tiny “from screenshot” label is enough.

---

## 25. AI understanding UX

- Disclose on-device intelligence once, calmly, on Home or first Processing: **On-device. Your conversation stays on this iPhone.**
- During understanding: **Understanding the conversation…**
- Fallback path: same UI; do not say “AI unavailable” unless Retry needs it. Prefer **Couldn’t prepare actions** with Try Again.
- Never expose: model names, tokens, confidence scores, “hallucination,” engine kind, prompt text.
- Never present drafts as “messages from an assistant.”

---

## 26. Accessibility requirements

Design a11y into every screen (product FR / HIG Accessibility).

### VoiceOver

- Each draft row is **one** accessibility element when possible.
- Label pattern: **{Action kind}. {Title}. {When}. {Ambiguity or validation}. {State}.**
- Example: **Calendar event. Meet at café near campus. Friday about 7:00 PM. Check the time. Proposal.**
- Custom actions: **Create**, **Edit**, **Skip** / **Restore**, **Retry** as applicable.
- Selection mode: selection state must be distinct from Created.
- After Edit sheet dismisses, return focus to the edited row.
- Announce create success/failure.

### Traits & values

- Created: selected/summary value communicates completed create, not “selected for batch.”
- Progress: Updating trait / live region on Processing phase changes.
- Buttons: clear traits; disabled Create must explain why in the label or hint.

### Touch

- Minimum **44×44 pt** targets.
- Swipe actions are **secondary**; Create/Edit/Skip must also be available via buttons/menu for Switch Control / Full Keyboard Access.

### Reading order

- Header → draft list (top to bottom) → toolbar actions.
- Source sheet: title then text.

### Color independence

- State always includes text and preferably symbol.

---

## 27. Dynamic Type behavior

- Support all standard Dynamic Type sizes.
- Titles wrap; prefer multi-line titles over truncation.
- Source phrase may truncate visually; full string in accessibility value.
- Forms stack fields vertically; DatePickers remain usable at large sizes.
- Avoid fixed-height rows that clip content at accessibility sizes.
- Toolbar labels may shorten at large sizes (**Create** instead of long mixed labels) while VoiceOver keeps full wording.

---

## 28. Light / Dark appearance

- First-class for both appearances.
- Use semantic colors (`primary`, `secondary`, `tertiary`, `systemBackground`, `secondarySystemGroupedBackground`, tint).
- Do not hard-code pure black/white except where system semantics already do.
- Success/error use system green/red **plus** text.
- Test Review rows on both appearances for secondary footnote contrast.

---

## 29. Reduce Motion

When Reduce Motion is enabled:

- Prefer crossfade / opacity over slides and matched-geometry flourishes.
- Disable symbol bounce / large spring travel.
- Processing → Review: instant or short fade.
- Do not delay Create completion on animation.

Motion must never be the only signal of state change (pair with text/haptics carefully).

---

## 30. Reduce Transparency

- Fall back to opaque navigation/toolbars and solid grouped backgrounds.
- Do not rely on blur to separate hierarchy.
- Content list remains opaque in all cases.

---

## 31. Increase Contrast

- Stronger separators and borders where system increases contrast.
- Ambiguity / validation footnotes must remain readable (avoid ultra-light gray only).
- Provisional vs Created distinction must hold without low-contrast glass tricks.

---

## 32. Typography system

| Role | Style |
|---|---|
| Nav title | Large or inline `navigationTitle`: **Zuvano** / **Review** / **Edit Action** |
| Screen headline | `title2` / `title3` for empty states |
| Draft title | `body` emphasized or `headline` |
| Meta (when/where) | `subheadline` |
| Footnotes / source | `footnote` |
| Buttons | System button text styles |

**Font:** SF system; no custom display font for MVP.  
**Capitalization:** Sentence case for headlines and most buttons; Title Case only for short nav titles if matching system norms.

---

## 33. Color system

| Role | Token |
|---|---|
| Content background | System grouped background |
| Row background | Secondary grouped / system |
| Primary text | `.primary` |
| Secondary text | `.secondary` |
| Tint / primary actions | App accent (single calm accent; prefer system blue or a restrained brand tint; **not** neon purple/cyan AI cliché) |
| Success | System green + **Created** text |
| Destructive / skip discard | System red for Discard intake; Skip is not destructive red by default |
| Warning / attention | System orange optional for missing fields; always with text |

One accent. Do not rainbow-code AI states.

---

## 34. Spacing system

Use system spacing rhythms:

- List: default inset grouped margins.
- Form: default Form section spacing.
- Empty states: generous vertical padding (~24–40 pt) around symbol + text + button.
- Footnotes: 4–8 pt below meta line.
- Avoid custom micro-grids that fight `List`/`Form`.

---

## 35. Corner-radius system

- Prefer **system** list/form/sheet radii.
- Custom cards (if any, discouraged): align to continuous corners ~12–16 pt.
- Do not invent pill-heavy AI chips for every meta field.

---

## 36. Iconography

- SF Symbols only.
- Prefer hierarchical / monochrome rendering; match text weight.
- Avoid custom illustrated mascots for MVP.

---

## 37. SF Symbols usage

| Meaning | Suggested symbols |
|---|---|
| Calendar draft / created | `calendar`, `calendar.badge.checkmark` |
| Reminder draft / created | `checklist`, `checkmark.circle` |
| Paste | `doc.on.clipboard` |
| Photo | `photo.on.rectangle` |
| Share hint | `square.and.arrow.up` |
| Processing | System `ProgressView` |
| Ambiguity / attention | `exclamationmark.circle` (or none; prefer text) |
| Failure | `exclamationmark.triangle` |
| Settings | `gear` / Open Settings via UIApplication |
| Source text | `text.alignleft` / `doc.plaintext` |
| Skip | `xmark` |
| Restore | `arrow.uturn.backward` |

Animate symbols sparingly; respect Reduce Motion.

---

## 38. Materials / Liquid Glass usage

Follow Apple’s two-layer model:

| Layer | Zuvano rule |
|---|---|
| **Functional** (nav bar, toolbar, sheets, system alerts) | Allow system Liquid Glass via standard components |
| **Content** (list rows, draft content, backgrounds, empty states) | **No** Liquid Glass / `.glassEffect` / frosted draft cards |

**Absolute ban**

- Glass “proposal cards”
- Glass chat bubbles
- Glass floating FABs as the visual identity
- Stacking custom glass on glass in content

Reduce Transparency → opaque chrome. Clear glass only if ever used over rich media (not needed for MVP Review).

---

## 39. Component patterns

| Need | Component |
|---|---|
| Draft list | `List` inset grouped |
| Edit fields | `Form` + system controls |
| Empty / error | `ContentUnavailableView` |
| Progress | `ProgressView` + text |
| Photo | `PhotosPicker` |
| Paste | Button reading `UIPasteboard` (with availability) |
| Permission | Pre-alert → system alert |
| Destructive discard | Confirmation dialog |
| Batch select | Edit/Select mode with leading selection |

Prefer semantic system controls over custom gesture-only UI.

---

## 40. Button hierarchy

| Priority | Examples | Style |
|---|---|---|
| Primary | Create / Create N Ready / Done (terminal) | `.borderedProminent` or glass prominent on chrome if system default |
| Secondary | Select, View source, Enter Text, Try Again | `.bordered` / plain |
| Tertiary | Skip, Restore | Plain; Skip via swipe |
| Destructive | Discard conversation / Discard intake | Destructive role |

**One** prominent create action per view region. Do not tint every toolbar item.

---

## 41. Sheets

| Sheet | Detents | Dismiss |
|---|---|---|
| Edit Draft | medium/large as needed | Swipe / Cancel / Save |
| Source Text | medium/large | Swipe / Done |
| Permission pre-alert | Prefer compact custom view or alert-style card; keep short | Continue only |

If dismissing Edit would lose unsaved field edits, confirm before discard.

---

## 42. Alerts

Use alerts for:

- Discard intake (data loss)
- Cancel processing when work would be lost
- Rare critical failures

Do not alert for routine Created success.

---

## 43. Confirmation dialogs

Use confirmation dialogs / action sheets for:

- Discard intake
- Optional ambiguous create confirmation (if used)
- Dismiss remaining failed retries

Keep titles specific: **Discard this conversation?** Actions: **Discard**, **Keep Reviewing**.

---

## 44. Haptics

| Event | Haptic |
|---|---|
| Successful create | Light success / soft impact |
| Failed create | Warning / error notification haptic |
| Skip | None or very light selection |
| Processing complete → Review | Optional soft selection |

Never spam haptics per OCR frame or token. Always pair important haptics with accessible text feedback.

---

## 45. Animation and transitions

**Purpose of motion:** causality, state change, hierarchy, continuity, not decoration.

| Transition | Prefer |
|---|---|
| Processing → Review | Short shared fade / slide; Reduce Motion → fade/instant |
| Row insert | System list insertion |
| State change Creating → Created | Content transition / opacity |
| Sheet present | System sheet |

Avoid continuous ambient motion, parallax orbs, and long staged “AI thinking” choreography.

---

## 46. Keyboard / focus behavior

- Edit Draft: focus title field on appear when title empty or invalid.
- Manual OCR text entry: focus TextEditor on appear.
- Keyboard dismiss on Save / tap outside where appropriate.
- Full Keyboard Access: all Create/Edit/Skip/Done reachable.
- After sheet dismiss: restore VO/keyboard focus to the related row.

---

## 47. Copywriting principles

- Voice: calm, precise, trustworthy.
- Tone: direct in errors; quiet in success.
- Active voice; sentence case.
- Avoid “we,” “oops,” “AI magic,” “smart,” “agent.”
- Prefer **Create** over Confirm in UI.
- Prefer **Skip** over Reject in UI (maps to `rejected`).
- Prefer **Proposal** language over “AI output.”
- Privacy line: **On-device. Your conversation stays on this iPhone.**

---

## 48. UI terminology glossary

| UI term | Meaning |
|---|---|
| Proposal / Proposed action | Action Draft pending create |
| Create | User authorizes EventKit write |
| Skip | Reject draft (`rejected`) |
| Restore | `rejected → pending` |
| Created | `executed` with native id |
| Couldn’t create | Execution failed or interrupted |
| Review | Action Review screen |
| Source | Extracted text for this intake |
| Discard | Cancel intake and purge |

**Do not use in UI:** Intent, Confidence, Engine, Fallback, Hallucination, Pipeline, Orchestrator, ActionDraft (type name).

---

## 49. Error copy (canonical)

| Situation | Title | Description / action |
|---|---|---|
| OCR fail | **Couldn’t read the screenshot** | Try Again · Enter Text · Discard |
| Understanding fail | **Couldn’t prepare actions** | Try Again · Discard |
| Draft generation fail | **Couldn’t prepare actions** | Try Again · Discard |
| Invalid input | **That content can’t be used** | Try something else · Discard |
| Calendar create fail | **Couldn’t add to Calendar** | Retry |
| Reminder create fail | **Couldn’t add to Reminders** | Retry |
| Interrupted | **Creation was interrupted** | Retry when you’re ready |
| Permission denied | **Calendar access is off** / **Reminders access is off** | Open Settings |
| Missing start | **Add a start time to create this event.** | (inline) |
| Batch partial ready | **Create 3 Ready** | **2 need a start time.** |

---

## 50. Accessibility copy

- Hints sparingly: e.g. Create button hint **Adds this item to Calendar** / **Adds this item to Reminders**.
- Avoid hint that duplicates the label.
- Announcements: **Added {title} to Calendar.** / **Couldn’t add {title}.**
- Processing: **Understanding the conversation…** as the accessible value of the progress region.

---

## 51. Visual consistency rules

1. One accent color.
2. System List/Form language everywhere possible.
3. Proposals never wear success checkmarks.
4. Created is the only “done” checkmark state.
5. Ambiguity is text, not a confidence bar.
6. Glass stays on chrome, not content.
7. Empty and error states share the same quiet layout language.
8. Icons from SF Symbols only; consistent weight.
9. Margins follow system grouped lists.
10. Light and Dark both intentional, not inverted afterthoughts.

---

## 52. Anti-patterns: Zuvano must NOT do

1. Chat transcript UI or message bubbles for drafts.
2. Floating AI orb / glow / neon gradients as brand identity.
3. Dashboard of stats, streaks, or “insights.”
4. Browsable conversation archive / history inbox.
5. Trailing checkmarks meaning “selected” on proposals.
6. Soft **Confirm** that doesn’t say Calendar/Reminders will be written.
7. Auto-creating events when OCR/understanding finishes.
8. Auto-retrying EventKit after interrupt recovery.
9. Confidence meters, token counts, model badges.
10. Glass cards for each draft.
11. Tab bar with Memory / Chat / Settings for MVP.
12. Reading existing Calendar/Reminder items to “dedupe.”
13. Implying cloud AI processing.
14. Color-only success/failure.
15. Done that purges pending drafts without Discard confirmation.
16. Exposing Intent lists separate from Action Drafts.
17. Permission Allow button on a custom pre-alert (use Continue).
18. Third-party UI kits or illustration-heavy onboarding carousels for MVP.

---

## 53. Visual QA checklist

Before considering UI complete:

### Product / trust

- [ ] No draft looks Created before `executed`
- [ ] Create copy names Calendar and/or Reminders
- [ ] Independent draft states work in one list
- [ ] Ambiguous ~time can create; missing start cannot
- [ ] Interrupted draft never auto-creates
- [ ] Done disabled until terminal (or Discard confirmed)
- [ ] No history/archive surface

### Native / visual

- [ ] System List/Form/Navigation look native on iOS 26/27
- [ ] No content-layer Liquid Glass
- [ ] Light and Dark both reviewed
- [ ] Increase Contrast / Reduce Transparency reviewed
- [ ] Accent restrained; not neon-AI

### Motion / haptics

- [ ] Reduce Motion honored
- [ ] Motion not required to understand state
- [ ] Haptics paired with accessible feedback

### Accessibility

- [ ] VoiceOver reads each draft coherently
- [ ] Custom actions Create/Edit/Skip available
- [ ] Dynamic Type at largest sizes usable
- [ ] 44 pt targets
- [ ] Focus returns after sheets
- [ ] Status not color-only
- [ ] Processing phase announced

### States

- [ ] Home empty
- [ ] Processing phases
- [ ] OCR fail + manual text
- [ ] Understanding fail
- [ ] Nothing actionable
- [ ] Review multi-draft
- [ ] Edit sheet
- [ ] Permission deny
- [ ] Partial create success/fail
- [ ] Share handoff into Processing
- [ ] Discard / Done purge behavior

---

## 54. Locked UX decisions (implementation contract)

These resolve ambiguities left by product docs for UI only:

1. **No Tab Bar** in MVP.
2. **Action Review = inset grouped List** of proposals.
3. **UI verb is Create**, not Confirm.
4. **One create path:** validate → confirm state → permission → execute.
5. **Batch selection uses Select mode with leading selection**; never trailing ✓ on proposals.
6. **Skip** is the user-facing term for reject; **Restore** undoes Skip.
7. **Done** only when intake is terminal; otherwise Discard with confirmation.
8. **Source peek sheet** allowed for current intake only, not an archive.
9. **Liquid Glass only via system chrome**; ban content glass.
10. **Share Extension** shows minimal opening UI; Review always in main app.
11. **Home** leads with one sentence + Paste + Photo + Share hint.
12. **Confidence scores are never shown.**

---

## 55. Unresolved / validate on device

| Item | Notes |
|---|---|
| Exact EventKit “Open in Calendar/Reminders” deep link behavior | Optional nicety; not required for MVP trust |
| Share Extension custom UI vs system-only | Keep minimal; device-validate handoff timing |
| Whether ambiguous create needs an extra dialog | Default: **no** dialog if About footnote is visible; add only if usability testing shows accidental creates |
| App accent color final brand value | Choose one restrained system-compatible tint at visual design time |
| Large Content Viewer / accessibility sizes for mixed toolbar labels | Shorten visually; keep full VO string |

---

## Document history

| Version | Notes |
|---|---|
| 1.0 | Initial authoritative UI/UX instructions after product-doc alignment and iOS design review |
