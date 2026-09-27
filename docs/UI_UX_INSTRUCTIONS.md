# Zuvano: UI/UX Instructions

> **Authoritative UI/UX specification for implementation.**
>
> This document defines Zuvano's visual design language, interaction design, information architecture, accessibility, motion, and UI copy.
>
> **Authority:** Product → Feature → Architecture → Data Model → Technical Decisions → this UI/UX document.
>
> This document does **not** define SwiftUI source code, view-file structure, or implementation details beyond UI behavior and design tokens.
>
> **Design direction locked in this version:** **Native Apple × Calm Intelligence × Soft Precision.**
>
> Zuvano should feel like an Apple utility with a hint of intelligence. The intelligence is in what Zuvano understands, not in how loudly the interface advertises AI.

---

## 0. Platform & constraints

| | |
|---|---|
| Platform | iPhone only |
| Framework | SwiftUI |
| Deployment | iOS 26.0 |
| Development / test | iOS 27 |
| Dependencies | Apple frameworks only; no third-party UI/dependencies |
| Design references | Apple HIG; native iOS controls and Liquid Glass |
| Visual target | Native, calm, precise, premium, restrained |

Zuvano is **not**:

- a chatbot
- a memory/retrieval app
- a messaging client
- a calendar replacement
- a generic task manager
- an AI dashboard
- a SaaS console
- a conversation archive
- a floating-orb assistant

### Core experience

```text
Conversation
    ↓
Understanding
    ↓
Action proposals
    ↓
User review / edit
    ↓
Explicit Create
    ↓
Native iOS Calendar / Reminder action
```

### Core trust boundary

> **Zuvano suggests → I review/edit → I create → iOS writes the action.**

Zuvano must never imply that an action already exists in Calendar or Reminders until EventKit execution succeeds.

---

# 1. Design language

## 1.1 North star

### **Native Apple × Calm Intelligence × Soft Precision**

The product should feel:

- native
- calm
- intelligent
- precise
- trustworthy
- lightweight
- purposeful
- human
- premium
- private

The user should think:

> “This is simple. It understands what I need. I can trust it.”

Not:

> “This is an AI app.”

---

## 1.2 Brand-to-product ratio

Target approximately:

```text
90% Apple / native iOS
10% Zuvano
```

### Zuvano's 10%

- logo
- Zuvano accent
- restrained gradient
- copy
- subtle brand moments
- overall visual personality

### Apple's 90%

- navigation
- Lists
- Forms
- Sheets
- buttons
- typography
- system colors
- SF Symbols
- accessibility behavior
- system materials
- interaction conventions

Do not create custom UI merely to make the app look different.

---

# 2. Logo and brand identity

The Zuvano logo establishes the brand personality:

- rounded geometric Z
- white mark
- violet → periwinkle → blue gradient
- soft, modern geometry

The logo gradient is a **brand asset**, not the application's default UI color.

## 2.1 Logo gradient

```text
Violet       #A681FE
Periwinkle   #7C7CFC
Blue         #515FFD
```

Use this for:

- app icon
- marketing material
- onboarding/launch artwork if required
- occasional subtle brand moments

Do **not** use it for:

- every button
- list backgrounds
- draft cards
- navigation bars
- every icon
- gradient text
- glass surfaces
- decorative AI effects

---

# 3. Color system

## 3.1 Base UI

Use semantic iOS colors wherever possible.

### Light appearance

```text
Background                    systemGroupedBackground
Secondary background          secondarySystemGroupedBackground
Primary text                  primary
Secondary text                secondary
Tertiary text                 tertiary
Separator                     separator
```

Do not hard-code pure black/white for normal content.

### Dark appearance

Use the corresponding semantic system colors.

Dark mode is a first-class design, not a light-mode inversion.

---

## 3.2 Zuvano accent

### **Zuvano Indigo**

```text
#6366F1
RGB 99 / 102 / 241
```

This is the single custom application accent.

Use it for:

- primary actions
- selected/focused controls
- interactive links
- important active states
- subtle selection tint
- focused text cursor where appropriate
- restrained brand moments

Do not use it as a full-screen background or on every element.

### Accent philosophy

```text
Zuvano Indigo
      ↓
Primary interaction
      ↓
Selected / focused
      ↓
Subtle active state
```

The interface must remain predominantly neutral.

---

## 3.3 Semantic colors

### Success

Use system green.

Only use success styling when EventKit execution has actually succeeded.

Example:

```text
✓ Created
```

### Warning

Use system orange sparingly for attention states.

Always pair with text and/or symbol.

### Error

Use system red for:

- failed creation
- pipeline failure
- destructive discard

