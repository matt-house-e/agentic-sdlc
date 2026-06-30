# Model roles

The pipeline references **capability roles**, never hardcoded model names. Each role maps to
a model **tier alias** — so swapping a model is one edit here, and the pipeline auto-rides
model upgrades within a tier.

Claude Code has no runtime that reads this file; it's the **single source of truth** that the
commands/skills resolve into their `model:` fields (or `Agent` dispatch `model:` argument).

## Role → tier

| Role | Tier alias | Where it's used |
|---|---|---|
| `planner` | `opus` | design sketch, plan, plan stress-test |
| `reviewer` | `sonnet` → `opus` *(by risk)* | self-review, the "correct me" gate |
| `implementer` | `sonnet` | the token-heavy per-task build loop |
| `grunt` | `haiku` | mechanical scans, digest summarisation |

## Aliases vs pinned IDs

- **Pipeline → tier aliases** (`opus` / `sonnet` / `haiku`). You *want* to auto-ride model
  upgrades — that's the "rent the engine" thesis.
- **Evals → pinned model IDs** (e.g. `claude-opus-4-8`). Reproducibility is the point of a
  swap-test; a drifting alias would invalidate the comparison.

## Reviewer escalation — *match review horsepower to the cost of being wrong*

Default the `reviewer` to **Sonnet**; escalate to **Opus** when any fires:

- touches a high-risk zone — auth/secrets, DB/schema migration, behaviour-changing prompts/evals, public API/contract
- blast radius — spans multiple components, or the diff exceeds ~5 files / ~150 lines
- architectural weight — an ADR was created, or a new dependency/pattern introduced
- proven error-prone — re-review *after* a real defect was already found in this PR
- thin tests — low coverage on the changed code

This reuses the **same risk signal** that drives proceed-vs-park and the auto-merge gate —
one classifier, three uses. Thresholds are tunable as real runs calibrate them.

> See `design/07-build-decisions.md` and `design/09-safety-and-runtime.md` for the rationale.
