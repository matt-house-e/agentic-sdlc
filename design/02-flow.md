# 2 · Flow

> **The loop's backbone is a deterministic check, not an LLM saying "looks done."**

## The end-to-end loop

```
   ┌─────────────────────────────────────────────────────────────┐
   │                                                             │
   ▼                                                             │
 ISSUE ──► PLAN ──► WORK ──► SIMPLIFY ──► VERIFY ──► SHIP ──► LEARN
   │        │        │          │     ┌────┴────┐     │        │
intent    fresh-   single-    3-lens │ tests   │   PR +     harvest
in the    Claude   threaded   clean  │ lint    │   labels   findings →
issue/PR  review   coding     up     │ build   │   + auto-  invariants
          of plan  loop              │ evals   │   merge    (gated)
                                     └─────────┘
                                  THE SPINE: real
                                  pass/fail gates every
                                  transition. No green
                                  check → no progress.
   ▲                                                             │
   └─────────────── knowledge compounds back ───────────────────┘
```

Each box is (or becomes) a **`SKILL.md` skill** with a small JSON hand-off. `PLAN`,
`SIMPLIFY`, `VERIFY`, `LEARN` mostly exist in today's `ship_issue`; the move is to
*name* them, *script* their plumbing, and *gate* them on real checks.

## Three surfaces — and the hard line between them

The workflow has three distinct surfaces. The mistake would be blurring them:

| Surface | Mode | You are… |
|---|---|---|
| **Design** (scope → issues) | Interactive chat + `/grill-me` | In the loop, thinking |
| **Build** (`ship_issue` ×N) | Fire-and-forget, parallel, isolated | Gone / asleep |
| **Review** (the digest) | Async pull, end-of-run | Skimming + deciding |

- **Everything before the issue is human-paced** — never rushed by automation; that's where `/grill-me` earns its keep.
- **Everything after the issue is autonomous** — fired via `claude agents` (Agent View), which gives parallel runs + auto-worktree isolation + a monitor for free ([build decisions](07-build-decisions.md)).
- **The GitHub issue is the handoff contract** between them. (Which is *why* per-issue intent lives in the issue, not in repo spec files — same decision as [the knowledge loop](03-knowledge-loop.md).)

**Review = digest + GitHub.** Each run emits a short summary (shipped/blocked · rules-learned ·
parked question); you review the diffs/checks that matter in the PR. No custom dashboard — the
PR *is* the review artifact; the digest just points you at the two that need you.

```
WAKE-UP DIGEST  (3 runs overnight)
#812 add-rate-limit     ✅ merged   +1 invariant
#815 fix-webhook-retry  ✅ PR open  checks green → review
#818 refactor-auth      ⚠ parked    "2 valid approaches, need your call"
→ 1 needs you (#818), 1 to glance at (#815)
```

## The spine: verification, not vibes

Anthropic's load-bearing principle — *"if you can't verify it, don't ship it."* The
pipeline must close on **deterministic** signals:

| Gate | Check | Hard rule |
|---|---|---|
| Lint/format | `ruff check` **and** `ruff format --check` | Both — green lint ≠ green format |
| Tests | `pytest` (with worktree `PYTHONPATH`) | No red check opens a PR |
| Evals | filtered scenarios, behaviour changes only | The eval is the spec |
| Review | reviewer sees diff + criteria only | Scoped to *correctness/gaps*, not "find something" |

> This directly counters **reflection collapse** — an LLM verifier grows *confident*
> without growing *accurate*. Determinism is the antidote.

## Where subagents are used — and aren't

Research is blunt here: **multi-agent orchestration for coding is a fashionable trap**
(fragile, ~15× tokens, the famous 90% win was a *research* eval, not coding). So:

| Use a subagent for… | Keep single-threaded for… |
|---|---|
| Fresh-context **review** (unbiased by authorship) | The actual **coding loop** |
| Read-heavy **investigation** (return 1–2k summary) | Anything needing shared, mutating state |
| **Plan stress-test** (no prior context) | Sequential edit→verify→commit |

Subagents are for **context isolation**, never for parallelising the build.

## Context discipline — by architecture, not by limit

Long runs accumulate context, and attention degrades as they grow ("smart zone" → "dumb
zone"); silent autocompaction then loses fidelity. The fix is **structural, not a token
threshold** (a hardcoded limit would violate the thesis — that number only grows as windows
do):

- Each **phase-skill runs in a bounded/fresh context** — `plan` doesn't carry `work`'s noise.
- The **JSON hand-off artifact *is* the compaction** — a deliberate, inspectable summary, not an automatic lossy one.
- **No run leans on one giant accumulating context.** The decomposition gives smart-zone behaviour for free, and auto-rides bigger windows without changes.

This is a second reason the decomposition matters — beyond portability, it's how the
pipeline stays sharp on long work.

## Cost architecture (built in, not bolted on)

Token *prices* fall ~10×/yr, but total *spend* rises (Jevons) and reasoning models bill
hidden thinking at 5–10×. So efficiency is a durable discipline:

- **Route by role** — cheap tier for parallel grunt/subagents, frontier for plan/review.
- **Exploit caching** — Anthropic's 90% cache-read discount + 50% batch are *load-bearing
  cost levers*, not afterthoughts.
- **Spend lavishly only on bounded, high-value steps** (plan, review), not the whole loop.

✅ **Resolved:** `port-pr` stays an **occasional manual skill**, not a pipeline stage.
It keeps its value (your most bespoke asset) without adding weight to the main loop —
invoked on demand when a `scope:shared` PR needs mirroring.