### Important rule

**State is never communicated through color alone.**

Always combine:

```text
symbol + text + semantic color
```

---

# 4. Visual hierarchy

Every screen should follow:

```text
Brand / Context
      ↓
Primary content
      ↓
Supporting information
      ↓
Action
```

The interface should not feel like a dashboard.

Avoid:

- statistics
- confidence scores
- model labels
- AI status chips
- decorative metrics
- excessive badges
- “AI detected” banners

---

# 5. Typography

## 5.1 Font

Use the system SF font.

No custom display font for MVP.

SwiftUI system typography should be preferred over hard-coded font sizes.

---

## 5.2 Type hierarchy

| Role | Style |
|---|---|
| Navigation title | Large / inline system navigation title |
| Screen headline | `title2` / `title3` |
| Draft title | `headline` or emphasized `body` |
| Metadata | `subheadline` |
| Supporting/source text | `footnote` |
| Button labels | System button styles |

### Typography rules

- Sentence case for normal copy.
- Keep titles short and readable.
- Allow wrapping.
- Never sacrifice accessibility for fitting text on one line.
- Avoid oversized “AI” marketing typography inside the app.

---

# 6. Spacing system

Use Apple's spacing rhythm.

```text
4
8
12
16
20
24
32
40
```

Most custom spacing should live around:

```text
16 / 20 / 24 pt
```

Do not create arbitrary micro-grids.

Prefer system List/Form spacing when available.

---

# 7. Corner radius and geometry

Zuvano uses soft geometry without turning everything into a pill.

### Rules

- Prefer system component radii.
- Custom surfaces: approximately 12–16 pt continuous corners.
- System sheets and controls use native iOS geometry.
- Avoid excessive capsules.
- Avoid rounded cards nested inside rounded cards.

The logo is rounded; the entire application does not need to become a collection of pills.

---

# 8. Iconography

Use **SF Symbols only**.

No third-party icon sets.

Prefer monochrome or hierarchical rendering that matches surrounding text.

### Core symbols

| Meaning | Symbol |
|---|---|
| Calendar | `calendar` |
| Calendar created | `calendar.badge.checkmark` |
| Reminder | `checklist` |
| Created | `checkmark.circle.fill` |
| Paste | `doc.on.clipboard` |
| Photo | `photo.on.rectangle` |
| Share | `square.and.arrow.up` |
| Processing | system `ProgressView` |
| Attention | `exclamationmark.circle` |
| Failure | `exclamationmark.triangle` |
| Retry | `arrow.clockwise` |
| Skip | `xmark` |
| Restore | `arrow.uturn.backward` |
| Source | `doc.plaintext` / `text.alignleft` |
| Settings | `gear` |

Do not use colorful icon illustrations as the product identity.

---

# 9. Materials and Liquid Glass

Zuvano follows a strict two-layer model.

| Layer | Rule |
|---|---|
| Functional chrome | Native Liquid Glass/system materials are allowed |
| Content | Solid/semantic system surfaces; no custom glass |

## Functional layer

Liquid Glass may appear naturally through:

- navigation bars
- toolbars
- system sheets
- system alerts
- native system controls

## Content layer

Do **not** use Liquid Glass for:

- draft cards
- proposal rows
- chat bubbles
- content backgrounds
- floating AI panels
- glass FABs
- source text content

### Principle

> **iOS provides the glass. Zuvano provides the content.**

If Reduce Transparency is enabled, chrome must remain usable with opaque system surfaces.

---

# 10. Information architecture

```text
Home / Capture
    └─ Processing
         └─ Action Review
              ├─ Edit Draft sheet
              ├─ Source Text sheet
              ├─ Permission pre-alert
              └─ Per-draft execution feedback
```

## Out of MVP

- tab bar
- conversation archive
- chat thread
- intent browser
- model/debug screens
- confidence screens
- Calendar browsing
- duplicate detection UI
- memory/history UI
- generic settings dashboard

---

# 11. Navigation architecture

| Decision | Choice |
|---|---|
| Root | `NavigationStack` |
| Tabs | None |
| Capture → Processing | Active intake destination |
| Processing → Review | Animated transition |
| Edit Draft | Sheet |
| Source Text | Sheet |
| Return Home | Explicit Done when terminal |
| Abandon intake | Discard with confirmation |

Prefer sheets for narrowly scoped tasks.

Do not create deep navigation hierarchies for editing one action.

---

# 12. Screen inventory

