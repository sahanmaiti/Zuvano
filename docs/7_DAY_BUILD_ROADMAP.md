# Zuvano: 7-Day Build Roadmap

> Implementation roadmap against the frozen spec set (product, architecture, data model, features, technical decisions, UI/UX).
>
> Target: iOS 26.0 deployment, iOS 27 dev/test, SwiftUI, Apple frameworks only.

## Build philosophy

Build in this order:

**Foundation → Pipeline → Intelligence → Review UX → EventKit → Share Sheet → QA → Ship**

Rules for every day:

- Don't redesign the product mid-build.
- Treat `docs/00`–`05`, `UI_UX_INSTRUCTIONS.md`, and the data model as frozen unless you explicitly change the spec.
- No third-party dependencies.
- No future features unless the MVP actually needs them.
- End each day: build, test, review, fix, log, post.
- Don't call a feature done without running the verification steps for that day.
- Build logs are factual. No marketing fiction.

---

# Day 1: Project Foundation + App Shell

### Goal
Get a clean, native SwiftUI application running with the project's architecture skeleton and design system foundations.

### Build

- Verify Xcode project and deployment target.
- Establish Swift 6 strict concurrency configuration.
- Establish SwiftUI + Observation foundation.
- Create the initial application/navigation structure.
- Implement the Home / Capture screen from `UI_UX_INSTRUCTIONS.md`.
- Add Paste and Choose Photo entry points as UI.
- Establish typography, semantic colors, spacing and system component conventions.
- Establish reusable UI primitives only where genuinely needed.
- Add Light/Dark appearance support.
- Add accessibility foundations.
- Add SwiftUI previews for key states.

### Verify

- App builds cleanly.
- App launches on simulator/device.
- Home screen matches the UI/UX specification.
- Dynamic Type does not break the layout.
- Light/Dark appearance works.
- VoiceOver labels exist for primary controls.

### End-of-day definition of done

A user can launch Zuvano and see a polished, native Home / Capture experience, even though the processing pipeline is not yet connected.

### Public build-in-public post

**LinkedIn:** Explain that the architecture and UX are frozen and Day 1 is about turning the specification into a real native iOS shell.

**X:** Short progress update + screenshot/video of the Home screen + what is being built next.

---

# Day 2: Intake + OCR Pipeline

### Goal
Make Zuvano reliably accept text and images and produce extracted text.

### Build

- Implement Intake model/persistence.
- Implement text import.
- Implement image import with `PhotosPicker`.
- Implement temporary image retention rules.
- Implement Vision OCR.
- Implement extraction states.
- Implement Processing screen.
- Implement OCR failure state.
- Implement manual text fallback.
- Implement failed-stage retry for extraction.
- Clean up temporary image after successful OCR.

### Verify

Test:

- Plain pasted conversation.
- Clear screenshot.
- Long screenshot.
- Poor-quality screenshot.
- OCR failure.
- Retry.
- Manual text entry.
- App interruption during extraction.

### End-of-day definition of done

Text and screenshot inputs can enter the pipeline and reliably become extracted text with recoverable OCR failure handling.

### Public build-in-public post

Show the first real end-to-end moment:

**Screenshot → OCR → extracted conversation**

Do not expose private conversation content in the post.

---

# Day 3: On-Device Understanding + Intent Extraction

### Goal
Turn extracted conversation text into structured understanding and candidate intents.

### Build

- Implement `UnderstandingEngine` protocol.
- Integrate Foundation Models using the installed SDK/API validated against the current Xcode SDK.
- Implement structured output according to the data model.
- Implement deterministic fallback.
- Implement understanding failure state.
- Implement retry from the understanding stage.
- Implement user-actionable intent filtering.
- Ensure other people's commitments and non-actionable statements are dropped.
- Keep model internals out of the UI.

### Verify

Create a controlled test set covering:

