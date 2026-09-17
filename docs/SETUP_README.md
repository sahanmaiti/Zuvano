# Zuvano Cursor setup

Notes for working on Zuvano in Cursor during the hackathon build.

## What's in the repo

Project docs live under `docs/`. Cursor config is under `.cursor/`. Agent skills are under `.agents/skills/`.

```text
Zuvano/
├── .agents/skills/          # SwiftUI, EventKit, human-documentation, zuvano-daily-build, …
├── .cursor/
│   ├── agents/
│   │   └── ios-design-reviewer.md
│   └── rules/
│       └── zuvano-build-workflow.mdc
├── docs/
│   ├── 00_PROJECT_CONTEXT.md … 05_TECHNICAL_DECISIONS.md
│   ├── UI_UX_INSTRUCTIONS.md
│   ├── 7_DAY_BUILD_ROADMAP.md
│   ├── BUILD_LOG_TEMPLATE.md
│   ├── SETUP_README.md        # this file
│   └── build-log/
│       └── DAY_00_2026-09-17.md
├── README.md
└── skills-lock.json
```

Some setup guides still mention optional Cursor rules (`zuvano-architecture.mdc`, `zuvano-ui.mdc`, `zuvano-safety.mdc`). Only `zuvano-build-workflow.mdc` is in the repo today. Add the others if you want stricter per-area guardrails.

## Daily workflow

1. Read the current day in `docs/7_DAY_BUILD_ROADMAP.md`.
2. Implement against the frozen specs. Don't redesign product mid-build.
3. Build, test, fix.
4. Close the day with the `zuvano-daily-build` skill (build log + public posts).
5. Use `human-documentation` when writing or editing docs so they don't read like AI output.

Build logs go in `docs/build-log/`. Copy from `docs/BUILD_LOG_TEMPLATE.md`.

## Spec precedence

If docs disagree:

Product → Feature → Architecture → Technical decisions → UI/UX

## Skills worth knowing

| Skill | When |
|---|---|
| `human-documentation` | README, build logs, any project doc |
| `zuvano-daily-build` | End of each roadmap day |
| `ios-design-reviewer` | UI/UX reviews (also `.cursor/agents/ios-design-reviewer.md`) |
| SwiftUI / EventKit / SwiftData / etc. | Implementation help |

## MCP / tools

- **Xcode MCP** for builds, tests, previews
- **Mobbin** for UI reference (see workspace Mobbin rule)