| ID | Screen | Purpose |
|---|---|---|
| S1 | Home / Capture | Start an intake |
| S2 | Processing | OCR / understanding / draft generation |
| S3 | Action Review | Inspect, edit, skip, create |
| S4 | Edit Draft | Correct fields before creation |
| S5 | Source Text | Read-only source peek |
| S6 | Nothing Actionable | Valid result with no actionable drafts |
| S7 | Pipeline Failure | Recover from failed processing |
| S8 | Permission Pre-alert | Explain upcoming system permission |
| S9 | Share Extension | Capture-only handoff |

---

# 13. State architecture

## 13.1 Intake presentation states

| UI state | When | Screen |
|---|---|---|
| `idle` | No active intake | S1 |
| `processing` | Intake is being imported/understood/generated | S2 |
| `review` | Ready with ≥1 draft | S3 |
| `emptyActionable` | Ready with no drafts | S6 |
| `pipelineFailed` | Intake failed | S7 |
| `permissionNeeded` | Permission required during Review | Inline/banner on S3 |

---

## 13.2 Draft presentation states

| UI label | Underlying state | Visual |
|---|---|---|
| Proposal | pending + notStarted | Normal provisional row |
| Needs attention | pending + invalid required fields | Inline validation |
| About… | ambiguous with required values present | Human-readable ambiguity footnote |
| Skipped | rejected | Dimmed + Restore |
| Creating… | confirmed + executing | Inline progress; never success |
| Waiting for access | confirmed + notStarted + permission denied | Access message + Open Settings |
| Created | confirmed + executed | Success text + check symbol |
| Couldn't create | confirmed + failed | Error text + Retry |

Never show a long-lived “Confirmed” badge.

---

# 14. Selection mode

Batch selection must be visually distinct from creation success.

### Rules

- Enter Select from toolbar.
- Use **leading** selection controls.
- Never use trailing checkmarks to mean “selected.”
- Trailing checkmarks are reserved for **Created**.
- Exit Select mode after the create attempt or Cancel.

Selection is not execution.

---

# 15. Home / Capture — S1

## Purpose

The Home screen is intentionally minimal.

### Content

```text
Zuvano

Turn a conversation into
Calendar events and Reminders.

[ Paste ]

[ Choose Photo ]

[ Enter Text ]

Or share text or a screenshot to Zuvano
from another app.

On-device. Your conversation stays on this iPhone.
```

### Action hierarchy

**Primary**

- Paste

**Secondary**

- Choose Photo
- Enter Text

**Supporting**

- Share hint

### Visual treatment

- Neutral system grouped background.
- Large but restrained Zuvano title.
- No giant logo dominating the screen.
- A subtle Zuvano Indigo/gradient brand moment is acceptable.
- Buttons should use native system hierarchy rather than custom neon gradients.
- Do not turn the home screen into an AI landing page.

### Important

The app must retain all three capture paths:

- Paste
- Choose Photo
- Enter Text

Share Sheet remains an additional capture path.

---

# 16. Processing — S2

Processing is temporary and calm.

### Header

```text
Cancel                 Processing
```

### Center

Use system `ProgressView`.

Status changes by phase:

| Phase | Copy |
|---|---|
| Text extraction | **Reading text…** |
| Image extraction | **Reading the screenshot…** |
| Understanding | **Understanding the conversation…** |
| Draft generation | **Preparing actions…** |

### Rules

Do not use:

- AI orb
- glowing sphere
- chat bubbles
- typing indicator
- token streams
- shimmer effects
- fake transcript
- animated AI logo
- model name
- confidence score

Processing should communicate:

> “Work is happening.”

Not:

> “Look at our AI.”

---

# 17. Enter Text — capture UI

Manual text entry is a first-class capture path.

### Header

```text
Cancel                  Enter Text
```

### Primary content

A large native text editor with comfortable margins.

### Empty helper copy

> **Paste or type the conversation. Zuvano will read this text instead of the screenshot.**

### Continue

Disabled until usable text exists.

Once text is entered:

> **Continue**

becomes the primary action.

### Keyboard

Use the system keyboard.

Do not attempt to recreate or style the keyboard.

### Focus

TextEditor should receive focus when the screen appears.

---

# 18. Source Text — S5

Source is evidence, not a conversation UI.

### Presentation

Native sheet.

### Header

```text
Source                         Done
```

### Content

Read-only extracted text.

Example:

> “Yeah Friday works. Let's meet around 7 at the café. Remind me Thursday to call Arjun.”

### Rules

- No chat bubbles.
- No sender avatars.
- No AI annotations.
- No intent highlights.
- No confidence markers.
- No conversation history.
- Source belongs only to the current intake.

The source sheet should feel like a simple document/text peek.

---

# 19. Action Review — S3

## This is the product's primary surface.

The screen answers:

> **“What did Zuvano find that I might want to do?”**

