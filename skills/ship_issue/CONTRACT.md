# The state-envelope contract

> The one piece you can't rent. Standards (`AGENTS.md` / `SKILL.md` / `MCP`) cover
> knowledge, procedure, and tools — they do **not** cover the state that a single
> coherent context used to carry implicitly. Decompose `ship_issue` naively and that
> state (resolved base branch, task list, scope label, PR number, *and the rationale
> behind each decision*) evaporates. This contract is what makes the decomposition safe.

`/ship_issue` is a **thin orchestrator** that runs six isolated phase-skills in order:

```
plan → work → simplify → verify → [open PR] → review → learn → [auto-merge]
```

Each phase runs in a **fresh, isolated context** (`context: fork`) and hands a small
**JSON envelope** back to the orchestrator. The orchestrator threads accumulated state
forward. No phase inherits another's transcript — only the envelope and the durable
substrate survive a boundary.

This document is the single source of truth for that hand-off. Every phase-skill restates
the envelope shape inline (forks share no context, so each must be self-contained), but
**this file is authoritative** — if a phase and this file disagree, this file wins.

---

## Why decomposition needs a contract (the evidence)

Research is unambiguous (Cognition's *Don't Build Multi-Agents*; Anthropic's
*context engineering* and *long-running harnesses*; the ADR literature):

- **A diff records *what the code is*, never *why this and not the obvious alternative*.**
  If a decision's rationale isn't written somewhere re-readable, the next phase is free to
  "fix" it back. That reversal is **drift**, and it is the primary failure mode of a
  decomposed pipeline.
- **Compress the transcript, never the decisions.** Throwing away tool logs and test output
  at a phase boundary is correct — that's noise. Throwing away a decision or its rejected
  alternative is how phases diverge.
- **Isolation is safe for read-heavy work, risky for write-coupled work.** Plan and work
  *author* decisions; simplify / verify / review / learn mostly *read and report*. A phase
  that authors nothing cannot create a conflicting artifact.

So the design is **a thin envelope over a rich, re-readable substrate** — provided the
substrate carries the *why*, not just the *what*.

---

## The three layers

| Layer | What it is | Where it lives | Mutability |
|---|---|---|---|
| **Spec** | The issue's acceptance criteria — the contract for "done" | the GitHub issue body | **immutable** |
| **Substrate** (the blackboard) | The task plan, the **decisions log** (decision + why + rejected alternative), the diff, the commits | the issue + PR body + commit messages + the working tree | **append-only, re-readable** |
| **Envelope** | Handles + status + a decisions-delta + one prose line | passed phase → orchestrator → phase | **thin, transient** |

The **spec is immutable** (never silently widen scope). The **task plan is malleable** —
it absorbs mid-implementation discoveries; if implementation proves the plan wrong, the
plan is corrected, not patched around. Progress lives in **commits**, not a mutated plan.

The substrate is the ground truth. The envelope is only a **cursor into it** — never a
replacement for it.

---

## The envelope

Every phase returns exactly this JSON as its final message, and nothing else:

```json
{
  "phase": "work",
  "status": "ok",
  "state": {
    "issue": 42,
    "base": "origin/main",
    "branch": "feat/42-add-rate-limit",
    "worktree": "/abs/path/to/workspace",
    "scope_label": "scope:it-only",
    "pr": 123
  },
  "decisions": [
    { "choice": "reused parse_ticket()", "why": "matches services/jira.py pattern", "rejected": "a new parser" }
  ],
  "notes": "All 4 tasks implemented and committed. Task 3 added a new settings key (JIRA_PROJECT_KEY).",
  "parked": null
}
```

### Field semantics

| Field | Type | Reducer | Meaning |
|---|---|---|---|
| `phase` | string | — | Which phase produced this envelope (`plan`/`work`/`simplify`/`verify`/`review`/`learn`). |
| `status` | `ok` \| `parked` \| `failed` | — | The **only** thing the orchestrator branches on. |
| `state` | object | **merge (overwrite)** | Durable handles. The orchestrator merges these forward into the running state and passes the result to the next phase. A phase only sets the keys it changed. |
| `decisions` | array | **append** | Decisions this phase made, each `{choice, why, rejected}`. Append-only across the run — never deduped away. Also written to a durable home (see below). |
| `notes` | string | overwrite | One or two sentences orienting the next phase. A **pointer + heads-up**, never the record of a decision. Keep it short; no transcripts, no tool output. |
| `parked` | `{question, options?}` \| null | — | Present only when `status` is `parked` — the single question for the human. |

