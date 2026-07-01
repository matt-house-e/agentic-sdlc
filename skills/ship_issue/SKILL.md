---
name: ship_issue
description: Ship a GitHub issue end-to-end in an isolated worktree — plan, implement, simplify, verify, PR, self-review, compounding loop, auto-merge. Thin orchestrator over six isolated phase-skills behind a state-envelope contract.
argument-hint: <issue-number> [base-branch]
---

Ship issue #$ARGUMENTS from first read to merged PR.

`$ARGUMENTS` is `<issue-number>` or `<issue-number> <base-branch>`. Parse now: first token
is the issue number, second (optional) token is the explicit base branch.

You are the **orchestrator**. You own plumbing and sequencing; you own **no reasoning** —
that lives in six isolated phase-skills you invoke in order. Read
`${CLAUDE_SKILL_DIR}/CONTRACT.md` now — it is the authoritative state-envelope contract and
this skill assumes it.

The pipeline:

```
plan → work → simplify → verify → [open PR] → review → learn → [auto-merge]
```

Each phase runs in a fresh isolated context (`context: fork`) and returns a small JSON
**envelope**. You thread accumulated **state** forward and branch only on `status`.

---

## How you run a phase

For each phase below, invoke the phase-skill via the **Skill tool**, passing the current
running state as a JSON object string in the arguments:

```
Skill(ship-plan, "<running-state-json>")
```

The phase forks, does its work in isolation, and returns its envelope as its final message.
Then:

1. **Validate** the envelope: valid JSON, known `status`, `state` present. If malformed,
   re-invoke once asking for the envelope only; if it fails again, treat as `failed`.
2. Branch on `status`:
   - **`ok`** → merge `state` into the running state (overwrite keys), append `decisions`
     to the run's decision log, proceed to the next phase.
   - **`parked`** → **stop.** Record `parked.question` for the digest. Leave branch/PR in place.
   - **`failed`** → **stop.** Record `notes`. Leave any branch/PR as a draft with findings.

Never force past a `parked` or `failed`. The phases re-ground on the durable substrate, so a
small envelope is safe — do not try to forward transcripts.

---

## 0. Initialize the running state

```bash
gh issue view <issue-number> --comments     # confirm the issue exists and read it once
git fetch origin main
git worktree list
```

**Resolve the base branch non-interactively** (this runs fire-and-forget — never block on a
prompt):

1. **Explicit base** (second arg): use it. Check it's on origin (`git ls-remote origin <base>`);
   if missing, log a one-line warning and proceed (the PR diff includes its commits until it merges).
2. **No explicit base**: use `origin/main`.

If a genuine base ambiguity exists that you couldn't resolve upfront (e.g. this issue clearly
stacks on an in-flight branch you can't identify), treat it as a scoping miss and **stop with a
`parked` digest line** — don't guess silently. Pass the base as the second arg to avoid this.

**Workspace setup — isolation is the harness's job. Detect first, create only if needed:**

```bash
# A linked worktree has a separate git dir from the main checkout.
if [ "$(git rev-parse --git-common-dir)" != "$(git rev-parse --git-dir)" ]; then
  ISOLATED=1   # Agent View / --bg --worktree already isolated us — use it as-is
else
  ISOLATED=0   # main checkout (interactive / CI fallback)
fi
```

- **`ISOLATED=1`**: do **not** create a worktree. Ensure a dedicated branch — if still on the
  default branch, `git switch -c <type>/<issue-number>-<slug> <resolved-base>`; else use the
  current branch. Stay put.
- **`ISOLATED=0`**: create the fallback worktree and switch into it:
  ```bash
  REPO_SHORT=$(basename "$(git rev-parse --show-toplevel)")
  git worktree add ../${REPO_SHORT}-wt-<issue-number> -b <type>/<issue-number>-<slug> <resolved-base>
  ```

Derive `<type>` from issue labels (type:story→feat, type:task→task, type:bug→fix,
type:spike→spike, type:epic→epic) and `<slug>` from the title (lowercase, hyphens, ~40 chars).

Seed the running state:

```json
{ "issue": <n>, "base": "<resolved-base>", "branch": "<branch>", "worktree": "<abs-path>",
  "scope_label": null, "pr": null }
```

**Docker conflict risk**: if the repo's tests use shared ports and multiple worktrees are
active, stagger test runs.

---

## 1. plan  →  `Skill(ship-plan, <state>)`

Understands the issue, sketches + self-grills the approach, breaks it into atomic tasks, runs
a fresh-Claude plan stress-test, and **writes the approach + decisions as a comment on the
issue**. Returns the task plan's existence (in the issue) via `notes`; `decisions` carries the
key calls. Parks if the issue is genuinely ambiguous (vague AC, unresolved design fork).

Skip nothing here for non-trivial issues. For a trivial `type:task`/`type:bug` touching ≤3
files, `ship-plan` self-determines there is nothing to grill and returns a minimal plan fast.

## 2. work  →  `Skill(ship-work, <state>)`

Implements the task plan one task at a time — single-threaded, full context, delegating the
token-heavy loop to an implementer-tier subagent. Lints + tests each task, commits one logical
commit per task with the **why** in the body. If the plan proves wrong mid-flight, it corrects
the plan rather than patching over it. Returns the commit SHAs in `decisions`/`state`.