### Header

```text
Cancel                    Review
```

or the native navigation equivalent.

### Context line

```text
2 proposed actions                         View source
```

The count refers to proposals that have not yet been executed.

Do not label executed items as “proposed.”

---

# 20. Review list design

Use a native **inset grouped List**.

This is the primary visual decision for Review.

### Do not use

- dashboard cards
- giant floating cards
- glass proposal cards
- AI panels
- neon backgrounds
- decorative gradient containers

### Use

- native List
- semantic system backgrounds
- system separators
- comfortable row spacing
- SF Symbols
- clear hierarchy

---

# 21. Draft row anatomy

Each proposal communicates:

```text
Action type
Title
When
Where / Who
Source phrase
Ambiguity or validation if needed
Available interaction
Execution state
```

### Example Calendar proposal

```text
[calendar]  Meet at the café
             Friday · About 7:00 PM
             Café near campus

             “Let's meet around 7…”

             About 7:00 PM, check before creating.
```

### Example Reminder

```text
[checklist]  Call Arjun
             Thursday

             “Also remind me Thursday…”
```

---

# 22. Row interaction model

| Gesture | Result |
|---|---|
| Tap row | Open Edit Draft |
| Swipe trailing | Skip |
| Swipe leading | Edit, optional |
| Context menu | Create / Edit / Skip / Restore / Source as applicable |
| Toolbar Select | Batch selection |

Do not put three equally prominent buttons on every row.

Prefer:

```text
Tap → Edit
Swipe/menu → Skip
Toolbar → Create All Ready
```

A single-draft intake may expose a prominent Create action.

---

# 23. Proposal visual language

A proposal is provisional.

### Proposal

- normal row background
- normal primary title
- secondary metadata
- leading SF Symbol
- no green check
- no “Created” text
- no success tint
- no celebration

### Created

Only after EventKit succeeds:

```text
✓ Created
```

with system green + text + symbol.

### Skipped

```text
Skipped
Restore
```

with reduced emphasis.

### Failed

```text
Couldn't create
Retry
```

with clear error styling.

---

# 24. Ambiguity

Ambiguity should be expressed in plain language.

Example:

> **About 7:00 PM, check before creating.**

Do not display:

- confidence percentages
- confidence bars
- AI scores
- probability meters
- “94% sure”
- model reasoning

### Rule

Approximation is not the same as missing data.

If a concrete value is visible and usable, the draft can be created.

---

# 25. Missing required data

For a Calendar event without a start:

> **Add a start time to create this event.**

Create is disabled for that draft.

Do not hide the draft.

Do not silently infer a date/time.

---

# 26. Batch creation

### All ready

If every pending valid draft can be created:

```text
Create 2 Items
```

or, for a mixed batch:

```text
Create 1 Event & 1 Reminder
```

### Partial readiness

If some drafts are invalid:

```text
Create 3 Ready
```

with supporting text:

> **2 need a start time.**

Do not silently skip invalid drafts.

### Selected

In Select mode:

```text
Create Selected (2)
```

Selection controls are leading.

---

# 27. Create interaction

Create is the trust boundary.

### Single-draft flow

```text
Create
  ↓
Validate
  ↓
confirmed
  ↓
Permission if needed
  ↓
executing
  ↓
EventKit
  ↓
Created / Couldn't create
```

### UI terminology

Use:

- Create
- Add to Calendar
- Add Reminder
- Create N Items
- Skip
- Restore
- Retry

Do not use:

- Confirm
- Approve
- Accept
- Execute
- Run AI
- Generate

---

# 28. Calendar action UX

### Leading symbol

`calendar` / `calendar.badge.plus`

### Create wording

Use:

- **Add to Calendar**
- **Create Event**

depending on context.

### Requirements

A Calendar draft must have a visible start date/time.

If end is missing, product-defined default duration may be applied.

### After execution

Show:

```text
Created
```

with a success symbol.

Optional:

> Open in Calendar

only if a supported system deep link is available.

Do not read existing Calendar events for duplicate detection.

---

# 29. Reminder action UX

### Leading symbol

`checklist` / `reminder.bell`

### Create wording

Use:

- **Add Reminder**
- **Create Reminder**

Due date is optional.

If absent:

> No due date

may be shown as secondary metadata.

After execution:

```text
Created
```

Optional:

> Open in Reminders

if supported.

Do not read existing Reminders for duplicate detection.

---

# 30. Mixed batches

For mixed Calendar + Reminder batches, the primary action should clearly describe both stores.

Example:

```text
Create 2 Events & 1 Reminder
```

If the label becomes too long at large Dynamic Type sizes, visually shorten it to:

