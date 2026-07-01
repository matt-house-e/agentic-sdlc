---
name: ship-work
description: Internal phase 2 of /ship_issue (do not invoke directly). Implements the task plan one task at a time, single-threaded with full context, delegating the heavy loop to an implementer-tier subagent; lints, tests, and commits one logical commit per task. Returns a state envelope.
context: fork
user-invocable: false
argument-hint: <running-state-json>
---

You are the **work** phase of `/ship_issue`, running in an isolated context. You implement
the plan that `ship-plan` posted to the issue — one task at a time, one logical commit per
task. You author code and commit messages; the *why* lives in the commit bodies so no later
phase can silently reverse it.

`$ARGUMENTS` is the running state as JSON: `{ issue, base, branch, worktree, scope_label, pr }`.
Read it. You operate in `worktree` (the current directory) — never create your own worktree.

## Contract (authoritative copy in `ship_issue/CONTRACT.md`)

You **return exactly one JSON envelope** as your final message, nothing else:

```json
{ "phase": "work", "status": "ok|parked|failed", "state": { /* only keys you changed */ },
  "decisions": [ { "choice": "...", "why": "...", "rejected": "..." } ],
  "notes": "one or two sentences orienting the next phase",
  "parked": null }
```

- `decisions` is append-only and carries the *why* — never omit a rejected alternative.
- `notes` is a pointer + heads-up, not a transcript.

## Re-ground first (anti-drift rule 1)

The task list **lives in the issue comment that `ship-plan` posted** — not in the envelope.
Read the durable substrate before you touch a file, so you implement against ground truth:

```bash
gh issue view <issue> --comments    # spec (acceptance criteria) + ship-plan's Plan comment: the task list + decisions
git log --oneline -15               # what already exists on this branch
git diff <base>...HEAD              # the current diff, if any
```

