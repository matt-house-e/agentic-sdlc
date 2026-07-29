# 10 · The harness (current architecture)

> **Status:** current — supersedes the six-phase orchestrator described in `01-architecture.md`
> and `02-flow.md` (kept for the record). Decided 2026-07-29 from the evidence in issue #26.

## The pivot in one paragraph

`/ship_issue` was a **process**: six isolated phase-skills (`plan → work → simplify → verify →
review → learn`) behind a state-envelope contract, each in a fresh fork. It is now a
**harness**: one agent runs the whole issue in one coherent context, surrounded by the things
it cannot talk its way past — deterministic gates, authority boundaries, an operational
pre-flight, risk-gated independent review, and a run record. Choreography was deleted; gates
were kept and strengthened.

## The evidence (issue #26, three case studies)

1. **Small fix, full ceremony.** A ~23-line change dispatched six agents; only the plan pass
   contributed. Simplify, review, and learn produced nothing; full suites ran repeatedly with
   no new evidence between runs.
2. **Complex feature, misallocated ceremony.** Five horizontally-split PRs each received full
   ceremony while the assembled user journey was never proven. Waste: repeated context
   reconstruction at every fork boundary, redundant verification, mandatory low-yield phases.
3. **The production incident.** High ceremony coexisted with inadequate operational safety.
   Nobody asked the operational questions (queue starvation, backfill blast radius, LLM cost,
   kill switch); backfill shipped coupled to first rollout; production was deployed without
   explicit authorization; there was no recovery mode; an issue was closed by a PR that didn't
   meet its acceptance criteria.

The synthesis: **ceremony level and risk level are different axes.** The failures lived in the
gaps *between* phases — missing questions and missing authority boundaries — which no amount of
phase ceremony fixes.

## The decay argument

The phase decomposition compensated for 2025-era model weaknesses: drift over long tasks,
unreliable in-context self-review, small effective context. That compensation has **fixed
costs that do not shrink as models improve** — every fork re-reads the issue, diff, guidance,
and contract; every boundary risks drift that then needs anti-drift rules; every phase runs
whether or not it has anything to contribute. Meanwhile the benefit shrinks every model
generation. The pipeline was paying constant premiums against a decaying risk.

So the design rule is now:

> **Spend structure on what does not improve with the model.**

Four things qualify:

| Durable investment | Why it doesn't decay | Where it lives |
|---|---|---|
| **Deterministic gates** | A test suite is equally valuable at every capability level | one authoritative gate in `ship_issue`, re-armed by any post-gate commit; CI independently |
| **Authority boundaries** | A smarter agent reaches production *faster* — boundaries matter more, not less | hard rules in `ship_issue` + `templates/constitution.md`; mechanical enforcement tracked in #6 |
| **The durable substrate** | Issues/commits/PRs carrying the *why* serve humans and every future model | unchanged from the old design — its best surviving idea |
| **Ground truth about the process** | You can't prune what you can't see | the run record every run posts; feeds #15 |

Explicitly *not* on the list: fixed phase sequences, fork choreography, envelope plumbing,
mandatory simplify/review/learn stages. Those rented the model's reasoning through a prescribed
pipe, and the pipe became the bottleneck.

## The new flow

```
hygiene → pre-flight risk read → implement (one context, focused tests, logical commits)
       → THE GATE (lint+format / tests / filtered evals — fail closed, re-arms on any commit)
       → PR (idempotent, labels verified, closure integrity)
       → independent review IF a trigger fired (fresh fork, else skip with recorded reason)
       → harvest IF review produced a legitimate novel finding (admission bar per KNOWLEDGE.md)
       → auto-merge → run record + digest
```

Key properties:

- **One coherent context.** The thing that learned the risks during pre-flight is the same
  thing writing the code. No envelope plumbing, no re-grounding tax, no drift *between* phases
  because there are no phases. Subagents remain available as tools (an implementer-tier loop
  for token-heavy work, `code-simplifier` for a gnarly diff, the review fork) — reached for
  when useful, never mandatory. Nested `Agent` dispatches always run in the foreground
  (`run_in_background: false`) — the caller has nothing to interleave and a backgrounded
  dispatch ends the turn on an interim status line.