```text
Create
```

while VoiceOver retains the full semantic label.

---

# 31. Edit Draft — S4

Edit is a native sheet.

### Header

```text
Cancel                 Edit Action
```

### Form fields

| Field | Control |
|---|---|
| Title | TextField |
| Type | Picker: Calendar Event / Reminder |
| Starts | DatePicker |
| Ends | DatePicker |
| Due | DatePicker |
| Location | TextField |
| Person | TextField |
| Notes | TextField / TextEditor |
| Original phrasing | Read-only footnote where useful |

### Rules

- Save/Done only updates the draft.
- It never writes to EventKit.
- Validate again before Create.
- Changing Reminder → Calendar requires a start date before creation.
- Clearing a Calendar start disables Create.
- Resolving ambiguity sets `ambiguous = false`.

Use a native `Form`.

---

# 32. Permission UX

Request Calendar/Reminders permission lazily when the user first chooses Create.

### Optional pre-alert

Explain the benefit briefly.

Example:

> **Calendar access**  
> Zuvano adds events you approve to Calendar.

Button:

> **Continue**

Then show Apple's system permission prompt.

Do not use a custom “Allow” button that imitates the system prompt.

### Denied

Show inline:

> **Calendar access is off.**

with:

> **Open Settings**

Do not repeatedly prompt.

Drafts remain editable and skippable.

---

# 33. Success UX

Success should be quiet.

### Created row

```text
Meeting
Friday · 7:00 PM
Café near campus

✓ Created
```

Use:

- system green
- `checkmark.circle.fill`
- subtle state transition
- optional light success haptic
- VoiceOver announcement

Do not use:

- confetti
- full-screen celebration
- giant green cards
- fireworks
- animated success logos

### Accessibility announcement

Example:

> **Added Meet at the café to Calendar.**

---

# 34. Partial execution

Created, failed, skipped, and pending drafts can coexist.

Example:

```text
✓ Created
Couldn't create   Retry
Skipped            Restore
Proposal
```

Keep the user on Review.

The toolbar reflects remaining actionable drafts.

Do not hide successful rows immediately.

---

# 35. Done behavior

Done means the intake is terminal.

A terminal intake has no unresolved work.

Depending on product state, drafts are:

- Created
- Skipped
- Failed with retry dismissed / accepted as terminal

### Important

Done must not silently destroy pending work.

If unresolved drafts would be lost:

> **Discard remaining?**

Actions:

- Discard
- Keep Reviewing

Once terminal:

> **Done**

returns Home and purges the intake according to the privacy/data rules.

---

# 36. Skipped state

Skipped is not deletion.

### Visual

- reduced emphasis
- text: **Skipped**
- action: **Restore**

### Restore

Restores:

```text
rejected → pending
```

A skipped proposal remains recoverable until the intake is purged.

---

# 37. Interrupted execution

If a draft was executing when the app was interrupted:

### If nativeIdentifier exists

Treat as Created.

### If nativeIdentifier does not exist

Show:

> **Creation was interrupted. Retry when you're ready.**

Never automatically retry EventKit.

---

# 38. Empty / Nothing Actionable — S6

This is a valid result, not an error.

Use a quiet native empty state.

### Title

> **Nothing to create**

### Description

> **Zuvano didn't find anything for you to add to Calendar or Reminders.**

### Action

> **Done**

Do not say:

- AI failed
- No intent detected
- Confidence too low
- Nothing smart found

---

# 39. Pipeline failure — S7

Use a native, calm recovery surface.

## OCR failure

### Title

> **Couldn't read the screenshot**

Actions:

- Try Again
- Enter Text
- Discard

## Understanding / draft generation failure

### Title

> **Couldn't prepare actions**

Actions:

- Try Again
- Discard

Never expose model internals.

---

# 40. Retry behavior

| Failure | Action | Re-entry |
|---|---|---|
| OCR | Try Again | Extraction |
| OCR | Enter Text | Manual text |
| Understanding | Try Again | Understanding |
| Draft generation | Try Again | Draft generation |
| EventKit | Retry | That draft only |

If extracted text already exists, do not restart from scratch unnecessarily.

---

# 41. Image / OCR UX

Choose Photo or share an image.

Processing:

> **Reading the screenshot…**

On failure:

> **Couldn't read the screenshot**

Actions:

- Try Again
- Enter Text
- Discard

After successful OCR, do not keep displaying the raw screenshot in Review.

The source text is sufficient.

---

# 42. Share Sheet UX

The Share Extension is capture-only.

Do not perform:

- understanding
- draft generation
- EventKit writes

inside the extension.

Minimal handoff:

