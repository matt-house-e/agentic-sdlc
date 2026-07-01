# Agentic SDLC — Design Review

> **The bet in one line:** Own the *knowledge* and your *pipeline logic*; rent the *models* and the *harness*; build only what the platform isn't already commoditising for free.

These docs distill two rounds of research (8 agents, ~40 sources) into a direction
that survives the pace of AI change. **Phases 1-4 of the [roadmap](04-roadmap.md) are
implemented and merged** — see the top-level `README.md`'s Status log (v0.3.0 through
v0.6.0) — so this corpus now doubles as the record of what shipped and why, not just a
proposal. What's left is a short list of items explicitly **deferred** (🟡 in the
roadmap); there are no more open 🔵 decisions in the corpus.

## Read in this order

| # | Doc | What it answers | Read time |
|---|-----|-----------------|-----------|
| 0 | [Thesis](00-thesis.md) | What we own vs rent, and why it's durable | 2 min |
| 1 | [Architecture](01-architecture.md) | The layered stack + what standards to bet on | 4 min |
| 2 | [Flow](02-flow.md) | The end-to-end loop: issue → ship → learn | 3 min |
| 3 | [Knowledge loop](03-knowledge-loop.md) | How the system learns *and corrects* you | 3 min |
| 6 | [Constitution](06-constitution.md) | The seeded best-practice principles (draft) | 2 min |
| 7 | [Build decisions](07-build-decisions.md) | The 3 reality-checks resolved + what's rent vs build | 3 min |
| 8 | [Evals](08-evals.md) | How we measure "how we're doing" | 3 min |
| 9 | [Safety & runtime](09-safety-and-runtime.md) | The AFK blast-radius model (sandbox + gates) | 3 min |
| 4 | [Roadmap](04-roadmap.md) | Build now / defer / cut — sequenced | 3 min |
| 5 | [Evidence](05-evidence.md) | The research behind every claim + citations | skim |

## What changed from my first instinct

Research pulled the plan **leaner**. Five things I was going to build turned out to be
either already-shipped standards or premature:

| First instinct | After research |
|---|---|
| Build a cross-harness converter | ❌ Cut — AGENTS.md + SKILL.md + MCP *are* the standard |
| Build a model/provider abstraction | ⏸ Defer — do the cheap config indirection only |
| Build knowledge-GC machinery | ✂️ Trim — discipline, not a database engine |
| Constitution as a subsystem | ✂️ Trim — ~40 lines of advisory text |
| Constitution *overrules* you | 🔄 Inverted — it makes you *justify deviations* |

## Decisions resolved so far

| Question | Call |
|---|---|
| Multi-harness or single? | **Claude Code for now** — portability is a free byproduct of standards, no converter |
| Knowledge home | **AGENTS.md canonical**, generate `CLAUDE.md` from it |
| `port-pr` | **Occasional manual skill**, not a pipeline stage |
| Constitution | **Seed now** from best-practice — draft in [doc 6](06-constitution.md) |
| CLI vs MCP | **CLI-first**; MCP only when it earns its place (see [architecture](01-architecture.md)) |
| Isolation (RC1) | `ship_issue` **stops owning worktrees**; isolation via Agent View / `--bg --worktree`; runs **non-interactively** |
| Skills vs commands (RC2) | One explicit `/ship_issue` over internal **`SKILL.md` phase-skills**; **proceed-by-default, park-by-exception** |
| Model roles (RC3) | Role→tier table; **aliases in pipeline, pinned in evals**; reviewer **Sonnet→Opus by risk** |
| Evals | **Mine own git history** as golden set; deterministic graders; rent Inspect AI ([doc 8](08-evals.md)) |
| AFK safety | Auto-mode gates interruption not blast radius → **sandbox + branch protection + credential hygiene** + risk-gated auto-merge ([doc 9](09-safety-and-runtime.md)) |
| Context rot | **Discipline by architecture** (fresh phase contexts + hand-off), no hardcoded token limit |
| DX + AX | Both are standing **objectives**; loop harvests AX/DX frictions too |
| Phase sequencing | **Proceed incrementally, phase by phase** — Phases 1-4 shipped without locking the architecture doc first (🟢 in [roadmap](04-roadmap.md)) |

**Nothing left open:** the sequencing question above was the last 🔵 decision. What
remains is explicitly **deferred** (🟡 in [roadmap](04-roadmap.md)) — a freshness pass
for invariants, a provider gateway, and disposable brainstorm/ideate skills — not
undecided.

**Deferred (tracked):** constitution pruning → [#4](https://github.com/matt-house-e/agentic-sdlc/issues/4)
· per-area park-zone tuning → [#5](https://github.com/matt-house-e/agentic-sdlc/issues/5)
· AFK safety environment setup → [#6](https://github.com/matt-house-e/agentic-sdlc/issues/6).

## How to give feedback

Mark up any doc inline, or tell me which 🟡 deferred item to pick up next and which
claims you want challenged harder. Phases 1-4 are already committed to the real plugin
(see the top-level `README.md`'s Status log) — feedback here now targets what's still
deferred, plus anything shipped that you want revisited.
