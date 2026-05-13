---
description: Ship a GitHub issue end-to-end in an isolated worktree — plan, implement, test, PR, self-review, compounding loop, auto-merge
accepts_args: true
argument-hint: <issue-number> [base-branch]
---

Ship issue #$ARGUMENTS from first read to merged PR, entirely self-contained.

`$ARGUMENTS` is either `<issue-number>` or `<issue-number> <base-branch>`.
Parse them now: first token is the issue number, second (optional) token is the explicit base branch.

This command is repo-agnostic — it detects the project at runtime. Each repo's
specific invariants live in that repo's `CLAUDE.md` (`## Repo invariants`
section). Read that file early in step 6 and treat it as authoritative.

---

## 0. Overview first

Before any planning or code, post a brief block so the change is graspable in 8 lines:

```
**What it does:** <one sentence>
**Value:** <who benefits, what gets simpler or possible>
**Key files:** <2-4 files that matter most>
**Approach:** <one sentence on the technical strategy>
```

Then continue.

---

## 1. Understand the issue

```bash
gh issue view $ARGUMENTS --comments
```

Check:
- **Labels**: `type:*` sets commit type and scope; `component:*` narrows where to look
- **Acceptance criteria**: these become the definition of done
- **Dependencies**: is anything blocking this issue? Are there linked issues to read?

**Stop and comment on the issue if**: the issue is vague, acceptance criteria are missing, or a design decision is unresolved. Don't guess. Ask on the issue, then wait.

---

## 2. Orchestration check + base resolution

```bash
git fetch origin main
git worktree list
```

**Resolve the base branch** using this decision tree:

1. **Explicit base provided** (second argument, e.g. `/ship_issue 446 feat/13-some-base`):
   - Use it directly. Then run:
     ```bash
     git ls-remote origin <base-branch>
     ```
   - If the branch is not on origin, warn: *"This base branch isn't pushed yet — the PR diff will include its commits until it merges. Push it first, or continue knowing the PR base will be noisy."* Don't block, but require acknowledgement.

2. **No explicit base + active worktrees exist**:
   - List the active branches (from `git worktree list`, excluding main/HEAD entries).
   - Ask: *"Active in-flight branches: [list]. Does this issue depend on any of these? Enter a branch name to use as base, or press enter to use `origin/main`."*
   - If the user names a branch, apply the `git ls-remote` check above.
   - If the user presses enter (or says no), use `origin/main`.

3. **No explicit base + no active worktrees**:
   - Use `origin/main` silently. No prompt needed.

Store the resolved base as `<resolved-base>` — used in step 5.

**Docker conflict risk**: if the repo's test suite runs against shared ports (Postgres, etc.) and multiple worktrees are active, stagger test runs manually.

---

## 3. Design sketch + self-grill (skip for trivial issues)

Skip this step for `type:task` or `type:bug` issues that touch ≤ 3 files with no architectural decisions. There's nothing to design, so there's nothing to grill.

### 3a. Sketch

For all other issues, sketch the technical approach **before touching any file**:

- Which existing patterns does this follow? (Check this repo's `CLAUDE.md` for documented patterns.)
- Which files will be created vs modified?
- Does this require an ADR? (architectural decision — new dependency, pattern change, significant design choice — destination conventionally `docs/decisions/` or whatever the repo uses)
- Does the change touch any cross-cutting concern listed in the repo's invariants (caching, structured output, prompt construction, state shape)? Note those invariants explicitly so they don't get violated mid-implementation.

### 3b. Self-grill the sketch

The sketch above is a first draft. Now interrogate it the way `/grill-me` would interrogate a human — but answer your own questions. The point isn't to pester yourself with a checklist; it's to walk the decision tree of *this specific design* and resolve each branch before it ossifies into code.

**Generate the questions from the sketch, not from a list.** Look for places you were guessing, assumptions you'd struggle to defend, edge cases in the acceptance criteria you glossed over, dependencies on parts of the system you didn't actually read. Each answered question usually surfaces the next. Stop when you're inventing problems rather than discovering them.

**Resolve each question the cheapest way that gives a confident answer:**

- **Read the code.** Most "how does this work" / "what does X return" / "is there already a field for this" questions are dispatchable in a single Read or grep. Do that instead of asking.
- **Apply best practice.** For "should I do X or Y" questions, the codebase usually shows the preferred pattern somewhere — find it. If not, fall back to the invariants in this repo's `CLAUDE.md`. You almost always have enough context to make the call.
- **Ask the user — but only when you genuinely need to.** Reserve this for: (a) product or UX decisions that aren't yours to make, (b) decisions that depend on organizational context not in the codebase (team preference, roadmap, deadlines), or (c) genuine forks where the codebase shows both patterns and neither is canonical here. When you do ask, lead with your recommended answer and the reason — don't dump open questions on the user. One question at a time.

### 3c. Update the sketch

Fold what you learned back in: revised file list, called-out assumptions, edge cases now covered, dependencies clarified. The post-grill sketch is what step 4 breaks into tasks. If the grill revealed that the original approach doesn't fit, change the approach — don't paper over it.

---

## 4. Atomic task breakdown + plan review

### 4a. Break the work into atomic tasks

Break the work into a numbered task list **before creating the worktree or writing any code**.

Each task must:
- Touch **1–3 files** maximum
- Have a **single testable outcome** ("add X to Y so that Z works")
- Map to **one logical commit**

Example quality bar:
- BAD: "Implement the new service"
- GOOD: "Add `create_ticket()` to `app/services/jira.py` using the project key from settings"

Write the task list out explicitly. This is the plan you implement against — if something goes wrong during implementation, fix the plan and re-implement that task. Do not patch code and move on; errors compound.

**Include test + eval coverage as explicit tasks**, not as an afterthought:

- **Unit tests** — every task that adds or changes behavior gets a paired test task. The test task lands in the same commit as the code (or immediately after). No "we'll write tests later."
- **Evals** — if the change alters *observable agent behavior* (classification, routing, tool selection, conversation tone, output shape), add an eval task. Run `test -d evals/` to check if this repo has an eval framework; skip the eval step cleanly if not. When evals are available:
  - **Extend an existing dataset** when a relevant `evals/datasets/*.json` already covers the area — add scenarios for the new edge cases
  - **Create a new dataset** when nothing covers it — 3-6 scenarios: happy path, key edge cases, and at least one regression scenario that pins behavior that *must not* change
  - **Skip with a one-line rationale in the PR description** if the change is internal-only (refactor, typing, config, infra) with no behavioral effect

When evals exist, the eval task runs *before* the implementation task that changes the behavior — write the failing eval first, then make it pass. The eval is the spec.

### 4b. Fresh-Claude plan review (skip when step 3 was skipped)

You wrote this plan. You are biased toward it. Dispatch a **fresh subagent with no prior context** to stress-test it before any code is written — Anthropic's published guidance calls this the highest-ROI multi-Claude pattern.

Use the `Agent` tool with `subagent_type: general-purpose`. The prompt should be self-contained — the subagent has no memory of this session — and include:

- The issue body and acceptance criteria (verbatim)
- The post-grill sketch from step 3
- The full task list from 4a
- A pointer to this repo's `CLAUDE.md` and the relevant directories (derived from the `component:*` label)
- An explicit ask: *"Would you ship this plan? What's wrong with it? What's missing? Where am I likely to discover the approach is incorrect mid-implementation?"*

Tell the reviewer to be terse and concrete — file paths, line references, specific failure modes — not abstract advice. Cap the response at ~400 words.

**Act on the findings before proceeding:**
- **Material gap** (missing task, wrong file, wrong pattern) — update the task list, re-run the review if the change is large
- **Cosmetic suggestion** — note it but don't churn the plan
- **Reviewer is wrong** — explain why in one line and move on; don't argue with a subagent

If you skipped step 3 (trivial issue, no architectural decisions), skip this too. There's nothing to review.

---

## 5. Worktree setup

```bash
# Derive branch type from issue labels (type:story→feat, type:task→task, type:bug→fix, type:spike→spike, type:epic→epic)
# Derive slug from issue title (lowercase, hyphens, ~40 chars)
# <resolved-base> comes from step 2

REPO_SHORT=$(basename "$(git rev-parse --show-toplevel)")
git worktree add ../${REPO_SHORT}-wt-<issue-number> -b <type>/<issue-number>-<slug> <resolved-base>
```

All remaining work happens inside `../${REPO_SHORT}-wt-<issue-number>`. Switch to that directory now and stay there.

---

## 6. Read context

Read this repo's `CLAUDE.md` if you haven't this session — that's where the project's invariants, conventions, and `component:*` → directory mapping live. Then read the files most relevant to the issue's `component:*` label.

If `CLAUDE.md` doesn't document a `component:*` → directory mapping, infer it from the top-level directory structure (`app/`, `services/`, `src/`, etc.) and read the most relevant 3–5 files before touching anything.

Understand the existing pattern before writing any code. Lift and adapt — don't invent new patterns when the codebase already has one.

---

## 7. Implement — one task at a time

Work through the task list from step 4. For each task:

1. Implement it
2. Verify it works:
   - **Lint + format** — `make check` if the repo has a Makefile with that target, otherwise the repo's documented equivalent (e.g. `uv run ruff check . && uv run ruff format --check .`, `npm run lint`, `pre-commit run --files <changed>`). Check `CLAUDE.md` for the canonical command.
   - **Tests** — `make test` or the documented equivalent (`uv run pytest tests/`, `npm test`, etc.) — only after tasks that touch source under the runtime path.
   - **In a worktree, prefix Python tests with `PYTHONPATH=<worktree-abs-path>`** when the shell has a pre-set `PYTHONPATH` from the parent repo. Without this, `app.*` imports silently resolve to stale code in the parent checkout instead of your worktree edits — producing bogus `TypeError: got an unexpected keyword argument` failures despite a correct edit. Same applies to `make test` / `make eval`. Either prefix the command or `export PYTHONPATH=$PWD` in the worktree shell once.
3. Commit it (see step 8)
4. Only then move to the next task

**If implementation reveals the task plan was wrong** — stop, update the task plan, then re-implement the affected task cleanly. Do not accumulate patches on top of a wrong approach.

**Enforce this repo's invariants throughout.** They are documented in `CLAUDE.md` under `## Repo invariants` (or the repo's equivalent section). Treat them as binding: a passing PR must not violate any of them. Common categories that often surface here:

- **Data model** — Pydantic / dataclass / TypedDict choice; structured-output mechanism
- **State management** — fat state / context object pattern; how new fields land
- **Layer rules** — business logic in services vs handlers vs agents
- **LLM / prompts** — prompt-caching boundaries, structured output, model selection
- **Naming / spelling** — brand-name spellings, case conventions
- **Architectural changes** — when an ADR is required, where it lives

---

## 8. Logical commits

One commit per task. Format:

```
<type>(<scope>): <description>

- detail of what changed and why (if non-obvious)

Closes #$ARGUMENTS   ← only on the final commit
```

Derive `type` and `scope` from the issue labels using the mapping in `create_pr.md`.

Do not squash everything into one commit. The commit history is the implementation log.

---

## 9. Verify

```bash
make check        # lint + format — or the repo's documented equivalent
make test         # tests — or the repo's documented equivalent
```

Fix everything that fails. Do not open a PR with a red check.

**Then run the relevant evals** — only if this repo has an eval framework (`test -d evals/`). Do **not** run the full eval suite — it's slow and expensive. Filter to scenarios that cover the behavior this PR changes:

```bash
# Filter by scenario id prefix (datasets typically share a prefix — see evals/datasets/*.json)
make eval RUN=<prefix>      # all scenarios with that prefix
make eval RUN=<single-id>   # single scenario, useful for fast debug
make eval-seq RUN=<prefix>  # sequential mode for debugging interleaved output (if the target exists)
```

Decide which to run from the task list in step 4a:

- **You added a new eval dataset** → run those scenarios (filter by the id prefix you chose)
- **You modified behavior covered by an existing dataset** → run the scenarios in that dataset
- **You skipped eval coverage (with rationale)** → skip this step too; note it in the PR description