> **Opening Zuvano…**

Then the main app opens into Processing.

If handoff fails:

> **Couldn't open that share. Try pasting the text instead.**

---

# 43. On-device intelligence disclosure

Disclose calmly.

Preferred Home copy:

> **On-device. Your conversation stays on this iPhone.**

During processing use only phase copy:

- Reading…
- Understanding…
- Preparing actions…

Never expose:

- model name
- token count
- prompt
- confidence score
- engine name
- orchestration details
- hallucination terminology

---

# 44. Copywriting principles

Voice:

- calm
- precise
- direct
- trustworthy
- human

Avoid:

- “AI magic”
- “smart”
- “agent”
- “we”
- “oops”
- “amazing”
- “intelligent assistant”
- model jargon

### Core terminology

| UI term | Meaning |
|---|---|
| Proposal / Proposed action | Action Draft pending creation |
| Create | User authorizes EventKit write |
| Skip | Reject draft |
| Restore | Undo Skip |
| Created | EventKit execution succeeded |
| Couldn't create | EventKit execution failed |
| Review | Action Review screen |
| Source | Extracted text |
| Discard | Cancel intake and purge |

Do not use in UI:

- Intent
- Confidence
- Engine
- Fallback
- Pipeline
- Orchestrator
- ActionDraft
- Hallucination

---

# 45. Canonical error copy

| Situation | Title / Copy | Action |
|---|---|---|
| OCR failure | **Couldn't read the screenshot** | Try Again · Enter Text · Discard |
| Understanding failure | **Couldn't prepare actions** | Try Again · Discard |
| Draft generation failure | **Couldn't prepare actions** | Try Again · Discard |
| Invalid input | **That content can't be used** | Try something else · Discard |
| Calendar failure | **Couldn't add to Calendar** | Retry |
| Reminder failure | **Couldn't add to Reminders** | Retry |
| Interrupted | **Creation was interrupted** | Retry |
| Calendar permission | **Calendar access is off** | Open Settings |
| Reminder permission | **Reminders access is off** | Open Settings |
| Missing start | **Add a start time to create this event.** | Inline |
| Partial batch | **Create 3 Ready** | Supporting: **2 need a start time.** |

No blame, no dramatization, no vague error language.

---

# 46. Accessibility

Accessibility is part of the visual design, not a later pass.

## VoiceOver

Each draft should preferably be one coherent accessibility element.

Example:

> **Calendar event. Meet at café near campus. Friday about 7:00 PM. Check the time. Proposal.**

Available custom actions:

- Create
- Edit
- Skip
- Restore
- Retry

### Created

Accessibility state must communicate **created**, not selected.

### Processing

Announce phase changes politely.

---

# 47. Touch targets

Minimum:

**44 × 44 pt**

Swipe actions are secondary.

Create/Edit/Skip must remain accessible through explicit controls or menus for:

- Switch Control
- VoiceOver
- Full Keyboard Access

---

# 48. Dynamic Type

Support all standard Dynamic Type sizes.

Rules:

- Titles wrap.
- Draft titles wrap.
- Never clip text to preserve a fixed-height aesthetic.
- Forms stack naturally.
- Toolbar labels may shorten visually at large sizes.
- VoiceOver keeps full semantic labels.

Avoid fixed-height custom cards.

---

# 49. Dark mode

Dark mode must be deliberately designed.

Use:

- semantic system backgrounds
- semantic text colors
- system separators
- system green/red/orange
- Zuvano Indigo as a restrained accent

The logo gradient remains a brand asset.

Do not simply invert a hard-coded light design.

---

# 50. Reduce Motion

When enabled:

- replace slides with fades
- remove large spring movement
- remove symbol bounce
- avoid matched-geometry flourishes
- Processing → Review becomes fade/instant

Motion must never be the only indication of state.

---

# 51. Reduce Transparency

When enabled:

- use opaque system chrome
- remove dependency on blur
- keep content readable
- maintain clear hierarchy

No content should depend on glass to be understandable.

---

# 52. Increase Contrast

When enabled:

- strengthen separators/borders as appropriate
- maintain readable footnotes
- preserve proposal/created distinction
- never rely on low-opacity effects

---

# 53. Haptics

| Event | Haptic |
|---|---|
| Successful create | Light success / soft impact |
| Failed create | Warning/error notification |
| Skip | None or very light selection |
| Processing complete | Optional soft selection |

Never spam haptics during OCR or processing.

Every important haptic must have an equivalent visual/accessibility signal.

---

# 54. Animation

Motion exists to communicate causality and continuity.

### Prefer

