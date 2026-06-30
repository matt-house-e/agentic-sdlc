# Constitution

These are best-practice **principles, not conventions**. A principle is a flag
to **justify-or-deviate**: present evidence beats the rule, but the deviation
must be **conscious**, never silent. Conventions and taste (arbitrary-but-
consistent project choices) live in the **invariants** section, not here.

**Install:** drop this into the host repo's `AGENTS.md`, or keep it as
`constitution.md` imported into it. Then **curate it** — strike any principle
you'd never actually enforce. A seed you don't trim is bloat.

## Design

- Build the simplest thing that meets the requirement; add structure only when a second caller exists.
- One module, one responsibility — if you can't name it in a sentence, split it.
- No premature abstraction: duplicate twice before extracting.
- Make illegal states unrepresentable — types/enums over stringly-typed flags.
- Depend on interfaces you own, not on incidental details of what you call.

## Code

- Don't handle errors that can't happen; let impossible states crash loudly.
- Validate at trust boundaries only; trust your own internals.
- Comments say WHY, never WHAT; delete commented-out code.
- Isolate side effects at the edges; keep the core pure where practical.
- Name for the reader who lacks your context.

## Change discipline

- Every change ships with a check that proves it (test/lint/eval). If you can't verify it, don't ship it.
- One logical change per commit — the history is the design log.
- Make it work, make it right, make it fast — in that order; don't optimise the unmeasured.
- Fix what you touch; don't gold-plate what you don't.
- Prefer reversible changes; gate irreversible ones behind explicit review.

## AI-assisted work

- Plan before code on anything non-trivial; skip the plan only for one-shot diffs.
- Review in fresh context, scoped to correctness and requirement gaps — not "find something".
- Use sub-agents for context isolation, never to parallelise the build.
- Keep always-loaded memory lean — a rule that wouldn't catch a real mistake doesn't belong.
- Spend tokens where they buy correctness (plan, review); be frugal in the hot loop.

---

Pruning and curation are tracked per the host project (this plugin's seed review is issue #4).
