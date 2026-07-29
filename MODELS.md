# Model roles

The harness references **capability roles**, never hardcoded model names. Each role maps to
a model **tier alias** — so swapping a model is one edit here, and the harness auto-rides
model upgrades within a tier.

Claude Code has no runtime that reads this file; it's the **single source of truth** the
skills resolve into, via two routing paths (a skill's frontmatter can't pin a `model:`
directly):

1. **The harness and its `ship-review` fork inherit the session tier.** `/ship_issue` runs in
   your session's context, and a `context: fork` uses the default `general-purpose` agent,
   which inherits the session model — so launch `/ship_issue` at the **planner** tier and both
   follow it.
2. **Nested `Agent` dispatches pin explicitly**: the optional token-heavy implementation loop
   dispatches an **implementer**-tier (`sonnet`) subagent; a gnarly diff dispatches the
   `code-simplifier` agent. Reference roles/aliases, never pinned model IDs — and always
   foreground (`run_in_background: false`).

## Role → tier

| Role | Tier alias | Where it's used |
|---|---|---|
| `planner` | `opus` | the `/ship_issue` session: pre-flight risk read, plan, implementation judgment |
| `reviewer` | session tier | the risk-gated `ship-review` fork (inherits the session) |
| `implementer` | `sonnet` | the optional delegated token-heavy build loop |
| `grunt` | `haiku` | mechanical scans, digest summarisation |

## Aliases vs pinned IDs

- **Harness → tier aliases** (`opus` / `sonnet` / `haiku`). You *want* to auto-ride model
  upgrades — that's the "rent the engine" thesis.
- **Evals → pinned model IDs** (e.g. `claude-opus-4-8`). Reproducibility is the point of a
  swap-test; a drifting alias would invalidate the comparison.

## Review horsepower — *match it to the cost of being wrong*

Whether independent review runs at all is decided by `ship_issue`'s **signal table** (S1–S11)
— one risk classifier, used for review arming, plan depth, and the operational pre-flight
alike. The same signals say when review deserves top-tier horsepower: auth/security (S2),
migrations (S1), LLM behavior (S4), and cross-component journeys (S9) are the
cost-of-being-wrong signals — for those, launch the run (and therefore the inherited review
fork) at the planner tier rather than economizing. Thresholds are tunable as run records
accumulate (see `design/10-harness.md`, self-pruning).

> See `design/07-build-decisions.md` and `design/09-safety-and-runtime.md` for the original
> rationale; `design/10-harness.md` for the current architecture.
