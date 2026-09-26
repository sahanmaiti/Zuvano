<div align="center">

# Zuvano

**Turn conversation content into Calendar events and Reminders, on-device, with you in control.**

A native iOS app that takes content you provide, understands it privately on-device, and turns useful parts of it into Calendar events and Reminders. You review every proposed action before anything is created.

<br>

![iOS](https://img.shields.io/badge/iOS-26%2B-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift)
![Status](https://img.shields.io/badge/status-MVP%20complete-green?style=flat-square)
![Privacy](https://img.shields.io/badge/privacy-On--device-green?style=flat-square)
![Hackathon](https://img.shields.io/badge/ACoding%20Hackathon-2026-blue?style=flat-square)

<br>

</div>

---

## What is Zuvano?

A lot of useful information gets buried in conversations.

Someone sends you a meeting time. A friend asks you to pick something up on Thursday. A message includes a follow-up task you do not want to forget. The information is already there, but getting it into Calendar or Reminders usually means doing the work yourself.

You read the message, figure out what matters, switch apps, and type everything in again. It is easy to miss something.

Zuvano is built around that small but annoying gap.

You give it the content you want it to look at, either by pasting text, selecting a photo, or using the Share Sheet. Zuvano processes that content on-device and proposes structured **Action Drafts**. You can edit a draft, skip it, or create it.

Nothing is added to Calendar or Reminders just because the model suggested it. The final action is always yours.

Zuvano does not try to be another chatbot or conversation archive. It is a focused pipeline that takes content you choose and helps turn it into native iOS actions.

---

## ✨ Why Zuvano?

There are already plenty of apps that can work with text. The problem is that most of them are solving a different problem.

- **Chatbots and AI assistants** are built around conversation. Zuvano is built around extracting actionable items and getting them into the native apps you already use.
- **Notes and task apps** usually start after you have decided what needs to be saved. Zuvano starts with the conversation itself.
- **Cloud AI wrappers** require sending your content to a remote service. Zuvano's core processing is designed to stay on-device.

The interesting part of Zuvano is the pipeline between understanding something and actually doing something with it:

**conversation → extraction → understanding → intent → user-actionable filter → Action Draft → review → create → native execution**

There is an important boundary in that pipeline:

**AI proposes. You create.**

An extracted intent is not an execution command. An Action Draft is still just a proposal. Calendar or Reminders are only touched after you explicitly choose to create the draft.

The app is also being built with a deliberately small native stack: SwiftUI, Observation, Swift Concurrency, SwiftData, Vision, Foundation Models, and EventKit.

---

## 🚧 Project Status

Zuvano is **hackathon MVP complete** as part of **ACoding Hackathon 2026**.

**Days 0–7 of the roadmap are implemented.** The full loop runs on device: intake → understanding → Action Review → EventKit create, plus Share Sheet handoff and launch recovery. **Day 8** added EventKit reliability hardening (typed failures, writable calendar/list resolution, state-safe execution). Distribution archive still needs a development team and device QA for Share Sheet and Calendar/Reminders on hardware.

| Area | Status | Notes |
|---|---|---|
| Product definition | ✅ Complete | `docs/00_PROJECT_CONTEXT.md`, `docs/01_PRODUCT_SPEC.md` |
| Feature specification | ✅ Complete | `docs/04_FEATURE_SPEC.md` |
| System architecture | ✅ Complete | `docs/02_SYSTEM_ARCHITECTURE.md` |
| Data model | ✅ Complete | `docs/03_DATA_MODEL.md` |
| Technical decisions | ✅ Complete | `docs/05_TECHNICAL_DECISIONS.md` |
| UI/UX specification | ✅ Complete | `docs/UI_UX_INSTRUCTIONS.md` |
| Implementation roadmap | ✅ Complete | `docs/7_DAY_BUILD_ROADMAP.md` |
| Build-in-public logs | 🟡 In progress | `docs/build-log/` (Days 0–8) |
| iOS app / Xcode project | ✅ | `Zuvano/Zuvano.xcodeproj` |
| Home / Capture (S1) | ✅ | Paste, Choose Photo, Enter Text |
| Intake + OCR pipeline | ✅ | SwiftData, Vision OCR, processing + failure UI |
| On-device understanding | ✅ | Foundation Models + fallback, user-actionable filter |
| Action Drafts + Review | ✅ | Normalizer, mapper, validator, edit/skip/create UI |
| EventKit execution | ✅ | Calendar events + Reminders after confirmation |
| Share Extension | ✅ | App Group handoff + `zuvano://` deep link |
| Automated tests | ✅ | ~90 Swift Testing unit tests + template UI tests |
| App Store / archive | 🟡 Blocked on signing | App Group entitlements need dev team |

### What works today

**Capture & intake**

- **Paste** authorized text via system `UIPasteControl` (no direct clipboard reads)
- **Choose Photo** via `PhotosPicker` starts image intake
- **Enter Text** manual entry from Home
- **Share Sheet** (`ZuvanoShare`): text/image handoff into the main app via App Group + URL scheme

**Processing & understanding**

- **Processing** screen with phase-aware copy (extracting, understanding, preparing actions)
- **Vision OCR** for screenshots (unit-tested with stubs; real-device quality not formally benchmarked)
- **OCR failure** recovery: Try Again, Enter Text, Discard
- **On-device understanding** via Foundation Models with deterministic fallback when unavailable
- **User-actionable filter** drops other people's commitments, questions, hypotheticals, and MVP follow-ups
- **Intent normalization** with weekday/time resolution and ambiguity marking

**Review & execution**

- **Action Draft generation** maps intents to calendar events and reminders, persisted in SwiftData
- **Action Review**: edit sheet, skip/restore, source peek, validation, batch Create / Create Selected
- **EventKit create** after you confirm: permissions (pre-alert + system prompt), persist `executing`, write to Calendar/Reminders, persist `executed` or typed `failed` with Retry
- **Done** gated until every draft is terminal (including dismiss on failed rows)
- **Launch recovery** for interrupted intakes, stuck execution (`executing` without native id → failed/interrupted), and share handoff ingest

**Quality & privacy**

- SwiftData store under Application Support with backup exclusion (best-effort)
- Haptics, Reduce Motion–aware transitions, adaptive backgrounds for transparency/contrast
- Action Review accessibility: leading batch select, conditional VoiceOver actions, 44pt recovery controls

### Still needs device validation

Physical iPhone runs for Share Sheet end-to-end, Calendar/Reminders permission edge cases, Light/Dark/Dynamic Type/VoiceOver matrix, and signed Release archive with App Group.

---

## 🧠 How It Works

For each piece of content, Zuvano follows the same basic pipeline:

```mermaid
flowchart TD
    A[User provides content<br/>text / image / share] --> B[Extraction<br/>OCR or passthrough]
    B --> C[On-device understanding<br/>Foundation Models or fallback]
    C --> D[Candidate intents]
    D --> E[User-actionable filter]
    E --> F[Action Drafts<br/>editable proposals]
    F --> G[Action Review<br/>edit · skip · create]
    G --> H{User creates?}
    H -->|No| I[Skip or discard]
    H -->|Yes| J[EventKit<br/>Calendar / Reminders]
    J --> K[Per-draft result<br/>created or retry]
```

The important part is what happens between the model and EventKit.

AI output is treated as input to the system, not as permission to perform an action. Zuvano filters the extracted intents, turns the ones that are actually actionable into drafts, and puts those drafts in front of you for review. Only after you confirm does `DraftExecutionService` talk to EventKit.

---

## 🏗️ Architecture

Zuvano uses a **modular pipeline coordinated by a single orchestrator**. Presentation stays in SwiftUI; EventKit is isolated behind execution services.

```mermaid
flowchart TB
    subgraph Presentation["Presentation"]
        UI[SwiftUI + Observation]
        COORD[AppFlowCoordinator]
    end

    subgraph Orchestration["Orchestration"]
        ORCH[IntakePipeline]
    end

    subgraph Pipeline["Pipeline services"]
        OCR[TextExtractor · Vision]
        UNDER[UnderstandingEngine]
        NORM[IntentNormalizer · DraftMapper]
        VAL[DraftValidator]
        EXEC[DraftExecutionService · EventKit]
    end

    subgraph Share["Share handoff"]
        EXT[ZuvanoShare extension]
        HAND[ShareHandoffStore]
    end

    subgraph Persistence["Persistence"]
        STORE[ActionStore · SwiftData]
        TEMP[TemporaryImageStore]
    end

    UI --> COORD
    COORD --> ORCH
    COORD --> EXEC
    COORD --> HAND
    EXT -.-> HAND
    ORCH --> OCR
    ORCH --> UNDER
    ORCH --> NORM
    ORCH --> VAL
    ORCH <--> STORE
    ORCH <--> TEMP
```

### Major components

| Component | Responsibility | Status |
|---|---|---|
| **Presentation** | SwiftUI views render state; `AppFlowCoordinator` owns flow | ✅ |
| **IntakePipeline** | Import → extract → understand → draft → review; retry, recovery | ✅ |
| **TextExtractor** | Passthrough text + Vision OCR for images | ✅ |
| **UnderstandingEngine** | On-device intent extraction (FM + fallback) | ✅ |
| **UserActionableFilter** | Drops non-user intents before draft generation | ✅ |
| **IntentNormalizer** | Deterministic date/time resolution from raw expressions | ✅ |
| **DraftMapper / DraftValidator** | Intent → draft mapping and field validation | ✅ |
| **ActionStore** | SwiftData `@ModelActor` for Intake + Action Draft state | ✅ |
| **TemporaryImageStore** | Temp image files per data model rules | ✅ |
| **DraftExecutionService** | Permissions + EventKit create after user confirmation | ✅ |
| **ShareHandoffStore** | App Group ingest + stale cleanup | ✅ |
| **ZuvanoShare** | Capture-only Share Extension | ✅ |

### Important design decisions

- **Intake processing is separate from draft execution.** Intake state covers ingestion through ready-for-review. Confirmation and EventKit state belong to Action Drafts.
- **Intent and Action Draft are different things.** Only user-actionable intents become drafts.
- **Retries start from the failed stage.** OCR, understanding, draft generation, and EventKit each have their own retry boundary.
- **EventKit only in execution layer.** `IntakePipeline` recovery repairs persisted state; it does not auto-create calendar items on relaunch.
- **Paste uses system authorization.** iOS 16+ blocks direct `UIPasteboard` reads. Paste must go through a visible `UIPasteControl`.
- **Sensitive content stays in-flight.** Purged after terminal completion or discard, not stored as a conversation archive.

More detail: [`docs/02_SYSTEM_ARCHITECTURE.md`](docs/02_SYSTEM_ARCHITECTURE.md), [`docs/03_DATA_MODEL.md`](docs/03_DATA_MODEL.md), [`docs/05_TECHNICAL_DECISIONS.md`](docs/05_TECHNICAL_DECISIONS.md).

---

## 🛠️ Tech Stack

| Technology | Purpose | In use |
|---|---|---|
| **Swift 6** | Application language, strict concurrency | ✅ |
| **SwiftUI** | Native iPhone UI | ✅ |
| **Observation** (`@Observable`) | `AppFlowCoordinator` state | ✅ |
| **Swift Concurrency** | Async pipeline, `@ModelActor`, `@concurrent` EventKit offload | ✅ |
| **SwiftData** | In-flight Intake persistence | ✅ |
| **Vision** | On-device OCR (`VNRecognizeTextRequest`) | ✅ |
| **UIKit** | `UIPasteControl` for authorized paste | ✅ |
| **Foundation Models** (iOS 26+) | On-device understanding | ✅ |
| **EventKit** | Calendar / Reminders after confirmation | ✅ |
| **PhotosPicker** | Image import | ✅ |
| **App Groups** | Share Extension handoff | ✅ |

**Out of scope for the MVP:** third-party dependencies, external LLM APIs, backend services.

Deployment target: **iOS 26.0** minimum. Development and testing target: **iOS 27**.

---

## 📁 Project Structure

```text
Zuvano/
├── README.md
├── Zuvano/
│   ├── Assets.xcassets/
│   ├── Zuvano.xcodeproj
│   ├── Zuvano/
│   │   ├── App/                    # ZuvanoApp entry point
│   │   ├── Domain/                 # Source, IntakeSnapshot, Intent, ActionDraft types
│   │   ├── Extraction/             # TextExtracting, VisionTextExtractor
│   │   ├── Intelligence/           # UnderstandingEngine, IntentNormalizer, filter
│   │   ├── Execution/              # DraftExecutionService, EventKit store adapter
│   │   ├── Orchestration/          # IntakePipeline, DraftMapper
│   │   ├── Validation/             # DraftValidator
│   │   ├── Persistence/            # IntakeRecord, ActionDraftRecord, ActionStore, ModelContainer
│   │   ├── Shared/                 # App Group constants, ShareHandoffStore
│   │   ├── Features/
│   │   │   ├── App/                # AppFlowCoordinator, RootView
│   │   │   ├── Home/               # HomeView, ZuvanoPasteControl
│   │   │   ├── Processing/       # S2 Processing
│   │   │   ├── ActionReview/     # S3–S6 Review, Edit, Source peek
│   │   │   ├── PipelineFailure/  # S7 failure + retry
│   │   │   └── ManualTextEntry/  # OCR fallback text entry
│   │   └── DesignSystem/         # Colors, typography, haptics, adaptive backgrounds
│   ├── ZuvanoShare/                # Share Extension target
│   ├── ZuvanoTests/                # Swift Testing (pipeline, execution, handoff, purge)
│   └── ZuvanoUITests/              # Template UI tests
├── docs/                           # Frozen spec set + roadmap + build logs
│   ├── 00_PROJECT_CONTEXT.md
│   ├── 01_PRODUCT_SPEC.md
│   ├── 02_SYSTEM_ARCHITECTURE.md
│   ├── 03_DATA_MODEL.md
│   ├── 04_FEATURE_SPEC.md
│   ├── 05_TECHNICAL_DECISIONS.md
│   ├── UI_UX_INSTRUCTIONS.md
│   ├── 7_DAY_BUILD_ROADMAP.md
│   └── build-log/
│       ├── DAY_00_2026-09-17.md
│       ├── DAY_01_2026-09-18.md
│       ├── DAY_02_2026-09-18.md
│       ├── DAY_03_2026-09-21.md
│       ├── DAY_04_2026-09-22.md
│       ├── DAY_05_2026-09-22.md
│       ├── DAY_06_2026-09-24.md
│       ├── DAY_07_2026-09-24.md
│       └── DAY_08_2026-09-26.md
├── .agents/skills/                 # Project-local agent skills
└── .cursor/rules/                  # Build workflow rules
```

---

## 📚 Documentation

If you are new to the project, start here:

1. [`docs/00_PROJECT_CONTEXT.md`](docs/00_PROJECT_CONTEXT.md) — what Zuvano is and is not
2. [`docs/01_PRODUCT_SPEC.md`](docs/01_PRODUCT_SPEC.md) — requirements and MVP scope
3. [`docs/04_FEATURE_SPEC.md`](docs/04_FEATURE_SPEC.md) — feature behavior
4. [`docs/02_SYSTEM_ARCHITECTURE.md`](docs/02_SYSTEM_ARCHITECTURE.md) — system design
5. [`docs/03_DATA_MODEL.md`](docs/03_DATA_MODEL.md) — data model and state machines
6. [`docs/05_TECHNICAL_DECISIONS.md`](docs/05_TECHNICAL_DECISIONS.md) — technology choices
7. [`docs/UI_UX_INSTRUCTIONS.md`](docs/UI_UX_INSTRUCTIONS.md) — UI/UX specification

Implementation plan: [`docs/7_DAY_BUILD_ROADMAP.md`](docs/7_DAY_BUILD_ROADMAP.md)

Daily progress: [`docs/build-log/`](docs/build-log/)

---

## 🗺️ Roadmap

| Day | Focus | Status |
|---|---|---|
| **0** | Product, architecture, data model, UI/UX | ✅ Complete |
| **1** | Xcode project, SwiftUI app shell, Home / Capture | ✅ Complete |
| **2** | Intake, OCR, extraction pipeline | ✅ Complete |
| **3** | On-device understanding, intent extraction, user-actionable filter | ✅ Complete |
| **4** | Action Drafts, Action Review | ✅ Complete |
| **5** | EventKit execution, permissions, recovery | ✅ Complete |
| **6** | Share Extension, polish, integration | ✅ Complete |
| **7** | Hardening, visual/a11y QA, release candidate | ✅ Complete (simulator) |
| **8+** | EventKit reliability, execution state safety | ✅ In repo; device QA ongoing |

See [`docs/7_DAY_BUILD_ROADMAP.md`](docs/7_DAY_BUILD_ROADMAP.md) for definitions of done and verification criteria.

---

## 🔒 Privacy

Privacy is part of the architecture, not a separate feature added later.

- Conversation content is processed **on-device**. Zuvano does not send it to a backend or external LLM.
- The core flow does not use API keys or telemetry.
- Raw images are kept only until OCR succeeds.
- Extracted text is kept while it is needed for review and retry, then purged. It is not stored as a browsable conversation archive.
- SwiftData application data is stored under Application Support with **backup exclusion** on the Zuvano store directory (best-effort).
- Paste uses Apple's `UIPasteControl`. Clipboard content is only read after you tap Paste and iOS authorizes access.
- Calendar and Reminder items created through EventKit can sync through the user's Apple accounts in the normal way.

More detail: [`docs/00_PROJECT_CONTEXT.md`](docs/00_PROJECT_CONTEXT.md) §15, [`docs/01_PRODUCT_SPEC.md`](docs/01_PRODUCT_SPEC.md) §21.

---

## 🚫 What Zuvano Is Not

Zuvano is not trying to replace your messaging app, notes app, task manager, or calendar.

It is also not a chatbot, conversation archive, memory system, background monitor, or cloud AI wrapper.

Zuvano does not read private conversations from other apps. It does not scrape messages. It does not automatically execute an action because an AI model suggested one.

The user chooses the content, reviews the proposed actions, and decides what gets created.

---

## 🛠️ Getting Started

### Requirements

- Xcode with iOS 26+ SDK (iOS 27 recommended for development)
- iPhone Simulator or physical iPhone running iOS 26+
- For Share Extension + App Group on device: Apple Developer signing with the `group.com.zuvano.app` entitlement

### Build and run

```bash
cd Zuvano
open Zuvano.xcodeproj
```

Select an iPhone Simulator (or a connected device), then **Product → Run** (⌘R).

### Run tests

```bash
cd Zuvano
xcodebuild -scheme Zuvano \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  test
```

Or run **ZuvanoTests** from Xcode (⌘U).

### Source of truth

The `docs/` specification set governs implementation. If two documents disagree, use this resolution order:

**Product → Feature → Architecture → Technical decisions → UI/UX instructions**

---

## 📣 Build in Public

Zuvano is being built in public during **ACoding Hackathon 2026**.

Daily build logs in [`docs/build-log/`](docs/build-log/) record what was actually worked on each day.

| Day | Summary |
|---|---|
| **0** | Froze product spec, architecture, data model, UI/UX |
| **1** | Xcode project, SwiftUI Home shell, design system |
| **2** | Intake + SwiftData + Vision OCR pipeline, processing/failure UI, authorized paste |
| **3** | On-device understanding (Foundation Models + fallback), user-actionable filter, Review milestone |
| **4** | Action Drafts (normalizer, mapper, validator), full Review UX (edit/skip/create), unit tests |
| **5** | EventKit create path, permissions, execution UI, launch recovery |
| **6** | Share Extension handoff, haptics, dismiss-failure Done, adaptive backgrounds |
| **7** | Backup-excluded SwiftData store, purge tests, Action Review a11y/touch targets |
| **8** | EventKit store lifecycle, typed failures, writable calendar resolution, execution hardening |

---

## 🏷️ Hackathon

**ACoding Hackathon 2026** · Native iOS · iPhone · On-device AI · Human-in-the-loop actions
