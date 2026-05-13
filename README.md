# agentic-sdlc

A Claude Code plugin for end-to-end agentic software development: from GitHub issue to merged PR, with self-review and a compounding-engineering feedback loop.

## What it ships

**Slash commands** (in `commands/`):

| Command | What it does |
|---|---|
| `/ship_issue <n>` | Ships issue `#n` end-to-end: plan → worktree → implement → test → PR → self-review → compounding loop → auto-merge |
| `/create_issue <text>` | Creates a GitHub issue with the right type / priority / component labels |
| `/create_branch <n>` | Creates a feature branch from an issue, with the right type prefix and a derived slug |
| `/create_pr <n>` | Opens a PR linked to issue `#n` with correct labels and a `Closes #n` link |

**Agents** (in `agents/`):

| Agent | What it does |
|---|---|
| `code-simplifier` | Reads the diff, fans out three parallel lenses (Reuse / Quality / Efficiency), applies the fixes |

## Design

The commands are **repo-agnostic**. Repo-specific bits (invariants, directory layout, label vocabulary, brand-name spelling) live in each project's `CLAUDE.md`. The commands read `CLAUDE.md` at runtime and defer to it.

Runtime detection of project flavor:

- Repo short name → `basename "$(git rev-parse --show-toplevel)"`
- Eval framework present → `test -d evals/`
- Makefile targets → `grep -E '^<target>:' Makefile`
- Language / framework → `pyproject.toml` / `package.json` / etc.

## Install (local development)

Add to a project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "agentic-sdlc-local": {
      "source": {
        "source": "local",
        "path": "/absolute/path/to/agentic-sdlc"
      }
    }
  },
  "enabledPlugins": {
    "agentic-sdlc@agentic-sdlc-local": true
  }
}
```

Then in that project:

```
/plugin install agentic-sdlc@agentic-sdlc-local
```

Plugin commands take precedence over repo-level `.claude/commands/*.md`, so per-repo duplicates can be removed.

## Where the per-repo bits live

Each project's `CLAUDE.md` should include a `## Repo invariants` section listing one-line rules that PRs must satisfy. The compounding loop in `/ship_issue` step 12 grows this section over time: when the auto-reviewer flags a violation of a rule that isn't yet written down, the rule is appended automatically.

Examples of repo-invariant rules (drawn from real Lucanet servicedesk repos):

- "Pydantic everywhere: structured data uses `BaseModel` — never `TypedDict`, `@dataclass`, or plain dicts"
- "Fat state: new data goes in `ServiceDeskState`, not passed as function arguments"
- "Static system content blocks must have `cache_control: {"type": "ephemeral"}`"

`code-simplifier` reads these invariants in its phase 0 and embeds them in every parallel-lens prompt so they're never flagged as over-engineering.

## Status

- v0.1.0 — initial extraction from sibling `ai-servicedesk` + `hr-servicedesk` repos
- Not yet published anywhere; install via local marketplace
