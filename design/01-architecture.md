# 1 · Architecture

> **Author in open standards. Keep orchestration thin. Don't build a converter —
> the platform shipped one.**

## The stack, by portability

Research classified every layer of an agentic toolkit. The headline: the *data and
instruction* layers are now **portable standards**; only *orchestration* stays proprietary.

| Layer | Status | Bet on |
|---|---|---|
| Memory / instructions | ✅ **Portable standard** | `AGENTS.md` (≈24 agents, 60k repos, Linux Foundation) |
| Skills / procedural logic | ✅ **Portable standard** | `SKILL.md` (open-sourced Dec 2025, ~32 tools) |
| Tools / integrations | ✅ **Portable standard** | `MCP` (OpenAI + Google + MS adopted) |
| Hooks | 🟡 Config proprietary, logic portable | Standalone **scripts** + thin config |
| Slash commands | 🔴 Proprietary | Thin per-harness **invoker** |
| Subagent dispatch | 🔴 Proprietary (Claude-only) | Degrade to single-agent elsewhere |
| Isolation / worktrees | 🔴 Harness's job — **don't own it** | Accept a workspace; never `git worktree add` |

## Three consequences

**1. Move pipeline logic out of the 587-line command and into `SKILL.md` skills.**
The procedural logic becomes portable across ~32 tools for free; the slash command
shrinks to a thin invoker. This also fixes the real coupling: today the monolith's
*spine* (subagent routing, `$ARGUMENTS`, frontmatter) is the harness-locked part.

**2. Make `AGENTS.md` the canonical knowledge home; generate/import `CLAUDE.md`.**
Author once, in the cross-tool standard. The knowledge loop writes here.

**3. Stop owning isolation.** `ship_issue` currently creates *and* removes worktrees
(steps 5 & 14). That collides head-on with Codex's `spawn_agent` model and is the single
biggest portability blocker. Skills should **accept a workspace**, not create one.

## Why no converter

The first research round suggested a "generate-don't-flatten" build step (like the
reference plugin's `src/converters/`). The contrarian round overruled it with evidence:
**AGENTS.md + SKILL.md + MCP already run natively across harnesses**, and free
converters exist (Skill Porter, wshobson/agents → "consumed natively by Codex, Cursor,
OpenCode, Gemini CLI, Copilot"). Building your own rebuilds a shipped standard and
creates a translation matrix against N harnesses that each rev monthly — the canonical
maintenance trap.

> **Rule:** Author in the standard. If you ever need a non-native target, reach for an
> existing converter. Never hand-maintain N copies.

## CLI vs MCP — capabilities, two ways

Both give the agent powers; they trade off differently. **Default to CLI; reach for MCP
when it earns its place.**

| | CLI tools (`gh`, `git`, `wrangler`, `psql`) | MCP servers |
|---|---|---|
| Maturity | Battle-tested; the model already knows them | Newer; quality varies per server |
| **Context cost** | **~zero** — one Bash tool, on demand | **Every tool schema is always-on context** |
| Output | Unstructured text (agent parses) | Structured, typed, validated |
| Auth | env / config you manage | Harness-managed OAuth |
| Maintenance | Vendored binary, nothing to run | A server to run, trust, update |

**Decision rule:**
- **Has a good CLI? Use the CLI.** GitHub→`gh`, plus git/ruff/pytest/make/`wrangler`.
  Don't wrap a great CLI in an MCP — it adds context bloat and a moving part for no gain.
- **Use MCP when:** no solid CLI exists; you need typed results or a *curated safe subset*
  of an API; OAuth SaaS (Notion, Gmail, Linear); or one integration reused across clients.
- **Convergence:** Anthropic's "code execution with MCP" (Nov 2025) and Cloudflare's
  "Code Mode" show calling tools *as code/CLI* cuts tokens sharply — schemas stop hogging
  context. Even with MCP available, prefer invoking via code.

> For your stack: CLI for `gh`/git/ruff/pytest/make/`wrangler`; MCP for OAuth SaaS; custom
> services → CLI if one exists, else a thin MCP only when you need a typed/safe surface.

## The one piece you *can't* rent: the state-envelope contract

Decomposing the monolith into skills is the right architectural move — but it has a cost
the standards don't cover. A single coherent context today carries state implicitly
(resolved base branch, task list, scope label). Split naively and that evaporates.

So decomposition is **gated on** defining a small contract first:

- **An immutable plan artifact** — progress lives in git commits + the issue, not a
  mutated plan ("the plan is the spec, not the scratchpad").
- **A structured return envelope** — each skill returns a small JSON summary to its
  caller (`return-to-caller`), not 10k tokens of transcript.

This is the one genuinely architectural bet, and it pays off **within your current single
harness** regardless of portability.

## Model selection as config, not prose

Today: `"Opus for planning, Sonnet for implementation"` is hardcoded inline. Instead,
express **capability roles** resolved in one file:

```
# models.toml  (illustrative)
[roles.planner]      tier = "frontier"  reasoning = "high"
[roles.implementer]  tier = "workhorse" reasoning = "medium"
[roles.reviewer]     tier = "frontier"  reasoning = "high"
[roles.grunt]        tier = "cheap"     reasoning = "none"
```

Prompts reference **roles**, never model IDs. Swapping a model = one config edit.
This is the cheap, durable half of "model abstraction" — see [roadmap](04-roadmap.md)
for why the *gateway* half is deferred.

✅ **Resolved:** `AGENTS.md` is the canonical knowledge home; `CLAUDE.md` is
generated/imported from it (Claude Code reads it via import). Author once, in the
cross-tool standard — the knowledge loop writes here.
