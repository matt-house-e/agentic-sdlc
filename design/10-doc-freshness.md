# 10 · Doc freshness

> **Docs must always show the as-is state. Policies don't achieve that; forcing
> functions tied to guaranteed events do.**

## The failure mode, observed three times in one repo

1. `design/README.md` + `04-roadmap.md` described a plan; the plan shipped (Phases 1–4);
   nobody updated the docs (#20). Staleness was never tied to the event that caused it.
2. `prune-merged-worktrees.sh` was wired to "after auto-merge" — a trigger that never
   fired in this repo's real history. Fixed by moving it to "start of every run" (#18).
3. `KNOWLEDGE.md`'s freshness pass is self-documented as "not yet automated" — the
   disease, correctly diagnosed, never cured.

The common cause: **no signal flows from the code-change event to the doc it
invalidates.** "Remember to update the docs" is a policy. A change three files away
from a doc gives nobody — human or agent — a reason to check it. The industry
literature converges on the same diagnosis (Procida: "documentation is guaranteed to
decay unless there is an explicit, effective programme in place to maintain it";
Google's SWE book; Write the Docs; see [doc 5](05-evidence.md) additions).

One more result that shapes everything below: naive LLM checking ("does this diff
match this doc?") flags **98% of pairs** as inconsistent (DocPrism,
arxiv 2511.00215), because docs legitimately omit implementation detail. Unconstrained
semantic judgment drowns you. Deterministic checks triage; LLM judgment rides only on
sessions already running, constrained to factual contradictions.

## The pattern: three layers on one owned map

**Rent the patterns (Danger fileMatch, GitLab docs nudge, Kubernetes Prow, GDS review
dates are all the same shape), own the map + the cadence** — the #13 philosophy applied
to docs.

### Layer 0 — the docs map (owned knowledge)

A small per-repo mapping of source globs → doc files, living in
`.agentic-sdlc/config.json` (the existing per-repo hook). For this repo:

```
skills/**, agents/**, scripts/**  →  README.md, design/04-roadmap.md
skills/ship_issue/CONTRACT.md     →  design/01-architecture.md, design/02-flow.md
.claude-plugin/plugin.json        →  README.md (## Status)
```

The map is the single point of drift in all three layers. Mitigations: keep it tiny;
layer 1 verifies the map's own paths still exist (a map entry pointing at a dead path
is itself a failed check).

### Layer 1 — deterministic gate at a guaranteed event (free)

One tested script, `scripts/check-docs-map.sh <base>..<head>`, three checks:

1. **Pair check** — code glob changed, mapped doc unchanged → nudge (never block;
   GitLab ships the same rule as a nudge for a reason: rubber-stamping and skip-label
   habituation kill hard gates).
2. **Dead-reference scan** — file paths named in docs that no longer exist in the tree
   (>25% of top-1000 GitHub projects have at least one; arxiv 2307.04291). This is the
   strongest zero-cost "as-is state" check that exists.
3. **Map self-check** — every glob and doc path in the map resolves.

**Guaranteed event, this repo (no CI):** the `ship-verify` phase — deterministic gates
already live there; result rides the envelope, renders as a PR-body note + unchecked
box, exactly like the existing generic-path detector at the open-PR step.
**Guaranteed event, consuming repos with CI:** the same script as a PR-time Action that
labels `docs-review-needed` — the `check-docs_map.py` shape, unchanged.

### Layer 2 — semantic judgment, piggybacked only (zero marginal cost)

Never a standing LLM job. Two rides on sessions already paid for:

- **ship-review**: replace the vague completeness bullet ("If architecture changed:
  `CLAUDE.md` and/or an ADR is updated") with: *consume layer 1's output; for each
  flagged pair, judge whether the diff factually contradicts the doc — flag, don't
  silently auto-edit; surface in question surfaces.* Constrained to factual
  contradiction per DocPrism.
- **Consuming repos' existing Claude PR reviewer**: add the same checklist line to its
  prompt (Google eng-practices has ready-made wording). Where that reviewer exists,
  the plugin defers — `docs_check: external` in config — so nothing double-counts.

### Layer 3 — scheduled sweep for the cold corners (the #13 hygiene pass)

Per-PR checks only see docs mapped to the diff. Whole-corpus staleness — unresolved 🔵
markers whose subject already shipped, `## Status` log vs actual PR history, the
KNOWLEDGE.md five-outcome refresh — belongs to the Phase-5 hygiene sweep that files an
issue and ships it through the pipeline. This *is* the missing freshness-pass engine:
the engine is the pipeline itself; the sweep just files the issue.

## Genre frontmatter — the fix for #20's root cause

The design corpus rotted because plan-docs were held to no standard once executed.
Every doc declares its genre: `status: as-is | plan | historical`. Layer 1 holds
`as-is` docs to the map; `plan` docs carry 🔵 markers, which become greppable staleness
sentinels (a 🔵 in a doc whose mapped code has since shipped = a layer-3 finding);
executed plans get flipped to `historical` instead of silently lying.

## Build / defer / cut

| Investment | Verdict | Why |
|---|---|---|
| `check-docs-map.sh` (pair + dead-ref + self-check) | 🟢 **Build** | Deterministic, free, tested like the other scripts; would have caught #20 months earlier |
| Map in `.agentic-sdlc/config.json` | 🟢 **Build** | Existing hook; no new file format |
| Sharpen ship-review completeness bullet | 🟢 **Build** (tiny) | Turns the one existing check from vibes into a consumer of layer 1 |
| Genre frontmatter on design/ + README | 🟢 **Build** (tiny) | Root-cause fix for plan-docs rotting after execution |
| `docs_check: external` deference flag | 🟢 **Build** (tiny) | No double-counting with work-repo CI / Claude reviewers |
| 🔵-marker + Status-log sweep | 🟡 **Defer to #13** | Belongs to the scheduled hygiene pass, not per-PR |
| Review-date / TTL frontmatter (GDS model) | 🟡 **Defer** | Checks age, not correctness; KNOWLEDGE.md already says age ≠ stale |
| Standing LLM drift job (per-PR or cron) | 🔴 **Cut** | Recurring API cost for personal repos; DocPrism false-positive wall |
| Swimm / DeepDocs / Mintlify | 🔴 **Cut** | Paid platforms; the deterministic 80% is a ~100-line script |
| CODEOWNERS docs-owner gating | 🔴 **Cut** | Meaningless solo; guarantees a reviewer, not an update |

## What "done" looks like

- Every mechanism names its guaranteed event; "after auto-merge"-shaped triggers are
  rejected at design time.
- A PR touching `skills/` without touching the roadmap gets flagged the same day, not
  months later.
- Docs that describe executed plans say so, instead of impersonating proposals.
- Zero standing API spend; semantic judgment only ever rides sessions already running.

🔵 **Decision:** port the work repo's `check-docs.py` / `check-docs_map.py` directly
(Python) or reimplement in bash to match `scripts/` idiom + test harness?
🔵 **Decision:** should layer 1 also run at ship_issue step 0 (like the worktree
sweep) so drift from *manual* commits gets caught on the next pipeline run, not just
drift from pipeline PRs?
