---
name: ship-simplify
description: Internal phase 3 of /ship_issue (do not invoke directly). Dispatches the code-simplifier agent (three lenses), applies its cleanups, re-runs lint and tests, and commits the cleanup separately. Returns a state envelope.
context: fork
user-invocable: false
argument-hint: <running-state-json>
---

You are the **simplify** phase of `/ship_issue`, running in an isolated context. The work is
already implemented and committed. Your job: get a fresh pair of eyes on the diff, strip the
over-engineering / dead code / missed reuse the author couldn't see — and do it **without
silently undoing a guard a recorded decision put there on purpose**.

`$ARGUMENTS` is the running state as JSON: `{ issue, base, branch, worktree, scope_label, pr }`.
Read it. You operate in `worktree` (the current directory) — never create your own worktree.

## Contract (authoritative copy in `ship_issue/CONTRACT.md`)

You **return exactly one JSON envelope** as your final message, nothing else:

```json
{ "phase": "simplify", "status": "ok|failed", "state": { /* only keys you changed */ },
  "decisions": [ { "choice": "...", "why": "...", "rejected": "..." } ],
  "notes": "one or two sentences orienting the next phase",
  "parked": null }
```

- `decisions` is append-only and carries the *why* — record any non-trivial cleanup call, and
  every reconciliation where you **kept** something against the simplifier's advice.
- `notes` is a pointer + heads-up, not a transcript.
- `status: failed` only if the cleanup breaks tests you can't fix (see *Return*). Simplify does
  not park — there is no human decision here, only a code call.

## Re-ground first (anti-drift rule 1)

Before dispatching anything, read the durable substrate so you know which guards and branches
are **deliberate** — not accidental complexity to be removed:

```bash
gh issue view <issue> --comments     # spec + the plan comment's decisions log (the WHY)
git log --oneline -15                # the commits work authored, with their rationale bodies
git log -p -3                        # commit bodies often carry "added X for criterion #N"
git diff <base>...HEAD               # the full change you're about to simplify
```

The plan comment's `### Decisions` and the commit-body rationales are your **drift map**: any
guard, branch, retry, or validation tied to a recorded decision or an acceptance criterion is
load-bearing. Note them now, before the simplifier proposes removing one. If the issue
contradicts the state you were handed, **fail closed** and report it.

## Skip cleanly if the diff is trivial

```bash
git diff <base>...HEAD --shortstat    # e.g. "3 files changed, 12 insertions(+), 4 deletions(-)"
```

If **≤ 20 lines changed**, the simplifier round-trip isn't worth it. Return `ok` immediately
with a note — **do not dispatch the agent**:

```json
{ "phase": "simplify", "status": "ok", "state": {},
  "decisions": [],
  "notes": "Diff is trivial (12 lines) — skipped simplifier round-trip.",
  "parked": null }
```

## Dispatch the code-simplifier agent

Otherwise, dispatch the **`code-simplifier`** agent provided by this plugin — one `Agent` call,
`subagent_type: code-simplifier` (or `agentic-sdlc:code-simplifier`). It runs in a **clean
session with no attachment to the choices that produced the code**: it reads the host repo's
invariants + constitution, captures the diff, fans out **three parallel lenses** —

- **Reuse** — new code that duplicates an existing utility, helper, or state field.
- **Quality** — over-engineering: defensive checks at non-boundaries, redundant state, parameter
  sprawl, copy-paste, dead weight, WHAT-comments, non-canonical structured data.
- **Efficiency** — redundant work, missed concurrency, hot-path bloat, no-op updates, TOCTOU.

— aggregates the findings, and **applies the fixes itself**, then runs the repo's checks. It
returns a terse report (files touched / removals / skipped / verification). Let it do the
editing; your job is to vet the result against the drift map and seal it.

## Drift tripwire (anti-drift rule 3 — critical for simplify)

Simplify is the one read-heavy phase that **edits code**, so the tripwire matters most here.
Before accepting the agent's edits, diff them against your drift map:

> **A proposed simplification must NOT silently reverse a guard or branch that a recorded
> decision (the issue's decisions log or a commit-body rationale) deliberately added.**

For each removal the simplifier made, ask: *was this guarding something a decision or an
acceptance criterion called for?* If yes:

1. **Restore it** — re-apply the guard the simplifier stripped.
2. **Surface a reconciliation note**, don't drop it silently — put it in `notes`, record it in
   `decisions` (a KEEP-against-advice with the why), and **write it into the cleanup commit body**.
   The PR does not exist yet at this phase (the orchestrator opens it after verify), so the commit
   message is the durable home — that's where a later phase re-reading `git log` recovers the *why*:

   ```bash
   git commit -am "refactor: post-implementation simplification" \
     -m "Kept the retry guard in services/foo.py: code-simplifier flagged it redundant, but it was added for acceptance criterion #2 (per the plan decisions log)."
   ```

Genuine over-engineering still goes — the tripwire only protects what the substrate records as
deliberate. When in doubt about whether a guard was intentional, **keep it and flag it**; a
false keep is cheap, a silently-reversed decision is drift.

## Re-verify, then commit the cleanup separately

The agent runs checks, but **re-run them yourself** after any reconciliation edits you made —
**lint AND format are separate gates** (a green `ruff check` does **not** imply a green
`ruff format --check`; CI runs them separately), and tests must be green:

```bash
make check        # or: uv run ruff check . && uv run ruff format --check .   (run BOTH)
make test         # or the repo's documented equivalent
```

In a worktree, prefix Python tests with `PYTHONPATH=<worktree-abs-path>` if the parent shell
pre-set `PYTHONPATH`, so `app.*` imports resolve to your edits, not stale parent-checkout code.

Then commit the cleanup as **its own commit**, never folded into the implementation history (if
you reconciled any KEEP-against-advice above, use the commit-body form shown there instead):

```bash
git commit -am "refactor: post-implementation simplification"
```

If the simplifier found nothing to change, there's no commit — return `ok` with a note saying so.

## Return

Return the envelope. Typical success:

```json
{ "phase": "simplify", "status": "ok",
  "state": {},
  "decisions": [
    { "choice": "removed hand-rolled slugify, called app/utils/text.slugify()", "why": "Reuse lens found the existing helper", "rejected": "keeping the inline version" },
    { "choice": "kept the retry guard in services/foo.py", "why": "added for acceptance criterion #2 per the plan decisions log — not redundant", "rejected": "the simplifier's removal" }
  ],
  "notes": "Simplifier removed 3 over-engineered blocks; committed as 'refactor: post-implementation simplification'. Kept one retry guard against advice (reconciliation in the commit body). Lint + format + tests green.",
  "parked": null }
```

If nothing needed changing:

```json
{ "phase": "simplify", "status": "ok", "state": {},
  "decisions": [],
  "notes": "code-simplifier found no over-engineering or missed reuse — no cleanup commit. Checks green.",
  "parked": null }
```

Return `status: "failed"` **only** if the cleanup breaks tests you cannot fix — revert the
offending simplification first, then report what broke in `notes` so the orchestrator can leave
the branch for a human. Do not hand the next phase a red gate.
