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

## Swift / SourceKit-LSP in Cursor

Xcode builds the app, but Cursor's editor uses **SourceKit-LSP**, which does not understand `.xcodeproj` files on its own. Without a Build Server Protocol (BSP) bridge, you get false diagnostics such as `No such module 'UIKit'` and unresolved project types.

### Prerequisites

1. Open the **repo root** (`Zuvano/`) as the Cursor workspace — not only the inner `Zuvano/Zuvano/` source folder.
2. Install Cursor extensions (see `.vscode/extensions.json`):
   - **Swift** (`swiftlang.swift-vscode`)
   - **CodeLLDB** (`vadimcn.vscode-lldb`) — optional, for debugging
3. Install the BSP bridge:
   ```sh
   brew install xcode-build-server
   ```
4. Confirm Xcode toolchain:
   ```sh
   xcode-select -p
   # should be /Applications/Xcode.app/Contents/Developer
   ```

### One-time project setup

From the repo root, after a successful Xcode build:

```sh
xcode-build-server config -project Zuvano/Zuvano.xcodeproj -scheme Zuvano
xcodebuild -project Zuvano/Zuvano.xcodeproj -scheme Zuvano \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO build 2>&1 | xcode-build-server parse
```

This creates/updates:

- `buildServer.json` — BSP config for SourceKit-LSP (committed)
- `.compile` — machine-local compile flags cache (gitignored)

Copy `.vscode/settings.json.example` to `.vscode/settings.json` if you do not already have one.

Then **restart SourceKit-LSP**: `Cmd+Shift+P` → **Swift: Restart LSP Server** (or reload the window).

### After adding Swift files or changing build settings

Run the **Zuvano: Refresh SourceKit flags** task (`.vscode/tasks.json`) or rebuild in Xcode, then restart the LSP server.

### Troubleshooting

| Symptom | Fix |
|---|---|
| `No such module 'UIKit'` | Missing `buildServer.json` or stale `.compile`. Re-run setup above. |
| Types in other files not found | Workspace opened at wrong folder, or LSP not restarted after build. |
| Diagnostics differ from Xcode | Run **Refresh SourceKit flags**, then restart LSP. |
| Cross-file refs broken | Check `build_root` in `buildServer.json` points at DerivedData for this project. |