**The eval is the source of truth.** If a relevant scenario fails, fix the implementation, not the eval. If the eval itself is wrong, fix the eval as a deliberate, called-out change — not silently.

**Then run the code-simplifier subagent.** Dispatch the `code-simplifier` agent (provided by this plugin). It runs in a clean session, reads the diff, and removes over-engineering / dead code / missed reuse that you can't see because you wrote it. Apply its changes, re-run lint + tests, and commit the cleanup separately (`refactor: post-implementation simplification`). Skip only if the diff is trivial (≤ 20 lines changed).

---

## 10. Open the PR

If `<resolved-base>` is not `origin/main`, pass `--base <resolved-base>` to `gh pr create` so the diff only shows this issue's commits.

**Labels must be applied at PR-creation time.** Build the label list first so it can't be forgotten:

```bash
# Pull every label from the source issue (type:*, priority:*, component:*, etc.)
ISSUE_LABELS=$(gh issue view <issue-number> --json labels --jq '[.labels[].name] | join(",")')

# Always-on AI-attribution labels for ship_issue-authored PRs
AI_LABELS="ai-tool: claude-code,ai-workflow: ai-authored"

# Combined list passed to gh pr create
PR_LABELS="${ISSUE_LABELS},${AI_LABELS}"
```

Then create the PR with labels inline so it can't ship without them:

```bash
gh pr create \
  --title "<type>(<scope>): <description> (#<issue-number>)" \
  --base <resolved-base-or-main> \
  --label "$PR_LABELS" \
  --body "$(cat <<'EOF'
## Summary
[What this PR does and why]

## Changes
- [Change 1]
- [Change 2]

## Testing
[How this was verified]

## Checklist
- [ ] Lint passes
- [ ] Tests pass
- [ ] Relevant evals pass — or skip-rationale documented above
- [ ] Labels copied from source issue + `ai-tool: claude-code` + `ai-workflow: ai-authored` applied
- [ ] Self-reviewed (see below)
- [ ] Compounding loop run — invariants harvested or skip-rationale recorded
- [ ] ADR created if architectural decision made
- [ ] CLAUDE.md updated if architecture changed

Closes #$ARGUMENTS
EOF
)"
```

**Verify labels landed.** `gh pr create --label` silently no-ops on labels the repo doesn't have. Confirm the full set is on the PR before moving on:

```bash
gh pr view <pr-number> --json labels --jq '.labels[].name'
```

The output must contain every label from `$ISSUE_LABELS` plus both AI labels. If the repo already had `ai-workflow: human-authored` auto-applied (some org-level workflows do this), remove it explicitly — these are AI-authored:

```bash
gh pr edit <pr-number> --remove-label "ai-workflow: human-authored" 2>/dev/null || true
```

If any required label is missing, add it with `gh pr edit <pr-number> --add-label "<name>"` before continuing to self-review. Do not proceed with missing labels — downstream dashboards and the auto-reviewer depend on them.

If a `component:*` label is missing because the repo uses a slightly different vocabulary (`component:ci` vs `component:ci-cd`, etc.), check `gh label list` and use whatever label exists for that area — don't invent labels.

---

## 11. Self-review loop

Read your own PR diff:

```bash
gh pr diff
```

Check against each of the following. For any finding, note it, fix it, commit the fix, and re-run lint:

**Conventions**
- [ ] Follows the repo's documented patterns (see `CLAUDE.md` invariants)
- [ ] Business logic lives in the layer the repo designates for it (services / handlers / etc.)
- [ ] Structured data uses the repo's chosen model (Pydantic / dataclass / TypedDict — per `CLAUDE.md`)
- [ ] LLM-specific conventions respected (prompt caching, structured output, model selection — if applicable)
- [ ] No new patterns introduced when an existing one fits
- [ ] Brand/spelling conventions followed (check `CLAUDE.md`)

**Quality**
- [ ] No dead code, commented-out blocks, or TODO stubs left in
- [ ] Type hints used throughout (in typed codebases)
- [ ] No comments that explain WHAT the code does — only WHY if non-obvious
- [ ] No error handling added for scenarios that can't happen

