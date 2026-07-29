---
name: ship_issue
description: Ship a GitHub issue end-to-end in one coherent context — pre-flight risk read, implement with focused tests, one authoritative gate, risk-gated independent review, PR, auto-merge, run record. A harness of hard gates around a free agent.
argument-hint: <issue-number> [base-branch] [full]
---

Ship issue #$ARGUMENTS from first read to merged PR.

`$ARGUMENTS` is `<issue-number>`, optionally followed by `<base-branch>`, optionally followed
by the literal word `full`. Parse now: first token = issue number; a token matching an existing
branch name = explicit base; the token `full` = force maximum rigor (posted plan + independent
review) regardless of signals.

You run the **whole issue in one coherent context**. There is no phase pipeline: you read the
issue, assess risk, plan at the depth the risk demands, implement, gate, ship. What replaces
the pipeline is a set of **hard rules and gates you cannot skip or reorder** — everything else
(how you plan, when you delegate, what you read) is your judgment. See
`design/10-harness.md` for why.

---

## Hard rules (authority boundaries — no judgment, no exceptions)

1. **Shipping is not deploying.** Merging a PR never authorizes a production deployment.
   Never trigger a production deploy, release tag, or deploy workflow unless the user has
   explicitly granted it *for this run* — quote the grant verbatim in the run record. The
   repo's standard tagged-release process is never bypassed, even with a grant.
2. **No backfills or bulk mutations of production data.** Historical/bulk processing is
   always a separate, explicitly-approved issue — never coupled to a feature's first rollout.
   If this issue's spec includes one, split it out (park if the issue insists they ship
   together).
3. **No at-scale writes to external systems** (ticket systems, email, third-party APIs)
   beyond what the acceptance criteria explicitly require and tests cover.
4. **Never open a PR on a red gate. Never merge past a red check.** No `--admin`, no
   force-push to shared branches, no editing CI config to make a failure pass.
5. **Closure integrity.** `Closes #n` requires the issue's acceptance criteria to be met. If
   implementation legitimately diverged, record a scope-change comment on the issue *before*
   the PR merges — or open a replacement issue and reference it instead.
6. **Selected checks stay selected.** If the user asked for specific checks, state the set
   and reason before running, and do not expand it unasked.

---

## 0. Hygiene and workspace (plumbing)

```bash
gh issue view <issue-number> --comments     # read the issue ONCE, fully — spec + prior decisions
git fetch origin main
git worktree list
"$CLAUDE_PLUGIN_ROOT/scripts/prune-merged-worktrees.sh"     # routine sweep; --dry-run to preview
```

**Resolve the base non-interactively:** explicit base arg → use it (check `git ls-remote
origin <base>`; if missing, log a one-line warning and proceed — the PR diff includes its
commits until it merges). Otherwise `origin/main`. If the issue clearly stacks on an in-flight
branch you can't identify, **park** — don't guess.

**Isolation — detect first, create only if needed:**

```bash
if [ "$(git rev-parse --git-common-dir)" != "$(git rev-parse --git-dir)" ]; then ISOLATED=1; else ISOLATED=0; fi
```

- `ISOLATED=1` (Agent View / `--bg --worktree`): do **not** create a worktree. If still on the
  default branch, `git switch -c <type>/<issue-number>-<slug> <resolved-base>`; else use the
  current branch.
- `ISOLATED=0`: create the fallback worktree and work there:
  ```bash
  REPO_SHORT=$(basename "$(git rev-parse --show-toplevel)")
  git worktree add ../${REPO_SHORT}-wt-<issue-number> -b <type>/<issue-number>-<slug> <resolved-base>
  ```

`<type>` from labels (type:story→feat, type:task→task, type:bug→fix, type:spike→spike,
type:epic→epic); `<slug>` from the title (lowercase, hyphens, ~40 chars).

---

## 1. Pre-flight — the risk read (before any code)

Walk this signal list against the issue and the code it will touch. Deterministic: a signal
either fires or it doesn't, and you record which. Signals **arm safeguards**; nothing can
disarm a triggered safeguard mid-run (judgment escalates, never de-escalates).

| # | Signal |
|---|---|
| S1 | DB schema change or migration |
| S2 | Auth, permissions, secrets, or security-sensitive surface |
| S3 | New dependency, or a new architectural pattern |
| S4 | LLM behavior: prompts, evals, model selection, structured-output contracts |
| S5 | Queues, background workers, or scheduled/async processing |
| S6 | Bulk or historical data processing (backfills — see hard rule 2) |
| S7 | Writes to external systems (ticketing, email, third-party APIs) |
| S8 | Touches production data, or changes what production persists |
| S9 | Spans multiple components / an end-to-end user journey |
| S10 | Deployment, infra, or CI/CD config change |
| S11 | Acceptance criteria ambiguous, or an unresolved design fork → **park now** |