The **task list and decisions are in that plan comment** — pull them from there, not from
`notes`. If the substrate contradicts the state you were handed (different base, missing plan
comment, commits you didn't expect), **fail closed** and report it; do not proceed on a stale
assumption.

## Read context

Read this repo's `AGENTS.md`/`CLAUDE.md` (canonical knowledge home) if you haven't this
session — that's where the project's invariants, conventions, and `component:*` → directory
mapping live. Then read the 3–5 files most relevant to the issue's `component:*` label.

If no `component:*` → directory mapping is documented, infer it from the top-level directory
structure (`app/`, `services/`, `src/`, etc.) and read the most relevant files first.

Understand the existing pattern before writing any code. **Lift and adapt — don't invent new
patterns when the codebase already has one.**

## Model routing (cost) — delegate the loop, single-threaded

This is the token-heavy phase (large, repeated context re-reads). The fork **coordinates**;
it **delegates the per-task implementation loop to a SINGLE implementer-tier subagent**
(`Agent`, `subagent_type: general-purpose`, `model: sonnet` per `MODELS.md` — reference the
**implementer** role / `sonnet` alias, never a pinned model ID).

**Keep the coding loop single-threaded — one writer with full context.** Never fan
implementation out into parallel writers; that is the documented coding anti-pattern (parallel
writers diverge and clobber each other). One subagent carries the whole loop in order.

**Skip the delegation only for trivial issues** (≤ ~20 lines, single file) — the subagent
round-trip isn't worth it; implement inline yourself, following the same per-task protocol.

The subagent has **no session memory**, so its prompt must be self-contained and include:

- **The task list** — lifted from `ship-plan`'s issue comment (the spec it implements against).
- **The binding constraints** — the repo invariants you read above, plus the per-task
  constraints list below.
- **The worktree absolute path**, and the **`PYTHONPATH` note** below.
- **The per-task verify + commit protocol** (the loop below, including the logical-commit format).
- **The ask**: *implement and commit every task in order, then return a one-paragraph summary
  of what changed and any task-plan corrections you had to make.*

When the subagent returns, resume here to assemble the envelope.

## Per-task loop

Work the task list in order. For each task:

1. **Implement it** — adapt the existing pattern; don't introduce a new one when one fits.
2. **Verify it works:**
   - **Lint + format — BOTH must pass.** Run `make check` if the repo has that target.
     Otherwise run the linter **and** the formatter-check explicitly — they are separate
     checks and CI runs them separately:
     - Python/uv: `uv run ruff check . && uv run ruff format --check .`
     - Python/pip: `ruff check . && ruff format --check .`
     - JS/TS: `npm run lint && npm run format:check` (or the project's equivalent)
     - Other: see `AGENTS.md`/`CLAUDE.md` for the canonical command.

     **A green `ruff check` does NOT imply a green `ruff format --check`.** `ruff check`
     validates lint rules; `ruff format --check` validates whitespace/quotes/line breaks
     separately. Run both — CI fails on the formatter even when the linter is clean.
   - **Tests** — `make test` (or `uv run pytest tests/`, `npm test`, etc.) — only after
     tasks that touch source under the runtime path.
   - **`PYTHONPATH` gotcha (worktree).** When the shell has a pre-set `PYTHONPATH` from the
     parent repo, **prefix Python tests with `PYTHONPATH=<worktree-abs-path>`** (or
     `export PYTHONPATH=$PWD` once in the worktree shell). Without this, `app.*` imports
     silently resolve to **stale code in the parent checkout** instead of your worktree edits
     — producing bogus `TypeError: got an unexpected keyword argument` failures despite a
     correct edit. Same applies to `make test` / `make eval`.
3. **Commit it** (see *Logical commits*).
4. **Only then move to the next task.**

**If implementation reveals the task plan was wrong — STOP.** Correct the plan (update the
issue comment), then re-implement that task cleanly. Do **not** accumulate patches on top of a
wrong approach — errors compound. The plan is malleable; the spec is not. (This is the
malleable-plan principle from the contract.)

## Enforce the repo's invariants (binding)

The repo's **invariants** (documented in `AGENTS.md`/`CLAUDE.md`, `## Repo invariants`) are
**binding** — a passing PR must not violate any. The **constitution** principles also apply,
but as *justify-or-deviate*: a conscious, defensible deviation is allowed; silent drift is not.
Common categories that surface here:

- **Data model** — Pydantic / dataclass / TypedDict choice; structured-output mechanism.
- **State management** — fat-state / context-object pattern; how new fields land.
- **Layer rules** — business logic in services vs handlers vs agents.
- **LLM / prompts** — prompt-caching boundaries, structured output, model selection.
- **Naming / spelling** — brand-name spellings, case conventions.
- **Architectural changes** — when an ADR is required, and where it lives.

## Logical commits (anti-drift rule 2)

**One commit per task.** Conventional format — and the **WHY goes in the body**, because the
commit message is the durable home for work's decisions (a diff records *what*, never *why
this and not the obvious alternative*):

```
<type>(<scope>): <description>

- what changed and, when non-obvious, WHY this approach over the alternative

Closes #<issue>   ← ONLY on the final commit
```

Derive `<type>`/`<scope>` from the issue labels using the mapping in the `create_pr` skill.

**Do not squash** — the commit history is the implementation log. One commit per task, in order.

## Return

Return the envelope. Typical success — the new commit SHAs go in `state`, the substantive
choices go in `decisions`:

```json
{ "phase": "work", "status": "ok",
  "state": { "commits": ["a1b2c3d", "d4e5f6a", "9f8e7d6"] },
  "decisions": [ { "choice": "reused parse_ticket()", "why": "matches services/jira.py pattern", "rejected": "a new parser" } ],
  "notes": "All 4 tasks implemented and committed. Task 3 added a settings key (JIRA_PROJECT_KEY); plan comment corrected.",
  "parked": null }
```

- **A failure you don't understand → escalate to `ce-debug` before failing.** When a test
  fails for a reason you can't explain (not a quick reading-the-code fix), invoke the diagnosis
  protocol non-interactively: `Skill(ce-debug, "<the failing test + error + relevant state>  mode: pipeline")`.
  It investigates, root-causes, and — under **proceed-by-default** — applies a minimal test-first
  fix when that fix is safe and reversible. If it resolves the failure, re-run the gates and continue.
  Otherwise route its outcome **by kind**:
  - **Design-problem park** (ce-debug found the root cause is a design question for the human) →
    return `status: "parked"` with that question as `parked.question` — *not* `failed`.
  - **Unresolved red gate** (ce-debug couldn't root-cause-and-fix it) → `status: "failed"`.
- On `failed`: **push the branch first** so the findings are on origin; write `ce-debug`'s
  structured Debug Summary into the **draft PR/issue** (not the envelope), and keep `notes` a
  one-line pointer to it.
- `status: "parked"` with `parked: {question, options}` — only for a genuine mid-flight blocker
  that needs the human (e.g. implementation forces a product/UX call the plan didn't settle).
  Don't park for anything you can resolve by reading code or applying the documented pattern.
