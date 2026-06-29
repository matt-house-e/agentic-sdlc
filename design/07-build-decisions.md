# 7 · Build decisions (resolved)

> **The three Phase-1 reality-checks, settled — plus the finding that shrank the build:
> the parallel-fire + isolation + monitor surface is already native.**

## The big finding: most of the runtime is *rent*, not build

`claude agents` (**Agent View**, v2.1.139+, research preview) already provides the
fire-and-forget workflow natively ([docs](https://code.claude.com/docs/en/agent-view.md)):

- **Fire N in parallel** — dispatch `/ship_issue 123`, `124`… each a separate background session.
- **Auto-isolation** — each session is moved into its **own git worktree** before editing. You don't set up or tear down.
- **Walk away** — a per-user supervisor daemon keeps runs alive after you close the view.
- **Wake to a digest** — rows grouped **Needs input / Working / Completed**, each with a status line + **PR label**.

So the **Build** and **Review** surfaces are mostly rent. The only thing to build is a thin
**roll-up digest** (one line per run: shipped/blocked + rules-learned + parked question) —
and it maps almost 1:1 to Agent View rows.

## RC1 · Isolation — who creates the worktree?

✅ **`ship_issue` stops creating its own worktree.** It must **detect-and-skip** when already
isolated (else worktree-inside-worktree under Agent View). Isolation comes from:
- **Agent View dispatch** — the interactive fire-and-forget path (harness owns it), or
- `claude --bg --worktree` — the scripted/CI path.

**Hard requirement this exposes:** fire-and-forget means `ship_issue` must run
**non-interactively**. Headless skills work (`claude -p "/ship_issue 123"`) but **modal
prompts don't**. So resolve every decision upfront or default safely, and **park to "Needs
input" only on a genuine blocker**.

## RC2 · Skills vs commands — and proceed-vs-park

✅ **One explicit `/ship_issue <n>`** orchestrating internal **`SKILL.md` phase-skills**
(`plan`/`work`/`simplify`/`verify`/`review`/`learn`). Explicit entry (deterministic for
walk-away) + portable, testable internals. Not auto-invoked, not hand-composed.

✅ **Proceed-by-default, park-by-exception.** The rule:

| | Reversible (cheap follow-up undo) | Irreversible / outward-facing |
|---|---|---|
| **Implementation detail** (mine) | ✅ assume + log | ⚠️ park |
| **Product / UX / "done"** (yours) | ⚠️ park | 🛑 park, hard stop |

**Park only when one trips:** (1) irreversible/outward-facing, (2) not yours to decide /
acceptance criteria missing or contradictory, (3) architectural fork with lasting
consequence and no codebase precedent, (4) scope explosion. **Otherwise assume + proceed +
log** the assumption to the digest. One explicit **always-park zone**: behaviour-changing
prompt/eval edits. Per-area tuning → [issue #5](https://github.com/matt-house-e/agentic-sdlc/issues/5).

## RC3 · Model roles

✅ **Role→tier table** (authoring-time convention — Claude Code has no capability-registry
runtime; realized via each skill's `model:` field):

| Role | Tier | Where |
|---|---|---|
| `planner` | opus | plan, design sketch |
| `reviewer` | **sonnet → opus by risk** | self-review, the "correct me" gate |
| `implementer` | sonnet | the token-heavy build loop |
| `grunt` / triage | haiku | mechanical scans, digest summarisation |

✅ **Aliases in the pipeline** (`opus`/`sonnet`/`haiku` — auto-ride model upgrades),
**pinned IDs only in evals** (reproducibility).

✅ **Reviewer escalation principle — *match review horsepower to the cost of being wrong.***
Default Sonnet; escalate to Opus when any fires: high-risk zone (auth/secrets, migration,
prompts/evals, public API) · multi-component or large diff (~5 files / ~150 lines) ·
ADR/new dependency · re-review after a real defect · thin test coverage. Reuses the **same
risk signal** as the park rule — one classifier, two uses. Thresholds tunable by real runs.

## What this means for the build

- **Don't build:** parallel orchestration, worktree isolation, a monitoring UI — all native.
- **Do build:** the roll-up digest; the non-interactive `ship_issue`; the phase-skills; the
  detect-and-skip isolation guard; the role→tier `model:` fields; the risk classifier shared
  by park + review escalation.