## 3. simplify  →  `Skill(ship-simplify, <state>)`

Dispatches the `code-simplifier` agent (clean session, three lenses), applies its changes,
re-runs lint + tests, commits the cleanup separately. Skips cleanly if the diff is trivial
(≤20 lines). Read-only-ish: it must honor the **drift tripwire** — never undo a guard a
recorded decision added without a reconciliation note.

## 4. verify  →  `Skill(ship-verify, <state>)`

Runs the deterministic gates: lint **and** format-check (both — green lint ≠ green format),
tests, and filtered evals for behavior changes. **The eval is the spec.** Returns `failed` on
any red gate — do not open a PR on red.

## 5. Open the PR (orchestrator plumbing — no phase)

Only after `verify` returns `ok`. If `<base>` ≠ `origin/main`, pass `--base <base>`.

**Idempotency first — never double-open.** A fire-and-forget run can crash and resume; check for
an existing PR on the branch before creating one:

```bash
EXISTING=$(gh pr list --head <branch> --state open --json number --jq '.[0].number')
# if EXISTING is set, reuse it (set state.pr = $EXISTING) and skip creation; else create below.
```

Resolve the `scope:*` label (config `.agentic-sdlc/config.json` → built-in fallback → never
prompt to upgrade), create the PR **without** `--label` (a missing label aborts creation
entirely), then **hard-gate** on label reconciliation:

```bash
PR_NUMBER=<pr-number>; ISSUE_NUMBER=<source-issue-number>
"$CLAUDE_PLUGIN_ROOT/scripts/verify-pr-labels.sh" "$PR_NUMBER" "$ISSUE_NUMBER"   # exits non-zero if any required label is missing
```

Do not proceed on a non-zero exit. Add `pr` and `scope_label` to the running state.

**Scope upgrade note (non-interactive).** Keep the repo-default scope; never prompt to upgrade
mid-run. But if the diff touches paths likely identical across sibling repos
(`.github/workflows/`, top-level `prompts/`, `docs/development/`, `docs/decisions/`, `CLAUDE.md`,
`Makefile`/`pyproject.toml`, `.pre-commit-config.yaml`), add a one-line note to **both the PR body
and the digest**: *"touches generic paths — consider `scope:shared` + `/port-pr` after merge."*
The human decides on review; promoting to `scope:shared` is a reversible label edit — defer, don't park.

**PR body** = `create_pr`'s template (see that skill for the full label/scope detail) **plus** two
ship_issue additions: a short **`## Decisions`** section summarizing the run's decision log, and a
**`- [ ] Compounding loop run — invariants harvested or skip-rationale recorded`** checklist box
(the `learn` phase ticks it).

## 6. review  →  `Skill(ship-review, <state>)`

Reads `gh pr diff` in a fresh context (unbiased by authorship), checks it against the
conventions / constitution / quality / completeness checklists, fixes findings (commit + push
each), and checks the PR-body boxes. Returns once clean.

## 7. learn  →  `Skill(ship-learn, <state>)`

Waits for a reviewer verdict newer than the latest commit, central-judges each finding's
legitimacy, and harvests genuinely-novel legitimate findings into the host repo's knowledge
home — routed by tier (invariant / constitution / ADR) and only if it clears the admission bar.
Idempotent via `docs(invariants|constitution|adr):` commit prefixes. Iterates to `APPROVED`
(bounded); surfaces a yellow note on reviewer timeout / Lint failure rather than blocking.

## 8. Enable auto-merge (orchestrator plumbing — no phase)

```bash
gh pr merge $PR_NUMBER --auto --squash --delete-branch
```

Works with `REVIEW_REQUIRED` branch protection. Do **not** use `--admin`. Skip and stop if the
PR is still a draft, a required check is red, or the diff is large enough to want a human eye
first (leave a review-request comment + note it).

---

## 9. Done — the wake-up digest

Report:
- PR URL
- Auto-merge state — enabled / blocked (reason) / skipped (reason)
- Worktree path (stays until the PR merges)
- Compounding-loop result — invariants added / skip-rationale / yellow note
- Any `parked` question (the `⚠ needs your call` line) or `failed` reason, if the run stopped early
- Any follow-on issues to create (if scope narrowed during implementation)

After auto-merge lands the PR (interactive/CI fallback path only — under Agent View the harness
owns the worktree lifecycle):

```bash
"$CLAUDE_PLUGIN_ROOT/scripts/prune-merged-worktrees.sh"     # add --dry-run to preview
```

---

## When to bail (park, don't guess)

- **Issue is actually two issues** → `ship-plan` parks asking to split it.
- **Unresolved design decision** → park with options, don't pick arbitrarily.
- **Tests fail in a way the phase doesn't understand** → `work`/`verify` first escalate to the `ce-debug` diagnosis skill (non-interactive); only if that can't root-cause-and-fix it does the phase return `failed` (push the branch, draft PR with the Debug Summary).
- **Implementation would touch >8 files** → a sign the issue needs splitting; park.

A `parked` or `failed` envelope from any phase stops the pipeline cleanly and hands back to the
human via the digest — that is the design working, not a fault.
