# agentic-sdlc

A Claude Code plugin for end-to-end agentic software development: from GitHub issue to merged PR, with self-review and a compounding-engineering feedback loop.

## What it ships

**Skills** (in `skills/`) — authored in the portable [`SKILL.md`](https://agentskills.io) standard
(slash commands have merged into skills; invoke any of these as `/<name>`):

| Skill | What it does |
|---|---|
| `/ship_issue <n>` | Ships issue `#n` end-to-end: plan → work → simplify → verify → PR → review → compounding loop → auto-merge. A **thin orchestrator** over six isolated phase-skills (see below) |
| `/create_issue <text>` | Creates a GitHub issue with the right type / priority / component labels |
| `/create_branch <n>` | Creates a feature branch from an issue, with the right type prefix and a derived slug |
| `/create_pr <n>` | Opens a PR linked to issue `#n` with correct labels and a `Closes #n` link |
| `/port-pr <n>` | Ports a merged `scope:shared` PR from one repo into its sibling — applies the diff, resolves conflicts, opens a mirror PR with `Mirrors <owner>/<repo>#<n>` in the body |
| `/ce-debug <ref>` | Systematic bug diagnosis — traces the full causal chain before fixing, test-first. **Vendored** (pinned) from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin); see `skills/ce-debug/VENDORED.md`. Also runs non-interactively inside `/ship_issue` when `work`/`verify` hit a failure they can't explain |

**Phase-skills** (in `skills/ship-*/`) — the six stages `/ship_issue` runs in order, each in a
**fresh, isolated context** (`context: fork`) that hands a small JSON envelope back to the
orchestrator. They are internal (`user-invocable: false`) — the orchestrator invokes them, you don't:

| Phase-skill | What it does |
|---|---|
| `ship-plan` | Understands the issue, self-grills the approach, breaks it into atomic tasks, runs a fresh-Claude plan stress-test, writes the approach + decisions to the issue |
| `ship-work` | Implements one task at a time (single-threaded, full context; delegates the heavy loop to an implementer-tier subagent), lint+test+commit per task |
| `ship-simplify` | Dispatches `code-simplifier`, applies its cleanups, commits them separately |
| `ship-verify` | The deterministic spine — lint **and** format, tests, filtered evals; fails closed on any red gate |
| `ship-review` | Fresh-context self-review of the PR diff (unbiased by authorship) against conventions / constitution / quality / completeness |
| `ship-learn` | The compounding loop — harvests legitimate, novel review findings into the host repo's knowledge home, routed by tier |

The hand-off between phases is governed by a **state-envelope contract**
(`skills/ship_issue/CONTRACT.md`): a thin JSON envelope (handles + status + an append-only
decisions ledger + one prose line) over a re-readable substrate (the issue, PR diff, and commits).
This is what keeps decomposition from drifting — see the contract for the full rationale.

**Agents** (in `agents/`):

| Agent | What it does |
|---|---|
| `code-simplifier` | Reads the diff, fans out three parallel lenses (Reuse / Quality / Efficiency), applies the fixes |

**Scripts** (in `scripts/`) — load-bearing plumbing extracted from the skills so it's
versioned and testable (run `bash scripts/tests/run.sh`):