- **The pre-flight is the part that would have prevented the incident.** A deterministic
  signal list (migrations, auth, new deps, prompts/evals, queues/workers, bulk data, external
  writes, production data, cross-component scope, deploy/infra changes) arms the safeguards.
  Any queue/bulk/external/production signal forces the operational questions — volume, cost,
  failure behavior, starvation, kill switch, rollback — to be answered in a posted plan
  *before implementation*. Backfills are structurally severed from first rollout: always a
  separate, explicitly-approved issue. Cross-component features start with a tracer-bullet
  slice through the full user journey before horizontal breadth.
- **Verification has one owner.** Focused tests during implementation; one authoritative gate
  after the last code change; any later commit (review fixes included) re-arms it. The old
  pipeline ran suites in work, simplify, verify, and CI — and still let review-phase fixes
  land *after* the deterministic gate. The new rule closes that hole and deletes the
  redundancy.
- **Independent review is risk-gated, not ritual.** The fresh-context fork (`ship-review`)
  survives — authorship blindness is the one thing a same-context agent genuinely cannot
  self-supply — but it runs only when a trigger fires. A skipped review always records its
  reason in the run record. As models improve, the trigger list shrinks by evidence; shrinking
  a list is a one-line edit, not a re-architecture.
- **Learning is opportunistic, not a phase.** A legitimate, novel review finding still gets
  harvested into the host repo's knowledge home under `KNOWLEDGE.md`'s admission bar — but a
  clean review dispatches nothing. In the old pipeline learn almost always no-opped at full
  fork cost.
- **Authority boundaries are hard rules, stated where the agent works.** Shipping an issue
  never implies deploying it. No production deployment, backfill, bulk mutation, or at-scale
  external write without an explicit human grant quoted in the run record. The standard tagged
  release process is never bypassed. "Closes #n" requires the acceptance criteria to be met or
  a scope-change record on the issue first.

## What was deleted, and where its value went

| Deleted | Its value now lives |
|---|---|
| `ship-plan` fork | Pre-flight + inline plan; a *posted* plan (issue comment) when any risk signal fires — the plan stress-test survives as an optional fresh-subagent check for risky work |
| `ship-work` fork | The harness's implementation loop (same per-task discipline: focused tests, one logical commit per task, why in the body, malleable plan / immutable spec, `ce-debug` escalation) |
| `ship-simplify` fork | `code-simplifier` agent retained; dispatched at the harness's discretion for large diffs instead of unconditionally |
| `ship-verify` fork | THE GATE — same checks, now run once at the right moment and re-armed by any post-gate commit |
| `ship-learn` fork | The harvest step, run only when there is something to harvest; `wait-for-review.sh` still owns the CI-reviewer wait |
| `CONTRACT.md` (state envelope) | The substrate rules (spec immutable, decisions durable, why in commit bodies) moved into the harness skill; the envelope itself is gone because there are no boundaries to carry state across. Work too large for one context is a **split-the-issue park**, not a decomposition problem |

## Self-pruning (the anti-overfitting mechanism)

Every run posts a machine-readable **run record** on the PR: which signals fired, whether
review ran and what it found, what the gate caught, what was harvested, what was skipped and
why. That is the plugin's evolution mechanism: process elements that repeatedly contribute
nothing become deletion candidates *on evidence*; triggers that repeatedly miss become
tightening candidates. Issue #15 (observability) is the aggregation layer over these records.

The rule this encodes: **don't hand-design the right process after each retro — build the
measurement that lets the process shed weight as models earn trust.** Gates get stronger over
time; choreography gets deleted.

## Open questions

- **Trigger calibration.** The review trigger list and the operational signal list are
  first-draft. The run records exist precisely so they can be tuned on evidence.
- **Mechanical enforcement of authority boundaries.** Today they are stated rules the harness
  obeys; #6 (sandbox, branch protection, credential hygiene) is what makes them physical.
- **Incident recovery.** Deliberately *not* built into `ship_issue` — recovery is a different
  job with inverted priorities (restore known-good first, no backfills/deletes, minimal
  verification, standard release path). `ce-debug` covers diagnosis today; a dedicated
  recovery skill is future work if wild use shows the need.
