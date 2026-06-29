# 0 · Thesis

> **Own the artifacts. Rent the engine. Build only the gap.**

## The core principle

Your build effort should go where value **compounds**, not where it **depreciates**.

- **Models and harnesses are depreciating assets** — they improve every month whether
  or not you touch them. Anything you build tightly coupled to them rots on their schedule.
- **Your knowledge and your pipeline logic are appreciating assets** — they only grow
  if you build the machinery to capture them. Nobody else can build them for you.

So: **spend at the bottom of the stack (durable), rent the top (volatile).**

## Own vs rent

| Layer | Decision | Why |
|---|---|---|
| Models (Opus, GPT, Gemini) | **Rent, always** | Improves monthly; swapping is the *point* |
| Harness (Claude Code, Codex) | **Rent — stay on standards** | Execution engine; don't marry one |
| External tools / integrations | **Rent via MCP** | Won the integration layer; survives any harness |
| Commodity steps (debug, brainstorm) | **Rent, vendored + pinned** | Undifferentiated; let others eat the churn |
| **Orchestration (your pipeline)** | **Own — thin & portable** | Durable *shape*, swap the *implementation* |
| **Knowledge & standards** | **Own — this is the moat** | Appreciates; encodes *your* judgment |

## Durable vs volatile — what to commit to

| Durable (commit) | Volatile (keep swappable) |
|---|---|
| Your knowledge/invariants file | Specific model IDs |
| Decision log (the *why*) | Reasoning-knob names, caching mechanics |
| The OpenAI-compatible chat schema | Exact prompt wording (re-tune per model) |
| MCP for tools | Slash-command / subagent formats |
| AGENTS.md + SKILL.md (open standards) | Which harness you run today |
| Capability *roles* (planner/implementer) | The model behind each role |

## A standing objective: good DX *and* AX

Two experiences, both design targets:

- **DX (developer experience)** — your three surfaces (design / build / review). The human stays in the loop where it matters and walks away where it doesn't.
- **AX (agent experience)** — how well the *environment* is set up for the agent to perceive and act: fast/reliable tests, a sharp `AGENTS.md`, clean tool/CLI availability, clear errors.

The pipeline **depends on** good AX and should **help maintain** it — the knowledge loop
harvests AX/DX frictions (e.g. "tests too slow to use as a gate"), not just code invariants.

## The one nuance that makes this work

A system that only *learns from you* calcifies your bad habits at scale. The knowledge
loop must also **correct** you — but research (see [knowledge loop](03-knowledge-loop.md))
shows correction works by **forcing you to justify a deviation** from good practice,
**not** by overriding your judgment. Present evidence always beats a stored rule.

That's a stronger version of what you asked for: *learn how I build, and make me defend
it when it conflicts with good engineering.*

✅ **Resolved:** Claude Code for the foreseeable future (may change). So portability is
*not* a build goal — we get it as a **near-free byproduct** of authoring in the open
standards (AGENTS.md / SKILL.md / MCP), and we build **no converters or per-harness
adapters** until a real second harness forces the question.
