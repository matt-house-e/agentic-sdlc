# Knowledge model

The compounding loop implements against this model: a two-tier store of durable
project knowledge, harvested from real review findings, kept lean by an
admission bar and refreshed against rot. This file is the reference; the host
repo holds the actual knowledge.

## Knowledge home

`AGENTS.md` is the canonical, cross-tool home — read natively by many harnesses.
`CLAUDE.md` is generated/imported from it. **The loop writes to `AGENTS.md`.**
Never hand-edit the generated `CLAUDE.md`; regenerate it.

## Two tiers, two authorities

| Tier | What it is | Example | Authority |
| --- | --- | --- | --- |
| **Invariants** (taste / convention) | Arbitrary-but-consistent project choices | "Use Pydantic, not dataclasses" | **Enforced** — a PR must not violate them. |
| **Constitution** (best-practice principles) | Objective-ish engineering principles | "No error handling for impossible states" | **Justify-or-deviate** — a violation is *flagged*; you must consciously justify or fix. **Present evidence always beats the stored rule** — never a silent override. |

## The admission bar

A new rule gets in ONLY if:

> Removing this line would let a real mistake through.

- Keep the always-loaded file lean — Anthropic guidance: **under ~200 lines**.
  Bloat means rules get ignored.
- Write in **imperative voice**: "Use X" / "Never Y".
- If a candidate rule wouldn't have caught a real mistake, it doesn't belong.

## Observation-anchored

Harvest rules ONLY from real review findings or failures — **never
aspiration**. Anchoring to observed mistakes is what makes the store
drift-resistant: every rule (invariant or principle) traces back to something
that actually went wrong.

## Central judging

Judge a review finding's *legitimacy* **once**, before harvesting it. Reject
confidently-wrong reviewer findings rather than folding an incorrect rule in. A
bad rule admitted here propagates to every future PR — the gate matters more
than the volume.

## The refresh model

The freshness pass (documented here, not yet automated). Each existing rule
resolves to one of five outcomes:

| Outcome | When |
| --- | --- |
| **Keep** | Still earns its place against the admission bar. |
| **Update** | Right intent, stale specifics. |
| **Consolidate** | Overlaps another rule; merge into one. |
| **Replace** | Contradicted by newer evidence. |
| **Delete** | No longer catches a real mistake. |

Two rules, verbatim:

- *"age alone is not a stale signal"*
- *"contradiction = strong Replace signal"*

A cross-doc conflict check runs first and **ranks contradictions above
individual staleness** — a rule that disagrees with another doc is a louder
signal than a rule that is merely old.

## Where each kind of knowledge lives

| Knowledge | Home |
| --- | --- |
| Invariants + constitution | `AGENTS.md` |
| The *why* of big calls | `docs/decisions/` ADRs |
| Per-issue intent | The GitHub issue / PR (not a repo file) |
