# 3 · Knowledge loop

> **Learn how you build. Correct you when it conflicts with good engineering.
> Stay small enough to actually be read.**

## The minimal artifact set (solo scale)

Research is emphatic: the durable core is human-readable artifacts — but the *winning*
set for a solo dev is small and code-anchored. Heavy spec ceremony (spec-kit's
Constitution/Spec/Plan/Tasks tree) is in ThoughtWorks "Assess, not Adopt" and measured
**~10× slower** in one study. **Spec rot is the named failure mode.**

| Artifact | Lives in | Role |
|---|---|---|
| **Invariants + constitution** | `CLAUDE.md` / `AGENTS.md` | The always-loaded appreciating asset |
| **Per-issue intent** (what/why/acceptance) | the **GitHub issue/PR** | Ephemeral, auto-archived — *not* a repo file |
| **Decision log** (lightweight ADRs) | `docs/decisions/` | The durable *why* code can't reconstruct |
| **Harvested learnings** | feed → invariants | Your existing compounding loop |

> **Deliberately omitted:** standalone feature-spec files, Requirements/Design/Tasks doc
> sets, bidirectional spec↔code sync. That's the rot surface.

## Two kinds of rule, two authorities

| Kind | Example | System behaviour |
|---|---|---|
| **Taste / convention** | "Use Pydantic, not dataclasses" | **Enforce** — arbitrary but consistent |
| **Best-practice principle** | "No error handling for impossible states" | **Flag to justify-or-deviate** |

## The correction mechanism — the key design decision

Your requirement: *learn but also correct, don't just mimic.* The naive loop (capture →
enforce) calcifies bad habits. My first fix — a constitution that **overrules** you — was
**wrong**, and the evidence is decisive:

> Compound-engineering's own retrieval agent hard-codes the opposite:
> *"never let a past learning silently override present evidence… flag the conflict
> rather than echoing the claim."*

So the corrected design: a best-practice principle is a **flag that forces a justification**,
never a silent override. Present evidence (the actual code, the actual context) always wins —
but you have to *consciously deviate*, not drift. **Correction through friction, not authority.**
That's the stronger version of what you wanted.

## Anti-rot machinery — discipline, not a database

The contrarian round was right that hand-building schema validation + GC + TTLs is a
maintenance tarpit (native memory now persists the file for you). So keep it lightweight:

- **Admission bar** — a new invariant gets in *only* if "removing this line would cause a
  mistake." Anthropic's own CLAUDE.md guidance: keep under ~200 lines; bloat → ignored rules.
- **Observation-anchored** — harvest invariants *only* from real review findings/failures,
  never aspiration. This is what makes them drift-resistant.
- **Cheap freshness pass** — periodically re-validate each invariant against current code.
  5 outcomes: **Keep / Update / Consolidate / Replace / Delete**. Two rules worth copying
  verbatim: *"age alone is not a stale signal"* and *"contradiction = strong Replace signal."*

## Harvest, centrally judged

Steal the *idea* (not the skill) from `ce-resolve-pr-feedback`: **judge findings centrally,
fan out only fixes**, with confidently-wrong-bot detection — so a reviewer's mistake doesn't
get promoted into a permanent rule.

✅ **Resolved:** Seed now from external best-practice — see the draft in
[6 · Constitution](06-constitution.md). It starts correcting immediately and grows from
your harvested findings over time.