**Completeness**
- [ ] All acceptance criteria from the issue are met
- [ ] If architecture changed: `CLAUDE.md` and/or an ADR updated
- [ ] PR description accurately describes the changes
- [ ] PR labels match source issue (`type:*`, `priority:*`, `component:*`) plus `ai-tool: claude-code` and `ai-workflow: ai-authored`; no stray `ai-workflow: human-authored` left from org defaults

Once all findings are resolved, mark the checklist items as done in the PR body:

```bash
gh pr edit $PR_NUMBER --body "$(cat <<'EOF'
[updated body with checked boxes]
EOF
)"
```

---

## 12. Compounding loop — feed review findings back into the rules

After self-review, close the loop: if the auto-reviewer (or a human) flagged a violation of a convention that isn't already written down, add a one-line invariant to this repo's `CLAUDE.md` so the same mistake can't be flagged on a future PR.

### 12a. Wait for a review newer than the latest commit

If this repo has a Claude PR review workflow (`.github/workflows/claude-review.yml` or similar), it's typically gated on green CI — it fires after Lint succeeds, not at PR creation. Don't fetch comments until a fresh review has landed, or the step will routinely no-op for the wrong reason.

**Don't poll workflow runs by SHA.** The reviewer workflow uses `workflow_run` triggered by Lint, which itself runs on `pull_request`. `github.event.workflow_run.head_sha` therefore reports the **merge commit SHA**, not the PR head. Matching `gh run list --workflow="Claude PR review"` results against `pr.headRefOid` silently fails, and the loop never breaks. This is the single highest-cost gotcha in this step — don't rediscover it.

**Do this instead.** Poll the PR's reviews directly and wait for one with a `submittedAt` newer than the latest commit's `committedDate`:

```bash
gh pr checks --watch                    # first: block until Lint + other checks finish

# Then wait for a review submitted after the latest commit
until [ "$(gh pr view "$PR_NUMBER" --json reviews,commits --jq \
  '(.reviews[-1].submittedAt // "") > (.commits[-1].commit.committedDate // "")')" = "true" ]; do
  sleep 30
done

# Read the verdict
gh pr view "$PR_NUMBER" --json reviewDecision --jq .reviewDecision
# → APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED / COMMENTED / null
```

If Lint failed (so the reviewer never gated in), or 10+ minutes pass with no reviewer run, surface this as a yellow note in the Done report and skip — do not block the ship.

### 12b. Iterate until APPROVED

The reviewer's first verdict may be `CHANGES_REQUESTED`. The slash command isn't done until it's `APPROVED` (or you decide to override and merge with `--admin`). Bound the loop so it can't run forever:

```text
attempts=0
loop:
  attempts=$((attempts + 1))
  read verdict from 12a
  case verdict in
    APPROVED:
      break
    CHANGES_REQUESTED:
      if attempts > 3:
        surface in Done report, stop the slash command, hand back to user
      fetch inline + summary findings (see 12c)
      address each finding: edit, commit, push
      go back to 12a (wait for a NEW review newer than the new commit)
    COMMENTED or REVIEW_REQUIRED (no APPROVE yet):
      treat as APPROVED for the compounding-loop purpose — there's nothing
      blocking; novel findings still get harvested in 12c-e
      break
```

Each iteration's commit message should reference the finding it addresses (`fix(<scope>): address reviewer note on X`). Don't squash these into one — the per-iteration log is useful evidence of the loop closing.

If you hit the attempt cap, the reviewer disagrees with your fix, or you're confident the finding is wrong, **don't fold an incorrect rule into `CLAUDE.md`** — dismiss it inline (`gh pr review --dismiss …`) or surface to the user. Loops aren't free; if you're churning, ask for help.

### 12c. Fetch review findings

```bash
gh pr view $PR_NUMBER --json reviews,comments                # review verdicts + PR-level comments
gh api repos/<owner>/<repo>/pulls/$PR_NUMBER/comments        # line-level inline comments
gh api repos/<owner>/<repo>/issues/$PR_NUMBER/comments       # issue-style comments (verdict, summary)
```