- Calendar commitments.
- Reminder requests.
- Tasks the user said they would do.
- Follow-ups.
- Other people's commitments.
- Historical statements.
- Questions.
- Hypotheticals.
- Entity-only mentions.
- Ambiguous times.
- Missing Calendar start time.
- Multiple actions in one conversation.
- No actionable content.

### End-of-day definition of done

Conversation text can be interpreted on-device into structured candidate intents without turning every sentence into an action.

### Public build-in-public post

Talk about the interesting technical challenge:

**How do you teach an on-device model the difference between something someone said and something the user actually needs to do?**

Do not reveal prompts, private data, or model internals.

---

# Day 4: Action Drafts + Core Review UX

### Goal
Transform actionable intents into editable Action Drafts and build the central Zuvano experience.

### Build

- Implement `IntentNormalizer`.
- Implement Action Draft generation.
- Implement draft persistence.
- Implement Action Review.
- Implement proposal states.
- Implement ambiguity presentation.
- Implement missing-field validation.
- Implement Edit Draft sheet.
- Implement Skip / Restore.
- Implement source text peek.
- Implement empty/no-actionable state.
- Implement Create controls.
- Implement accessibility for draft rows and custom actions.

### Verify

Check:

- One conversation → multiple drafts.
- Calendar + Reminder in same intake.
- Ambiguous time.
- Missing Calendar start.
- Editing fields.
- Changing action type.
- Skip.
- Restore.
- No actionable content.
- Large Dynamic Type.
- VoiceOver reading order.

### End-of-day definition of done

Zuvano's core value proposition is visible:

**Conversation → understandable proposals → user can review/edit/skip/create.**

No EventKit execution is required yet.

### Public build-in-public post

This is a major milestone.

Show the Action Review experience using safe demo data.

---

# Day 5: EventKit Execution + Permissions + Recovery

### Goal
Make confirmed drafts create real native Calendar events and Reminders safely.

### Build

- Implement `PermissionManager`.
- Implement lazy Calendar permission.
- Implement lazy Reminders permission.
- Implement permission pre-alert.
- Implement `CalendarService`.
- Implement `ReminderService`.
- Implement `ActionExecutor`.
- Persist `executing` before EventKit writes.
- Persist native identifier after successful execution.
- Implement per-draft success/failure states.
- Implement explicit retry.
- Implement interrupted execution recovery.
- Implement permission-denied recovery.
- Implement batch create.
- Ensure no auto-execution during launch recovery.

### Verify

Test:

- Calendar permission allowed.
- Calendar permission denied.
- Reminders permission allowed.
- Reminders permission denied.
- Single create.
- Multiple creates.
- Mixed Calendar + Reminder.
- EventKit failure.
- Retry.
- App termination during execution.
- Relaunch with executing draft.
- Successful native identifier persistence.
- No duplicate auto-execution.

### End-of-day definition of done

Zuvano can safely turn user-created proposals into real native Calendar/Reminder items while preserving the confirmation and recovery boundaries.

### Public build-in-public post

Show the first real native action being created.

Emphasize:

**Zuvano suggests. You decide. iOS creates.**

---

# Day 6: Share Sheet + Full Integration + UX Polish

### Goal
Connect the full product journey and polish the experience.

### Build

- Implement Share Extension capture-only flow.
- Implement App Group temporary handoff.
- Open main app into Processing.
- Integrate the complete pipeline:
  Capture → Extraction → Understanding → Drafts → Review → Create → Result.
- Polish transitions and animation.
- Add meaningful haptics.
- Verify Reduce Motion.
- Verify Reduce Transparency.
- Verify Increase Contrast.
- Verify Dynamic Type.
- Verify VoiceOver.
- Polish error/retry/recovery copy.
- Remove debug UI and accidental model terminology.
- Verify privacy cleanup behavior.

### Verify

Run complete flows:

1. Paste text → Calendar.
2. Paste text → Reminder.
3. Screenshot → OCR → Calendar.
4. Screenshot → OCR → Reminder.
5. Screenshot → manual text fallback.
6. Share text → full flow.
7. Share screenshot → full flow.
8. Multiple actions.
9. No actionable content.
10. Partial execution.
11. Permission denied.
12. Interrupted execution.
13. Retry.
14. Discard.
15. Done/purge.