### `state` keys

| Key | Set by | Used by |
|---|---|---|
| `issue` | orchestrator (from args) | every phase (re-grounding) |
| `base` | orchestrator (base resolution) | work (branch point), open-PR plumbing |
| `branch` | orchestrator / work | work, open-PR, review |
| `worktree` | orchestrator (workspace setup) | every phase (where to operate) |
| `scope_label` | open-PR plumbing | learn, label verification |
| `pr` | open-PR plumbing | review, learn, auto-merge |
| `commits` | work / simplify / review (optional) | the digest; informational — latest-wins like the rest of `state` |

---

## Orchestrator control flow

The orchestrator owns: argument parsing, base resolution, workspace setup, PR creation,
label verification, auto-merge, and the wake-up digest. It owns **no reasoning** — that
lives in the phases. For each phase it:

1. Invokes the phase-skill (`context: fork`), passing the current running state as JSON in
   `$ARGUMENTS`.
2. Reads the returned envelope and branches on `status`:
   - **`ok`** → merge `state` into the running state, append `decisions`, run the next phase.
   - **`parked`** → **stop.** Surface `parked.question` in the digest (`⚠ needs your call`).
     Leave the branch/PR in place for the human.
   - **`failed`** → **stop.** Surface `notes`; if a branch/PR exists, leave it as a draft
     with the findings. Do not force past a red gate.
3. **Validates the envelope** before trusting it. Markdown skills cannot enforce a typed
   output schema, so the orchestrator checks: valid JSON, known `status`, `state` present.
   If a phase returns malformed output, re-invoke it once asking for the envelope only; if
   it fails again, treat as `failed`.

"Open PR" and "auto-merge" are **deterministic plumbing the orchestrator runs directly** —
they are not reasoning phases and have no envelope.

---

## The anti-drift rules (every phase obeys these)

1. **Re-ground before acting.** Each phase's first action is to re-read the durable
   substrate — the issue (spec + decisions), `git log`, and the diff — *before* trusting the
   envelope it was handed. If the substrate contradicts the envelope, **fail closed** and
   report it; do not proceed on a stale assumption.
2. **Decision allowlist on compaction.** When deciding what to carry, drop raw tool output
   and test logs freely. **Never** drop a decision, a rejected alternative, or an invariant.
   These go in `decisions` *and* a durable home.
3. **Drift tripwire.** A phase that would reverse a decision recorded in the substrate must
   surface a **reconciliation note** (in `notes` and on the PR), not silently overwrite it.
   Example: *"This simplification removes the guard added for acceptance criterion #2 —
   flagging rather than dropping."*

### Where decisions are durably written (not just in the envelope)

The `decisions` array is the *delta*; its permanent home is the substrate, so a fresh phase
recovers the *why* by re-reading — no transcript required:

- **plan** writes its approach + key decisions + rejected alternatives as a **comment on the
  issue** (and, for architectural calls, an ADR under `docs/decisions/`).
- **work** writes the *why* into **commit messages** (the body, not just the subject).
- The **PR body** carries a short **`## Decisions`** section summarizing the run.

---

## Invocation mechanics (Claude Code specifics)

- Each phase-skill sets **`context: fork`** so it runs in an isolated context; the skill body
  becomes the fork's prompt and its final message (the envelope) returns to the orchestrator.
- Each phase-skill sets **`user-invocable: false`** so it is **model-invocable but hidden from
  the `/` menu** — the orchestrator can call it, users don't see it as a standalone command.
  (Do **not** use `disable-model-invocation: true`; that would block the orchestrator's
  programmatic call.)
- The phase-skills are named with a **`ship-` prefix** (`ship-plan`, `ship-work`, …) to avoid
  colliding with the bundled `/verify`, `/review`, `/simplify` skills.
- **Workspace-agnostic:** phases operate on the current working directory and **never create
  their own worktree**. Isolation is the orchestrator's (and ultimately the harness's) job.
- **Model routing** stays role-based (see `MODELS.md`): the orchestrator and the
  plan / review / learn phases run as the **planner** tier; **work** delegates its token-heavy
  implementation loop to an **implementer**-tier (Sonnet) subagent; **simplify** delegates to
  the `code-simplifier` agent. Reference roles/aliases, never pinned model IDs.