`gh pr view --json` does not expose `reviewThreads` (that's GraphQL-only), so use the REST endpoints for inline + issue comments. The `pulls/<n>/comments` endpoint carries the line-level findings from the inline-comment MCP tool; `issues/<n>/comments` carries the verdict + summary.

### 12d. Classify each finding

Three buckets — be deterministic, don't invent rules to fill the step:

1. **APPROVE + zero inline comments, or only style nits / praise** → skip the step entirely. Note "no novel findings" in the Done report.
2. **Finding maps to an existing invariant** in `CLAUDE.md` `## Repo invariants` or an ADR → skip, but log *which* invariant caught it (useful signal that the system worked).
3. **Finding cites a rule not yet in `CLAUDE.md` or an ADR** → propose a one-line invariant. Architecturally significant changes get an ADR instead; most findings are invariant-level.

### 12e. Commit the addition

```bash
# For invariant-level findings:
# Append one bullet to "Repo invariants" in CLAUDE.md
git add CLAUDE.md
git commit -m "docs(invariants): <one-line rule> (review of #$ARGUMENTS)"

# For architectural findings:
# Create docs/decisions/NNN-<topic>.md following the ADR template (or the repo's equivalent)
git add docs/decisions/
git commit -m "docs(adr): <decision> (review of #$ARGUMENTS)"

git push
```

The `docs(invariants):` / `docs(adr):` prefix keeps re-runs idempotent — if the step is run twice (e.g. a human reviewer adds comments after the auto-reviewer), only genuinely new rules get appended.

### 12f. Rules of thumb

- **One-line invariants only** under "Repo invariants" — paragraph-level guidance goes elsewhere (ADRs, prompt docs, this slash command)
- **Imperative voice** — "Use X" / "Never Y", not "X is preferred"
- **No invariants on this very PR** — if the change *is* the workflow tweak, expect "no novel findings" and skip cleanly
- **Don't argue with the reviewer** — if a finding is wrong, dismiss it inline; don't fold incorrect rules into `CLAUDE.md`

---

## 13. Enable auto-merge

The PR is reviewed, labelled, and the compounding loop has run. Hand the rest to GitHub's auto-merge so you don't have to babysit it:

```bash
gh pr merge $PR_NUMBER --auto --squash --delete-branch
```

This works *with* `REVIEW_REQUIRED` branch protection on `main` (if configured) — the PR sits in auto-merge until both checks pass and a review approves, then it squash-merges and deletes the remote branch in one move. Do **not** use `--admin`; that bypasses required review unless the user explicitly asks for it.

**Skip auto-merge and stop if:**
- The PR is still a draft — mark it ready first, then enable
- Any required check is red — fix it, push, then enable
- The diff is large enough that you want a human eye before it auto-merges — leave a review-request comment instead and note this in the Done report

If `gh pr merge --auto` errors (e.g. auto-merge isn't enabled on the repo, or the PR isn't in a mergeable state), surface the error in the Done report and stop. Don't force-merge.

---

## 14. Done

Report:
- PR URL
- Auto-merge state — enabled / blocked (with reason) / skipped (with reason)
- Worktree path (`../<repo>-wt-$ARGUMENTS`) — stays until the PR merges
- Compounding loop result — invariants added, skip-rationale, or yellow note (reviewer timeout / Lint failed)
- Any follow-on issues to create (if scope was narrowed during implementation)

The auto-merge from step 13 will land the PR and delete the remote branch when checks + review align. After that, clean up the local worktree:

```bash
git worktree remove ../<repo>-wt-<issue-number>
git branch -d <branch-name>
```

If worktrees have piled up because their PRs merged while you were elsewhere, walk `git worktree list` and remove any whose upstream branch no longer exists on origin (`git ls-remote origin <branch>` returns empty).

---

## When to bail

- **Issue is actually two issues** — comment on the issue asking to split it, close the worktree, stop
- **Unresolved design decision** — comment with options, don't pick arbitrarily, stop
- **Tests fail in a way you don't understand** — push the branch, open a draft PR with findings, ask for input
- **Implementation would require touching >8 files** — this is a sign the issue needs splitting; comment and stop
