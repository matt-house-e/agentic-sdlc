# agentic-sdlc

A Claude Code plugin for end-to-end agentic software development: from GitHub issue to merged PR, with self-review and a compounding-engineering feedback loop.

## What it ships

**Skills** (in `skills/`) — authored in the portable [`SKILL.md`](https://agentskills.io) standard
(slash commands have merged into skills; invoke any of these as `/<name>`):

| Skill | What it does |
|---|---|
| `/ship_issue <n>` | Ships issue `#n` end-to-end in **one coherent context**: pre-flight risk read → implement → one authoritative gate → PR → risk-gated independent review → opportunistic harvest → auto-merge → run record. A **harness** of hard gates around a free agent (see below) |
| `/create_issue <text>` | Creates a GitHub issue with the right type / priority / component labels |
| `/create_branch <n>` | Creates a feature branch from an issue, with the right type prefix and a derived slug |
| `/create_pr <n>` | Opens a PR linked to issue `#n` with correct labels and a `Closes #n` link |
| `/port-pr <n>` | Ports a merged `scope:shared` PR from one repo into its sibling — applies the diff, resolves conflicts, opens a mirror PR with `Mirrors <owner>/<repo>#<n>` in the body |
| `/ce-debug <ref>` | Systematic bug diagnosis — traces the full causal chain before fixing, test-first. **Vendored** (pinned) from [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin); see `skills/ce-debug/VENDORED.md`. Also runs non-interactively inside `/ship_issue` when implementation or the gate hits a failure it can't explain |

**The harness** — `/ship_issue` is no longer a phase pipeline. One agent runs the whole issue
in one coherent context, surrounded by the things it cannot talk its way past:

- **Hard rules (authority boundaries)** — shipping ≠ deploying (production needs an explicit
  human grant), no backfills/bulk mutations coupled to first rollout, no at-scale external
  writes, never merge past a red check, closure integrity (`Closes #n` requires the AC met or
  a scope-change record on the issue).
- **A pre-flight risk read** — a deterministic signal table (migrations, auth, new deps, LLM
  behavior, queues/workers, bulk data, external writes, production data, cross-component
  scope, deploy/infra, ambiguous AC) that arms safeguards: a posted plan, operational
  questions (volume / cost / failure behavior / starvation / kill switch / rollback), a
  tracer-bullet slice for cross-component work, and independent review. Signals arm; nothing
  disarms mid-run.
- **One authoritative gate** — lint **and** format, full tests, filtered evals; fail closed;
  **re-armed by any post-gate commit** (review fixes included).
- **Risk-gated independent review** — the `ship-review` fork (`context: fork`,
  `user-invocable: false`) reads the diff cold, unbiased by authorship, fixes findings, and
  returns a terse report. It runs only when a signal armed it (or the user forces `full`);
  skipped reviews record their reason.
- **Opportunistic harvest** — a legitimate, novel review finding is folded into the host
  repo's knowledge home under `KNOWLEDGE.md`'s admission bar; a clean review dispatches
  nothing.
- **A run record** — every run posts a machine-readable PR comment recording which signals
  fired, what ran/skipped and why, and what each step actually contributed — the evidence
  base for pruning the process itself (see `design/10-harness.md`).

Subagents remain tools, not stages: an implementer-tier loop for token-heavy work and the
`code-simplifier` agent for over-built diffs, dispatched at the harness's discretion.

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

Each project's `CLAUDE.md` should include a `## Repo invariants` section listing one-line rules that PRs must satisfy. The compounding loop — `/ship_issue`'s harvest step — grows this section over time: when a review flags a violation of a rule that isn't yet written down, the rule is appended automatically (admission bar permitting).

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

- Harness rewrite (2026-07-29, closes #26) — deleted the six-phase orchestrator + state-envelope contract; `/ship_issue` is now a **single-context harness**: hard authority boundaries, a deterministic pre-flight signal table, one authoritative re-arming gate, risk-gated `ship-review` (the only surviving fork), opportunistic harvest, and a machine-readable run record per PR (feeds #15). Constitution gained an *Operational safety* section. Rationale + evidence: `design/10-harness.md`
- v0.6.0 — Phase 4: vendored a pinned `ce-debug` diagnosis skill (MIT, EveryInc/compound-engineering-plugin @ `compound-engineering-v3.16.0`) — fills the root-causing gap; adapted to our conventions (dual interactive/non-interactive modes, no branch creation, hands off to `create_pr`/`ship_issue`); wired into `work`/`verify` so an unexplained failure escalates to structured diagnosis before parking
- v0.5.0 — Phase 3: decomposed `/ship_issue` into six isolated `SKILL.md` phase-skills (`ship-plan/work/simplify/verify/review/learn`) behind a **state-envelope contract** (`skills/ship_issue/CONTRACT.md`); `/ship_issue` is now a thin orchestrator; migrated all `commands/` to the portable `skills/` format
- v0.4.0 — Phase 2: two-tier knowledge model (`KNOWLEDGE.md`) — invariants (enforced) + constitution (justify-or-deviate); installable `templates/constitution.md`; compounding loop central-judges findings + admission bar + tier routing; `code-simplifier` reads the constitution
- v0.3.0 — Phase 1: `ship_issue` stops owning isolation (detect-and-skip) + runs non-interactively; load-bearing bash extracted to tested `scripts/`; model roles in `MODELS.md`
- v0.2.0 — `/port-pr` slash command + `scope:*` label set
- v0.1.1 — fix: poll PR reviews directly in `ship_issue` step 12 (workflow_run head_sha gotcha)
- v0.1.0 — initial extraction from sibling `ai-servicedesk` + `hr-servicedesk` repos
- Installed via local-directory marketplace; not yet published