### End-of-day definition of done

The complete product loop works from real user input to real native actions.

### Public build-in-public post

Post a short demo of the complete flow.

---

# Day 7: Hardening + Visual QA + Release Candidate

### Goal
Turn the working MVP into a stable, polished hackathon submission candidate.

### Build / QA

- Run full unit tests.
- Run integration-style pipeline tests.
- Run Swift 6 concurrency checks.
- Run accessibility review.
- Run `/ios-design-reviewer`.
- Run `/security-reviewer`.
- Run `/verifier`.
- Run `/debugger` only for actual failures.
- Test on physical iPhone.
- Test Light/Dark.
- Test Dynamic Type.
- Test VoiceOver.
- Test Reduce Motion.
- Test Reduce Transparency.
- Test Increase Contrast.
- Test poor OCR.
- Test model unavailable/failure fallback.
- Test EventKit denied/failure.
- Test interrupted execution.
- Test Share Sheet handoff.
- Remove unnecessary logs.
- Confirm no personal content is logged.
- Confirm sensitive intake content is purged according to the data model.
- Review App Store-facing copy/assets if available.
- Create release candidate build.

### Final review

Ask:

- Does the app feel native?
- Is the core experience obvious within seconds?
- Does every action remain under user control?
- Can the user tell proposal from created action?
- Are failures recoverable?
- Is there any accidental chatbot/dashboard/memory-app behavior?
- Is Liquid Glass restrained?
- Does the app work without accessibility compromises?

### End-of-day definition of done

A stable, tested, polished Zuvano release candidate exists and is ready for final hackathon submission preparation.

### Public build-in-public post

Share the final journey:

**Day 1 → Day 7**

Focus on what was built, what changed, what was difficult, and what you learned.

---

# Daily Completion Protocol

At the end of every implementation day, Cursor must perform this sequence:

1. Inspect the day's changed files.
2. Build the project.
3. Run relevant tests.
4. Fix failures caused by the day's work.
5. Run the relevant reviewer subagent(s).
6. Verify against the applicable product/architecture/UI requirements.
7. Do not silently change frozen specifications.
8. Create/update the daily build log.
9. Summarize what was actually completed.
10. Prepare a public build-in-public post.
11. Clearly list unfinished work and risks for the next day.

Never mark a feature complete merely because code was written.

---

# Daily Build Log Files

Create one file per completed day:

```text
docs/build-log/
├── DAY_00_2026-09-17.md
├── DAY_01.md
├── DAY_02.md
├── DAY_03.md
├── DAY_04.md
├── DAY_05.md
├── DAY_06.md
└── DAY_07.md
```

The date may be added to the filename when known.

The log must be a factual engineering record.

---

# Daily Build Log Required Sections

Each daily log must contain:

1. Date
2. Day
3. Goal
4. What was implemented
5. Files/components changed
6. Architecture decisions made
7. Tests performed
8. Verification results
9. Problems encountered
10. Fixes applied
11. Known limitations
12. Next day
13. Build-in-public LinkedIn post
14. Build-in-public X post
15. Optional screenshot/video suggestions

Do not invent accomplishments.

If something was attempted but failed, record the failure honestly.

---

# Source-of-Truth Rule

The following documents are frozen unless the user explicitly asks to change them:

- `00_PROJECT_CONTEXT.md`
- `01_PRODUCT_SPEC.md`
- `02_SYSTEM_ARCHITECTURE.md`
- `03_DATA_MODEL.md`
- `04_FEATURE_SPEC.md`
- `05_TECHNICAL_DECISIONS.md`
- `UI_UX_INSTRUCTIONS.md`

If implementation exposes a contradiction:

1. Stop.
2. Identify the contradiction.
3. Report it.
4. Ask for or receive an explicit decision.
5. Only then change the source document.

Never silently rewrite product decisions to make implementation easier.
