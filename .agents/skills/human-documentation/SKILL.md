---
name: human-documentation
description: Write project documentation that reads like a developer who built the product wrote it, not an AI doc generator. Use when creating, updating, rewriting, expanding, or maintaining README files, architecture docs, technical decisions, feature specs, implementation notes, build logs, setup docs, changelogs, hackathon updates, or build-in-public posts.
---

# Human Documentation

Write documentation that sounds like a real developer on this project wrote it.

Read relevant repo files first. Use actual project terminology, filenames, types, modules, commands, and architecture when they exist. Do not invent implementation details to make docs look complete. Separate implemented functionality from planned or proposed work. Do not oversell the project.

## When to use this skill

Apply this skill whenever the task involves project documentation, including:

- README files
- architecture documentation
- technical decisions
- feature specifications
- implementation notes
- build logs
- development logs
- setup documentation
- project documentation
- changelogs
- hackathon build updates
- public build-in-public documentation

If the user asks for doc work without naming this skill, still follow these rules.

## Writing rules

### Hard ban: em dashes

NEVER use the em dash character anywhere in generated documentation.

Use commas, periods, colons, parentheses, or sentence rewrites instead.

Before returning any document, search the output for `—`. If any appear, rewrite those sentences.

### Avoid AI-sounding language

Do not use generic AI phrases such as:

- "In today's rapidly evolving…"
- "At its core…"
- "It's worth noting…"
- "Let's dive into…"
- "seamlessly"
- "robust"
- "scalable and efficient"
- "powerful yet simple"
- "cutting-edge"
- "state-of-the-art"
- "leverage"
- "utilize"
- "furthermore"
- "moreover"
- "in conclusion"

Also avoid similar filler: "comprehensive", "holistic", "streamlined", "game-changing", "revolutionary", "next-generation", "best-in-class", "unlock", "empower", "delve", "navigate", "landscape", "paradigm", "synergy", "tapestry", "underscores", "pivotal", "testament", "multifaceted", "myriad".

Do not swap banned phrases for equally artificial synonyms. Use plain developer language instead.

### Prefer concrete over vague

- Name real files, types, services, states, and commands when known.
- Say what the code or spec actually does, not what it "enables" in abstract terms.
- Explain decisions and reasoning, not just component lists.
- Mention trade-offs only when supported by project context. Do not invent trade-offs.
- Do not explain obvious concepts unless the target reader actually needs them.

### Tone and rhythm

- Write like a developer explaining the project to another developer.
- Use contractions naturally when they fit ("it's", "doesn't", "we're").
- Vary sentence length. Mix short direct sentences with longer explanatory ones.
- Avoid excessive qualifiers and unnecessary padding.
- Keep Markdown clean and practical.
- Avoid unnecessary emojis, decorative formatting, excessive bold text, and filler sections.
- Let the content determine the structure. Do not force every document into the same generic template.

### Honesty

- If something is planned, say planned. If something is done, say done and point to evidence.
- If scope is uncertain, say so.
- Prioritize clarity, specificity, and honesty over polished marketing language.

## Workflow

1. Read the relevant source material in the repo before writing.
2. Draft the document using the rules above.
3. Run the human-writing review pass below.
4. Rewrite anything that fails.
5. Return the final document only after the review pass passes.

## Human-writing review pass

Before producing documentation, silently check:

1. Is there any `—` character?
2. Does the document contain obvious AI-generated phrases?
3. Does the writing sound like a developer rather than a documentation generator?
4. Are there vague claims that could be replaced with concrete details?
5. Is anything being unnecessarily oversold?
6. Has anything been invented?
7. Are current and planned functionality clearly separated?
8. Is there unnecessary filler?
9. Are important architectural decisions explained rather than merely listed?
10. Does the sentence rhythm feel natural?

If any check fails, rewrite before returning the document.

## Good vs bad

**Bad**

> At its core, Zuvano seamlessly leverages cutting-edge on-device AI to robustly transform conversation content into actionable outcomes, furthermore ensuring a scalable and efficient user experience.

**Good**

> Zuvano runs OCR and on-device understanding on content you paste or share, then shows Action Drafts in Action Review. Nothing hits EventKit until you tap Create on a draft.

**Bad**

> The architecture consists of several modular components working together in a powerful yet simple pipeline.

**Good**

> `IntakePipelineCoordinator` drives extraction, understanding, normalization, and execution. Views stay dumb; draft confirmation and EventKit writes happen only after the user creates a draft.

**Bad**

> It's worth noting that the Share Extension will seamlessly integrate with the main app.

**Good**

> The Share Extension only captures content and hands off to the main app (TD-16). Processing stays in the app target, not the extension.

## Zuvano terminology (when relevant)

Use project terms consistently when they appear in the repo:

- Intake, Action Draft, Intent, user-actionable filter
- Action Review, Create (not Confirm for the primary action)
- IntakePipelineCoordinator, UnderstandingEngine, ActionExecutor
- implemented vs planned vs documented target

If a term is not in the repo yet, do not present it as implemented.

## Final reminder

The goal is documentation a teammate would trust: specific, honest, readable, and free of AI filler. When in doubt, cut words, add a filename, or say "not built yet."