| Transition | Motion |
|---|---|
| Processing → Review | Short fade/slide |
| Row insertion | System list animation |
| Creating → Created | Subtle content transition |
| Edit/source | Native sheet animation |

### Avoid

- floating AI orbs
- parallax
- particle effects
- continuous ambient animation
- long “thinking” sequences
- gradient morphing
- decorative shimmer
- excessive spring animations

---

# 55. Button hierarchy

| Priority | Examples | Treatment |
|---|---|---|
| Primary | Create / Create N Ready / Done when terminal | `.borderedProminent` or native prominent system control |
| Secondary | Select / View source / Enter Text / Try Again | `.bordered` / plain |
| Tertiary | Skip / Restore | Plain / swipe |
| Destructive | Discard intake | Destructive role |

### Rule

One prominent primary action per relevant view region.

Do not make every button blue.

---

# 56. Sheets

| Sheet | Presentation |
|---|---|
| Edit Draft | Medium/large as needed |
| Source Text | Medium/large |
| Permission explanation | Compact/native alert-like |

Edit dismissal with unsaved changes requires confirmation.

---

# 57. Alerts and confirmations

Use alerts only for meaningful interruption.

### Appropriate

- discard intake
- cancel processing when work would be lost
- critical failure
- optional ambiguous creation confirmation

### Discard title

> **Discard this conversation?**

Actions:

- Discard
- Keep Reviewing

### Ambiguous create

Default behavior:

**Do not interrupt with an extra confirmation if the row already clearly says “About 7:00 PM, check before creating.”**

If testing shows accidental creation, use:

> **Create using About 7:00 PM?**

Actions:

- Create
- Edit
- Cancel

---

# 58. Visual design tokens

```text
ZUVANO DESIGN SYSTEM
────────────────────────────────

BRAND
Zuvano Indigo        #6366F1

BRAND GRADIENT
Violet               #A681FE
Periwinkle           #7C7CFC
Blue                 #515FFD

TYPOGRAPHY
SF System
No custom display font

BACKGROUND
systemGroupedBackground
secondarySystemGroupedBackground
systemBackground

TEXT
primary
secondary
tertiary

SEMANTIC
Success              systemGreen
Warning              systemOrange
Error                systemRed

SPACING
4 / 8 / 12 / 16 / 20 / 24 / 32 / 40

CUSTOM RADIUS
12–16 pt maximum
Prefer system radii

ICONS
SF Symbols only

MATERIAL
Native system Liquid Glass
Functional chrome only

CONTENT
Native List / Form

NAVIGATION
NavigationStack

TABS
None

PRIMARY VERB
Create

SECONDARY
Edit / Skip / Restore / Retry

DESTRUCTIVE
Discard

MOTION
Short / causal / subtle

BRAND STYLE
Calm
Precise
Native
Trustworthy
Intelligent
Human
Private
```

---

# 59. Anti-patterns

Zuvano must **not** become:

1. A chat interface.
2. A conversation archive.
3. An AI dashboard.
4. A floating AI orb.
5. A neon purple/cyan AI interface.
6. A collection of glass proposal cards.
7. A screen full of statistics.
8. A confidence-score interface.
9. A model-debug interface.
10. A tabbed utility suite.
11. A custom calendar browser.
12. A duplicate-detection system.
13. A UI that auto-creates actions.
14. A UI that auto-retries EventKit.
15. A UI where checkmarks mean selection and creation simultaneously.
16. A UI that says “Confirm” when it actually writes to Calendar/Reminders.
17. A UI that treats a proposal as created before EventKit succeeds.
18. A color-only status system.
19. A decorative gradient-heavy interface.
20. A custom keyboard.
21. A third-party UI kit.
22. An illustration-heavy onboarding experience.

---

# 60. Screen-by-screen visual consistency

The entire product should follow this progression:

```text
HOME
Minimal + branded
        ↓
PROCESSING
Minimal + temporal
        ↓
REVIEW
Native + information-rich
        ↓
EDIT
Native Form
        ↓
CREATED
Quiet confirmation
```

The deeper the user goes, the more functional the UI becomes.

Branding should be strongest at the entry point and increasingly subtle inside the workflow.

---

# 61. Visual QA checklist

## Product / trust

- [ ] No proposal looks Created before EventKit succeeds.
- [ ] Create wording clearly indicates Calendar/Reminders where necessary.
- [ ] Independent draft states work in one list.
- [ ] Ambiguous usable values can be created.
- [ ] Missing required Calendar start blocks Create.
- [ ] Interrupted EventKit execution never auto-retries.
- [ ] Done never silently destroys unresolved work.
- [ ] No conversation archive exists.
- [ ] No duplicate intelligence reads existing Calendar/Reminders.

