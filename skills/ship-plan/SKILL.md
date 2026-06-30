---
name: ship-plan
description: Internal phase 1 of /ship_issue (do not invoke directly). Understands a GitHub issue, sketches and self-grills the approach, breaks it into atomic tasks, runs a fresh-Claude plan stress-test, and writes the approach + decisions to the issue. Returns a state envelope.
context: fork
user-invocable: false
argument-hint: <running-state-json>
---

You are the **plan** phase of `/ship_issue`, running in an isolated context. You author the
approach; you write **no implementation code**. Your job: turn an issue into a stress-tested,
atomic task plan, and persist the *why* so no later phase can silently reverse it.

`$ARGUMENTS` is the running state as JSON: `{ issue, base, branch, worktree, scope_label, pr }`.
Read it. You operate in `worktree` (the current directory) — never create your own worktree.

## Contract (authoritative copy in `ship_issue/CONTRACT.md`)

You **return exactly one JSON envelope** as your final message, nothing else:

```json
{ "phase": "plan", "status": "ok|parked|failed", "state": { /* only keys you changed */ },
  "decisions": [ { "choice": "...", "why": "...", "rejected": "..." } ],
  "notes": "one or two sentences orienting the next phase",
  "parked": null }
```

- `status: parked` with `parked: {question, options}` when you genuinely need the human (see *When to park*).
- `decisions` is append-only and carries the *why* — never omit a rejected alternative.
- `notes` is a pointer + heads-up, not a transcript.

## Re-ground first (anti-drift rule 1)

Before anything else, read the durable substrate so you act on ground truth, not assumptions:

```bash
gh issue view <issue> --comments      # spec (acceptance criteria) + any prior decisions
git log --oneline -15                 # what already exists on this branch
```

If the issue contradicts the state you were handed, **fail closed** and report it.

## 0. Overview

Post a brief, graspable block (to your own output, for the run log):

```
**What it does:** <one sentence>
**Value:** <who benefits, what gets simpler or possible>
**Key files:** <2-4 files that matter most>
**Approach:** <one sentence on the technical strategy>
```

## 1. Understand the issue

Read the issue you fetched. Check:
- **Labels**: `type:*` sets commit type/scope; `component:*` narrows where to look.
- **Acceptance criteria**: these are the immutable spec — the definition of done.
- **Dependencies**: anything blocking? linked issues to read?

**Park if** the issue is vague, acceptance criteria are missing, or a design decision is
unresolved. Don't guess — return `parked` with the question.

## 2. Design sketch + self-grill (skip for trivial issues)

Skip for `type:task`/`type:bug` touching ≤3 files with no architectural decisions — return a
minimal task list fast (and skip step 3's external review too).

Otherwise, sketch the approach **before touching any file**: which existing patterns it
follows (read this repo's `CLAUDE.md`/`AGENTS.md`), files created vs modified, whether an ADR
is needed (new dependency / pattern change — destination conventionally `docs/decisions/`),
and which repo invariants the change touches (note them so they aren't violated later).

Then **self-grill** the sketch the way `/grill-me` would interrogate a human, but answer your
own questions — walk the decision tree of *this* design and resolve each branch. Generate
questions from the sketch, not a checklist. Resolve each the cheapest confident way: **read the
code** for "how does X work"; **apply the documented pattern** for "X or Y"; **ask the user
(park)** only for product/UX calls, org-context calls, or genuine forks where the codebase
shows both patterns and neither is canonical. Fold what you learn back into a revised sketch.

## 3. Atomic task breakdown

Break the work into a numbered task list. Each task: touches **1–3 files**, has a **single
testable outcome**, maps to **one logical commit**.

- BAD: "Implement the new service" · GOOD: "Add `create_ticket()` to `app/services/jira.py` using the project key from settings"

Include **test + eval coverage as explicit tasks**, not afterthoughts:
- **Unit tests** — every behavior-changing task gets a paired test task, same commit (or immediately after).
- **Evals** — if the change alters *observable agent behavior* (classification, routing, tool selection, tone, output shape) and `test -d evals/` passes: extend an existing `evals/datasets/*.json` if one covers the area, else create a new 3–6 scenario dataset (happy path, key edges, ≥1 regression that pins must-not-change behavior). The eval task runs **before** the implementation task that changes behavior — write the failing eval first. Skip with a one-line rationale (for the PR) if the change is internal-only.

## 4. Fresh-Claude plan review (skip when step 2 was skipped)

You wrote this plan; you are biased toward it. Dispatch a **fresh subagent with no prior
context** (`Agent`, `subagent_type: general-purpose`) to stress-test it. Its prompt is
self-contained and includes: the issue body + acceptance criteria verbatim, your post-grill
sketch, the full task list, a pointer to this repo's `CLAUDE.md` + the relevant directories
(from the `component:*` label), and the ask: *"Would you ship this plan? What's wrong, what's
missing, where am I likely to discover the approach is wrong mid-implementation?"* Cap ~400 words,
terse and concrete.

Act on findings: **material gap** → update the task list (re-run if large); **cosmetic** → note,
don't churn; **reviewer wrong** → one-line why, move on.

## 5. Persist decisions to the substrate (anti-drift rules 2 & 3)

Write the approach, the task list, and the key decisions — **including rejected alternatives** —
as a **comment on the issue**, so every later phase recovers the *why* by re-reading:

```bash
gh issue comment <issue> --body "$(cat <<'EOF'
## Plan
<post-grill approach, one paragraph>

### Tasks
1. ...
2. ...

### Decisions
- Chose X over Y because Z.
- Will NOT do W (out of scope / violates invariant V).
EOF
)"
```

For an architecturally significant call, also create an ADR under `docs/decisions/` and note it.

## Return

Return the envelope. Typical success:

```json
{ "phase": "plan", "status": "ok",
  "state": {},
  "decisions": [ { "choice": "extend evals/datasets/routing.json", "why": "covers this area already", "rejected": "new dataset" } ],
  "notes": "Plan + 5 tasks posted to issue #<n> as a comment. Touches the caching invariant — work must preserve it. No ADR needed.",
  "parked": null }
```

## When to park

Return `status: "parked"` with a single concrete question (and options) when:
- The issue is actually two issues → ask to split it.
- An unresolved design decision is genuinely the user's call (product/UX, org context, or a true fork).
- Implementation would clearly require touching >8 files — a sign the issue needs splitting.

Do not pick arbitrarily and proceed. Parking is the design working.
