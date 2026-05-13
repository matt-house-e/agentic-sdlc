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
| `/port-pr <n>` | Ports a merged `scope:shared` PR from one repo into its sibling — applies the diff, resolves conflicts, opens a mirror PR with `Mirrors <owner>/<repo>#<n>` in the body |

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
        "source": "directory",
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

## Cross-repo porting (sibling servicedesks)

Two sibling repos (`ai-servicedesk` / `hr-servicedesk`) share most of their tooling, agents, prompts, and infra — but each has domain-specific code that must *not* cross over. The plugin uses three PR labels to control porting:

| Label | Meaning |
|---|---|
| `scope:it-only` | Default for `ai-servicedesk` PRs. Stays in the IT repo. |
| `scope:hr-only` | Default for `hr-servicedesk` PRs. Stays in the HR repo. |
| `scope:shared` | Generic change. After merge, `/port-pr` mirrors it into the sibling repo. |

`/ship_issue` step 10 applies the default scope label based on the repo (or a `.agentic-sdlc/config.json` override) and offers to upgrade to `scope:shared` when the diff touches paths that are likely identical across both repos (`.github/workflows/`, `prompts/`, `CLAUDE.md`, `Makefile`, etc.).

After a `scope:shared` PR merges, run `/port-pr <n>` from the sibling repo's working directory. It:

1. Fetches the source PR's merged diff via `gh pr diff`
2. Creates a `port/<source-repo>-<n>-<slug>` worktree from `origin/main`
3. Applies the diff with `git apply --3way`, falling back to `--reject` for conflicts the agent resolves semantically
4. Translates contextual domain tokens (paths, brand strings) without rewriting logic
5. Verifies (lint + tests + relevant evals)
6. Opens a mirror PR with `Mirrors <owner>/<repo>#<n>` in the body
7. Enables auto-merge

Per-repo configuration lives in `.agentic-sdlc/config.json`:

```json
{
  "sibling": "LucaNet-Main/hr-servicedesk",
  "scope_default": "scope:it-only"
}
```

For known servicedesks (`ai-servicedesk` ↔ `hr-servicedesk`), the mapping is built in and the config file is optional.

A future enhancement will auto-dispatch `/port-pr` from a GitHub Action on `scope:shared` merge — see the bottom of `commands/port-pr.md` for the sketch.

## Status

- v0.2.0 — `/port-pr` slash command + `scope:*` label set
- v0.1.1 — fix: poll PR reviews directly in `ship_issue` step 12 (workflow_run head_sha gotcha)
- v0.1.0 — initial extraction from sibling `ai-servicedesk` + `hr-servicedesk` repos
- Installed via local-directory marketplace; not yet published