## Visual

- [ ] Native iOS List/Form language.
- [ ] One restrained accent: Zuvano Indigo.
- [ ] Logo gradient is not used throughout the UI.
- [ ] No neon AI styling.
- [ ] No content-layer Liquid Glass.
- [ ] System typography.
- [ ] SF Symbols only.
- [ ] System semantic colors.
- [ ] Light mode reviewed.
- [ ] Dark mode reviewed.
- [ ] Increase Contrast reviewed.
- [ ] Reduce Transparency reviewed.
- [ ] Dynamic Type reviewed.

## Interaction

- [ ] Home supports Paste.
- [ ] Home supports Choose Photo.
- [ ] Home supports Enter Text.
- [ ] Share Sheet enters Processing.
- [ ] Processing can be cancelled safely.
- [ ] Review supports edit.
- [ ] Review supports skip/restore.
- [ ] Review supports batch creation.
- [ ] Create is explicit.
- [ ] Created state is quiet and inline.
- [ ] Failed creation is retryable.
- [ ] Done is terminal.

## Accessibility

- [ ] VoiceOver reads each draft coherently.
- [ ] Custom actions exist for Create/Edit/Skip/Restore/Retry where relevant.
- [ ] State is never color-only.
- [ ] Minimum 44 pt touch targets.
- [ ] Dynamic Type works at large sizes.
- [ ] Focus returns after sheets.
- [ ] Processing phases are announced.
- [ ] Full Keyboard Access can reach important actions.
- [ ] Reduced Motion is respected.

---

# 62. Locked design decisions

These are implementation contracts for the UI.

1. **Native Apple × Calm Intelligence × Soft Precision** is the visual direction.
2. Zuvano uses approximately **90% native iOS / 10% brand**.
3. **Zuvano Indigo `#6366F1`** is the single custom application accent.
4. The logo gradient is a **brand asset**, not the application-wide UI gradient.
5. No neon purple/cyan AI aesthetic.
6. No AI orb, shimmer, particle field, or decorative AI animation.
7. No tab bar in MVP.
8. Action Review is a **native inset grouped List**.
9. Proposal rows do not use content-layer Liquid Glass.
10. Liquid Glass is restricted to native functional chrome.
11. UI verb is **Create**, not Confirm.
12. Created is shown only after successful EventKit execution.
13. Created uses text + symbol + system green.
14. Proposal selection uses leading selection controls.
15. Trailing checkmarks are reserved for Created state.
16. Skip means reject; Restore reverses Skip.
17. Done is only terminal; unresolved work cannot be silently purged.
18. Source Text is a sheet for the current intake only.
19. Edit Draft is a Form sheet.
20. Home supports **Paste, Choose Photo, and Enter Text**.
21. Share Sheet is capture-only and hands off to the main app.
22. Processing is full-screen, calm, and phase-based.
23. Confidence scores and model internals never appear.
24. Ambiguity is expressed as human-readable text.
25. Accessibility and Dynamic Type are first-class.
26. Light and Dark modes are both required.
27. Native SF Symbols only.
28. Native semantic system colors are preferred everywhere except the single Zuvano accent.
29. The app should feel like an Apple utility with a hint of intelligence.

---

# 63. Implementation guardrails for Cursor

When implementing UI from this specification:

### Before changing a screen

Check:

1. Which screen ID is being changed?
2. Which product behavior must remain unchanged?
3. Which state is being represented?
4. Is the visual change consistent with the Zuvano design system?
5. Is the component already available as a native SwiftUI control?
6. Does the change preserve Dynamic Type and VoiceOver?
7. Does it preserve the trust boundary?

### Prefer

- native SwiftUI controls
- semantic colors
- system typography
- SF Symbols
- List
- Form
- ContentUnavailableView
- ProgressView
- PhotosPicker
- native sheets
- native alerts
- system materials
- small reusable design tokens

### Avoid

- third-party UI libraries
- custom navigation systems
- custom glass effects
- giant custom cards
- hard-coded iPhone-specific dimensions
- custom keyboard UI
- decorative AI effects
- unnecessary custom components

### Critical implementation principle

> **Do not redesign product behavior while implementing the visual system.**

UI changes must preserve the Product → Feature → Architecture → Data Model contract.

---

# 64. Final design north star

> ## Zuvano should feel like an Apple utility with a hint of intelligence.
>
> The interface should be quiet.
>
> The content should be clear.
>
> The actions should be explicit.
>
> The brand should be recognizable but restrained.
>
> The intelligence should disappear behind the result.
>
> And the user should always know:
>
> **Zuvano suggests. I decide. iOS creates.**
