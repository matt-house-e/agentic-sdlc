# 6 · Constitution (seed draft)

> **Best-practice *principles*, not conventions.** A principle is a flag to
> **justify-or-deviate**: present evidence beats the rule, but deviation must be
> *conscious and defensible*, never drift. Conventions (your taste) live in the
> invariants file; **this is the file that corrects them.**

This is a seed (~25 lines) drawn from the proven patterns in the [evidence](05-evidence.md)
plus general engineering. Cut, edit, or veto any line — it's yours to own.

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

**How it's enforced:** the reviewer (in [the flow](02-flow.md)) checks the diff against
these principles. A violation isn't auto-rejected — it's surfaced as *"this conflicts with
principle X; justify or fix."* That's the correction-through-friction mechanism from
[the knowledge loop](03-knowledge-loop.md).

⏸ **Deferred → [issue #4](https://github.com/matt-house-e/agentic-sdlc/issues/4).**
Pruning this list (strike what you'd never enforce, reword the rest, pick its home) is
tracked there so it isn't forgotten. The seed stands as-is until then.