**What arms what:**

- **Any signal fired (or `full` requested)** → the plan is **posted as an issue comment**
  (approach, task list, key decisions *with rejected alternatives*) before implementation, and
  the **independent review** (step 5) is armed. For genuinely hard designs, also stress-test
  the plan with one fresh subagent (`Agent`, `general-purpose`, self-contained prompt,
  foreground) asking *"would you ship this plan — what's wrong or missing?"*.
- **S5–S8** → the posted plan must additionally answer the **operational questions**: expected
  volume (how many records/requests, measured not guessed), cost (which model/API, worst
  case), failure behavior (timeout, permanent failure, is the primary user path fail-open?),
  starvation (can bulk work delay live work?), kill switch, rollback. If you cannot answer one
  from the repo or the issue, **park with the question** — these are exactly the questions
  that caused a real production incident when skipped.
- **S9** → **tracer bullet first**: the first slice implements the thinnest complete user
  journey end-to-end; horizontal breadth (storage layers, worker fleets, delivery machinery)
  comes only after the journey is proven. If the issue is structured as horizontal component
  slices, park and propose re-slicing.
- **No signal fired** → a concise inline plan (your task list; the *why* goes in commit
  bodies) is sufficient, and review is skipped **with the reason recorded in the run record**.

**Park (stop, ask, leave the branch in place) when:** S11 fires; the issue is really two
issues; implementation would touch >8 files (split signal); or a hard rule conflicts with the
spec. Parking is the design working, not a failure.

---

## 2. Implement — one coherent context

Read the host repo's `AGENTS.md`/`CLAUDE.md` (invariants are **binding**; constitution is
justify-or-deviate) and the files the change touches. **Lift and adapt existing patterns —
don't invent new ones when one fits.**

Work your task list in order. Per task:

1. Implement it.
2. **Focused feedback only** — run the tests covering what you changed (not the full suite;
   the gate owns that). Lint if quick. New behavior gets a paired test in the same commit;
   behavior visible to evals (`test -d evals/`) gets the eval written **first**, failing, then
   made green.
3. **One logical commit per task**, conventional format, the **WHY in the body** — the commit
   history is the durable design log, and a diff never records *why this and not the obvious
   alternative*. `Closes #<issue>` on the final commit only. Never squash.

If implementation proves the plan wrong — **stop, correct the plan** (update the posted plan
comment if one exists), then re-implement cleanly. The plan is malleable; the spec (acceptance
criteria) is immutable — never silently widen or narrow scope (hard rule 5).

**Delegation is a tool, not a stage.** For a token-heavy loop, dispatch **one**
implementer-tier subagent (`Agent`, `general-purpose`, `model: sonnet` per `MODELS.md`) with a
self-contained prompt (task list, binding invariants, worktree path, the per-task protocol
above). Single-threaded always — never parallel writers. For a large diff that smells
over-built, dispatch `code-simplifier` and vet its edits against your recorded decisions
before committing. **Every nested `Agent` dispatch runs in the foreground**
(`run_in_background: false`) — you are the caller waiting on the result; a backgrounded
dispatch ends your turn on an interim status line.

**A failure you can't explain → `ce-debug` before giving up:**
`Skill(ce-debug, "<failing test/gate + output + context>  mode: pipeline")`. If it
root-causes and safely fixes, re-run and continue; a design-problem finding → park with the
question; an unresolved red → stop, push the branch, record the Debug Summary in the draft PR.

**PYTHONPATH gotcha (worktree):** with a parent-shell `PYTHONPATH` set, prefix Python test
runs with `PYTHONPATH=<worktree-abs-path>` (or `export PYTHONPATH=$PWD` once) — otherwise
`app.*` imports silently resolve to stale parent-checkout code and produce bogus failures.

---

## 3. THE GATE — one authoritative verification

Run **once, after the final code change**. Any commit made after a green gate — review fixes,
harvested knowledge, anything — **re-arms it** (for a provably docs-only diff, lint + format
alone may satisfy the re-run; record that call in the run record).

1. **Lint AND format** — both, always; green lint does not imply green format. `make check`,
   or explicitly: `uv run ruff check . && uv run ruff format --check .` (Python) /
   `npm run lint && npm run format:check` (JS/TS) / the repo's documented pair.
2. **Tests** — the full documented suite: `make test` / `uv run pytest tests/` / `npm test`.
3. **Evals, filtered** — only if `evals/` exists and behavior changed: `make eval
   RUN=<prefix>` scoped to the changed behavior — never the full suite. **The eval is the
   spec**: a failing scenario means fix the implementation; changing an eval is a deliberate,
   recorded decision, never a silent edit.

**Fail closed.** A red you can't fix (after `ce-debug`) stops the run: push the branch, open a
**draft** PR with the findings, report. No PR opens on red (hard rule 4).

---