| Script | What it does |
|---|---|
| `verify-pr-labels.sh <pr> <issue>` | Guarantees every source-issue label is on the PR (`gh pr create --label` aborts entirely on a missing label, so labels are applied after creation instead); exits non-zero if any is still missing |
| `wait-for-review.sh <pr> [timeout]` | Blocks until a PR review is submitted newer than the latest commit (polls reviews, not workflow runs by SHA); prints the verdict |
| `prune-merged-worktrees.sh [--dry-run]` | Removes `ship_issue`'s own `*-wt-*` worktrees and the harness's `.claude/worktrees/*` ones once `gh` confirms a merged PR for the branch (not ref-existence, which can't tell "merged" from "never pushed"); runs automatically at the start of every `/ship_issue` run, not just after auto-merge |

**Model roles** — `MODELS.md` maps capability roles (`planner`/`implementer`/`reviewer`/`grunt`)
to model tier aliases, so model choice is one edit and the pipeline auto-rides upgrades.

**Knowledge layer** — `KNOWLEDGE.md` defines the two-tier model the compounding loop feeds:
**invariants** (taste/convention — enforced) and the **constitution** (best-practice
principles — justify-or-deviate), with an admission bar to prevent rule bloat.
`templates/constitution.md` is an installable seed host repos curate.

## Design

The skills are **repo-agnostic**. Repo-specific bits (invariants, directory layout, label vocabulary, brand-name spelling) live in each project's `AGENTS.md` — the canonical knowledge home (`CLAUDE.md` is imported from it) — in two tiers, invariants and constitution (see `KNOWLEDGE.md`). The skills read it at runtime and defer to it.

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

Plugin skills take precedence over repo-level `.claude/commands/*.md` and `.claude/skills/*/`, so per-repo duplicates can be removed.

## Where the per-repo bits live

Each project's `CLAUDE.md` should include a `## Repo invariants` section listing one-line rules that PRs must satisfy. The compounding loop — `/ship_issue`'s `ship-learn` phase — grows this section over time: when the auto-reviewer flags a violation of a rule that isn't yet written down, the rule is appended automatically.

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

`/ship_issue`'s open-PR plumbing applies the default scope label based on the repo (or a `.agentic-sdlc/config.json` override) and notes a possible upgrade to `scope:shared` when the diff touches paths that are likely identical across both repos (`.github/workflows/`, `prompts/`, `CLAUDE.md`, `Makefile`, etc.).

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

A future enhancement will auto-dispatch `/port-pr` from a GitHub Action on `scope:shared` merge — see the bottom of `skills/port-pr/SKILL.md` for the sketch.

## Status

- v0.6.2 — fix: `scripts/prune-merged-worktrees.sh` now reliably cleans up stale worktrees — matches the harness's `.claude/worktrees/*` too (not just `ship_issue`'s own `*-wt-*` naming), and asks GitHub directly whether a merged PR exists for a branch instead of inferring from branch-gone-from-origin (which can't tell "merged" from "never pushed"), force-deleting a branch only when its tip exactly matches what was merged; now runs as routine hygiene at the start of every `/ship_issue` run, since the old "after auto-merge" trigger had never once fired in this repo's real history
- v0.6.1 — fix: `type:spike` commit-type mapping (was an invalid Conventional Commits type, now maps to `chore`); `code-simplifier` now diffs against the resolved base branch instead of hardcoding `main` (was silently reviewing the wrong diff on stacked PRs); `gh pr create`/`gh issue create` no longer abort entirely on a single missing label across `create_pr`/`port-pr`/`create_issue` — labels are applied after creation and checked against what the target repo actually has; dropped the `ai-tool: claude-code`/`ai-workflow: ai-authored` label convention entirely (most repos this plugin runs against don't have it)
- v0.6.0 — Phase 4: vendored a pinned `ce-debug` diagnosis skill (MIT, EveryInc/compound-engineering-plugin @ `compound-engineering-v3.16.0`) — fills the root-causing gap; adapted to our conventions (dual interactive/non-interactive modes, no branch creation, hands off to `create_pr`/`ship_issue`); wired into `work`/`verify` so an unexplained failure escalates to structured diagnosis before parking
- v0.5.0 — Phase 3: decomposed `/ship_issue` into six isolated `SKILL.md` phase-skills (`ship-plan/work/simplify/verify/review/learn`) behind a **state-envelope contract** (`skills/ship_issue/CONTRACT.md`); `/ship_issue` is now a thin orchestrator; migrated all `commands/` to the portable `skills/` format
- v0.4.0 — Phase 2: two-tier knowledge model (`KNOWLEDGE.md`) — invariants (enforced) + constitution (justify-or-deviate); installable `templates/constitution.md`; compounding loop central-judges findings + admission bar + tier routing; `code-simplifier` reads the constitution
- v0.3.0 — Phase 1: `ship_issue` stops owning isolation (detect-and-skip) + runs non-interactively; load-bearing bash extracted to tested `scripts/`; model roles in `MODELS.md`
- v0.2.0 — `/port-pr` slash command + `scope:*` label set
- v0.1.1 — fix: poll PR reviews directly in `ship_issue` step 12 (workflow_run head_sha gotcha)
- v0.1.0 — initial extraction from sibling `ai-servicedesk` + `hr-servicedesk` repos
- Installed via local-directory marketplace; not yet published
