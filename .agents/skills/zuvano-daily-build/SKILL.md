---
name: zuvano-daily-build
description: Complete a Zuvano implementation day by verifying the work, running relevant tests, reviewing the diff, and creating the factual daily build log plus LinkedIn and X build-in-public posts. Use at the end of each roadmap day.
---

# Zuvano Daily Build Completion

Use this skill only after the day's implementation work is complete or the user explicitly asks to close out the day.

## Required reading

Read:
- `7_DAY_BUILD_ROADMAP.md`
- `BUILD_LOG_TEMPLATE.md`
- all relevant frozen documents in `docs/`
- the current day's changed files

Never invent completed work.

## Completion sequence

1. Determine the current roadmap day.
2. Inspect the git diff/status and changed files.
3. Build the project.
4. Run the relevant tests.
5. Run the most relevant reviewer:
   - `ios-design-reviewer` for UI/UX
   - `verifier` for functional behavior
   - `security-reviewer` for security/privacy
   - `debugger` only when failures/regressions exist
6. Fix issues caused by today's work when explicitly within scope.
7. Re-run verification after fixes.
8. Create:
   `docs/build-log/DAY_<N>.md`
9. The log must contain:
   - date
   - day
   - goal
   - actual implementation
   - changed files/components
   - decisions
   - tests
   - verification results
   - problems
   - fixes
   - known limitations
   - next day
   - LinkedIn post
   - X post
   - media suggestions
10. Base the public posts only on verified work from the day.
11. Do not include:
   - private conversation content
   - personal data
   - API keys
   - tokens
   - secrets
   - sensitive logs
12. Do not modify frozen product/architecture documents to make the day appear complete.

## Important

If the day is not actually complete:
- do not mark it complete;
- document what remains;
- identify the blocking issue;
- state what should happen next.

The daily log is an engineering record first and a build-in-public artifact second.