## 4. Open the PR (plumbing)

**Idempotent — never double-open:**

```bash
EXISTING=$(gh pr list --head <branch> --state open --json number --jq '.[0].number')
```

Reuse `EXISTING` if set. Else create — base `<resolved-base>` if ≠ `origin/main`; body from
the `create_pr` skill's template **plus a `## Decisions` section** (the run's key calls with
rejected alternatives). Resolve the `scope:*` label (`.agentic-sdlc/config.json` → built-in
fallback → never prompt), create **without** `--label`, then hard-gate:

```bash
"$CLAUDE_PLUGIN_ROOT/scripts/verify-pr-labels.sh" "$PR_NUMBER" "$ISSUE_NUMBER"   # non-zero exit = stop
```

If the diff touches likely-shared paths (`.github/workflows/`, `prompts/`, `CLAUDE.md`,
`Makefile`, `docs/decisions/`, …), add the one-line *"consider `scope:shared` + `/port-pr`
after merge"* note to the PR body — the human decides on review; don't park.

---

## 5. Independent review — only if armed

**If no signal armed it and `full` wasn't requested: skip, and record the reason** (e.g. "no
review: no signals; 40-line localized diff, gate green"). Do not run review as ritual — a
skipped-with-reason review is a feature, not a gap.

**If armed:** dispatch the fresh-context fork — authorship blindness is the one thing you
cannot self-supply:

```
Skill(ship-review, "{\"issue\": <n>, \"pr\": <n>, \"base\": \"<base>\", \"worktree\": \"<abs-path>\", \"signals\": [\"S2\", ...]}")
```

It reviews the diff cold against conventions / constitution / quality / completeness, fixes
findings (commit + push), respects recorded decisions (drift tripwire), and returns a terse
findings report. Then: findings fixed → **the gate re-arms — re-run step 3**; a needs-human
question → park with it.

---

## 6. Harvest — only if there is something to harvest

If the repo has a PR-review workflow (`.github/workflows/*review*`), wait bounded for its
verdict — `gh pr checks --watch`, then
`VERDICT=$("$CLAUDE_PLUGIN_ROOT/scripts/wait-for-review.sh" "<pr>" 600) || true` (polls
reviews directly; never match workflow runs by SHA — `workflow_run` head SHAs are merge
commits and never match). Timeout / no workflow → yellow note in the run record, move on;
never block the ship.

- `CHANGES_REQUESTED` → address findings (≤3 iterations), commit + push, gate re-arms, wait
  for a fresh verdict. Past 3 → stop and hand to the human.
- Any **legitimate finding citing a rule not yet written down** (judge legitimacy first —
  reviewers are sometimes confidently wrong; dismiss what's wrong) → harvest it into the host
  repo's knowledge home per `KNOWLEDGE.md`: admission bar (*"would removing this rule let a
  real mistake through?"*), tier routing (invariant / constitution / ADR), one-line
  imperative, `docs(invariants|constitution|adr):` commit prefix for idempotency.
- Clean review, nothing novel (the common case) → one line in the run record. **No finding,
  no harvest work.**

---

## 7. Auto-merge, run record, digest

**Closure-integrity check first (hard rule 5):** re-read the acceptance criteria against the
final diff. Met → proceed. Diverged → post the scope-change comment on the issue now, or
retarget `Closes` to a replacement issue.

```bash
gh pr merge $PR_NUMBER --auto --squash --delete-branch    # never --admin
```

Skip auto-merge (and say so) if the PR is a draft, a required check is red, or the diff is
large enough to want a human eye first.

**Post the run record** — a PR comment with a fenced JSON block (this is the plugin's
self-pruning evidence; issue #15 aggregates these):

```json
{
  "issue": 0, "pr": 0, "rigor": "signals|full-override|none",
  "signals": ["S5", "S9"],
  "plan": "posted|inline", "tracer_bullet": true,
  "operational_questions": "answered-in-plan|n/a",
  "review": { "ran": true, "reason": "S2 auth surface", "findings": 1, "contributed": true },
  "gate": { "lint": "green", "tests": "38 passed", "evals": "routing.* 4/4", "reruns": 1 },
  "harvest": { "ran": false, "reason": "clean review" },
  "authority_grants": [], "escalations": [], "parked": null
}
```

`contributed` is the load-bearing field: it is how ritual gets identified and deleted on
evidence rather than argument.

**Then the digest to the user:** PR URL · auto-merge state (enabled / blocked-why /
skipped-why) · worktree path · signals fired and what each armed · what review/harvest
actually contributed · any park question (`⚠ needs your call`) · follow-on issues to create
(a split-out backfill issue goes here). If auto-merge landed the PR in-run (interactive/CI
fallback path only), sweep worktrees immediately:
`"$CLAUDE_PLUGIN_ROOT/scripts/prune-merged-worktrees.sh"`.
