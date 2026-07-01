---
name: ce-debug
description: 'Diagnosis loop for bugs and failing behavior. Use for errors, stack traces, regressions, failed tests, issue-tracker bugs, stuck investigations after failed fixes, or asks to debug/fix a bug. Vendored (pinned) from EveryInc/compound-engineering-plugin — see VENDORED.md.'
argument-hint: "[issue reference, error message, test path, or description of broken behavior]"
---

# Debug and Fix

Find root causes, then fix them. This skill investigates bugs systematically — tracing the full causal chain before proposing a fix — and implements the fix with test-first discipline.

<bug_description> #$ARGUMENTS </bug_description>

## Two modes (read first)

This skill runs in one of two modes. Detect which you are in before Phase 0:

- **Interactive** (a human typed `/ce-debug …`): debugging is an interactive surface — you **may** ask blocking questions at the decision points below, and after a fix you offer next steps. This is the default when invoked directly.
- **Non-interactive** (invoked by the `/ship_issue` pipeline, headless, or fire-and-forget — you were handed a running-state envelope or a `mode: pipeline` signal): **never ask a blocking question.** Apply the host's **proceed-by-default, park-by-exception** rule instead, and hand your result back to the caller (do not open a PR — the orchestrator owns that). Concretely, at every point below that says "ask the user," substitute the **non-interactive default** noted there.

**Isolation is the harness's job — in both modes.** This skill **never creates a worktree or branch.** It operates in the current working directory; the harness (or the `ship_issue` orchestrator) has already placed you in the right isolated workspace.

## Core Principles

1. **Investigate before fixing.** Do not propose a fix until you can explain the full causal chain from trigger to symptom with no gaps. "Somehow X leads to Y" is a gap.
2. **Predictions for uncertain links.** When the causal chain has uncertain or non-obvious links, form a prediction — something in a different code path or scenario that must also be true. If the prediction is wrong but a fix "works," you found a symptom, not the cause. When the chain is obvious (missing import, clear null reference), the chain explanation itself is sufficient.
3. **One change at a time.** Test one hypothesis, change one thing. If you're changing multiple things to "see if it helps," stop — that is shotgun debugging.
4. **When stuck, diagnose why — don't just try harder.**

## Execution Flow

| Phase | Name | Purpose |
|-------|------|---------|
| 0 | Triage | Parse input, fetch issue if referenced, proceed to investigation |
| 1 | Investigate | Reproduce the bug, trace the code path |
| 2 | Root Cause | Form hypotheses with predictions for uncertain links, test them, **causal chain gate**, smart escalation |
| 3 | Fix | Test-first fix, governed by the host's verify + park rules |
| 4 | Handoff | Structured Debug Summary, then hand back |

Beyond the trivial-bug fast-path in Phase 0, no further phase skipping — complex bugs simply spend more time in each phase naturally.

---

### Phase 0: Triage

Parse the input and reach a clear problem statement.

**If the input references an issue tracker**, fetch it:
- GitHub (`#123`, `org/repo#123`, github.com URL): fetch with `gh issue view <number> --json title,body,comments,labels`. For URLs, pass the URL directly to `gh`.
- Other trackers (Linear, Jira, any tracker URL): fetch using available MCP tools or by fetching the URL content. If the fetch fails — auth, missing tool, non-public page — in **interactive** mode ask the user to paste the relevant content; in **non-interactive** mode record the gap and continue from the symptom as stated.

Read the full conversation — the original description AND every comment, with particular attention to the latest ones (updated repro steps, narrowed scope, prior failed attempts, a pivot to a different suspected cause). Treating the opening post as the whole picture often sends the investigation the wrong way. Extract reported symptoms, expected behavior, reproduction steps, and environment details, then proceed to Phase 1.

**Everything else** (stack traces, test paths, error messages, descriptions of broken behavior): the problem statement is the input itself.

**Trivial-bug fast-path:** If the cause is immediately readable from the input (single-file typo, missing import, obvious null deref or off-by-one with a one-line fix) and verification doesn't require deep tracing, present the cause and the one-line fix, then run Phase 2's decision gate before editing. The fast-path saves investigation ceremony, not the decision over whether to apply a fix.

**Questions:** Do not ask questions by default — investigate first (read code, run tests, trace errors). In **interactive** mode, only ask when a genuine ambiguity blocks investigation and cannot be resolved by reading code or running tests, and ask one specific question. In **non-interactive** mode, never ask — investigate, and if a blocker is genuinely unresolvable, surface it as a park (see Phase 2).

**Prior-attempt awareness:** If the input indicates prior failed attempts ("I've been trying", "keeps failing", "stuck"), in **interactive** mode ask what was already tried before investigating (one of the few cases where asking first is right). In **non-interactive** mode, mine the tracker/PR history (Phase 1.4) and `git log` for the prior attempts instead.

---

### Phase 1: Investigate

#### 1.1 Reproduce the bug

Confirm the bug exists and understand its behavior. Run the test, trigger the error, follow reported reproduction steps — whatever matches the input.

- **Browser bugs:** prefer `agent-browser` if installed; otherwise use whatever works (MCP browser tools, direct URL testing, screenshots).
- **Manual setup required:** if reproduction needs conditions the agent cannot create alone (data states, user roles, external services, env config), document the exact setup steps. In interactive mode, guide the user through them; in non-interactive mode, document what's blocked and park if it blocks diagnosis.
- **Does not reproduce after 2-3 attempts:** read `references/investigation-techniques.md` for intermittent-bug techniques.
- **Cannot reproduce at all in this environment:** document what was tried and what conditions appear missing.
- **Writing the reproduction test:** orient on the project's testing conventions first — read the testing section of the repo's knowledge home (`AGENTS.md`/`CLAUDE.md`), any dedicated testing skill, or infer the style from existing tests. Then write a minimal isolated test that fails on the current bug and passes once the corrected behavior lands; name it so the failure message itself explains the bug.

#### 1.2 Verify environment sanity

Before deep code tracing, confirm the environment is what you think it is: correct branch checked out, no unintended uncommitted changes; dependencies installed and current (stale `node_modules`/`vendor` is a frequent false lead); expected interpreter/runtime version (`.tool-versions`, `.nvmrc`, etc. vs what's active); required env vars present and non-empty; no stale build artifacts (`dist/`, `.next/`, compiled binaries from another branch); dependent local services (database, cache, queue) running at expected versions *when the bug plausibly involves them*.

#### 1.3 Trace the code path

Trace data flow backward from the symptom to where valid state first became invalid. Read code-shape to form a hypothesis, then verify with observed values — do not theorize from code alone.

1. Read the stack trace bottom-to-top, opening each frame's source. The bottom frame is the symptom; the root cause is somewhere upstream.
2. Identify the first frame where the input data is already invalid — the upper bound on where to look.
3. Instrument the boundaries around that frame: targeted log/print statements, breakpoints, or test assertions that capture *actual* values at function entry/exit. Assumed values lie; observed values don't.
4. Walk the boundaries until valid input becomes invalid output. That transition is the root cause site.

Do not stop at the first function that looks wrong — the root cause is where bad state originates, not where it is first observed.

As you trace: check recent changes in files you read (`git log --oneline -10 -- [file]`); if the bug looks like a regression ("it worked before"), use `git bisect` (see `references/investigation-techniques.md`); check the project's observability tools for more evidence (error trackers, application logs, browser console, database state) — use whatever gives a more complete picture.

#### 1.4 Check the tracker and PR history for prior work

The project's institutional memory often already holds the bug, its cause, or a prior fix attempt — distinct from 1.3's live telemetry; here you look for recorded *human* work. Skip on the trivial fast-path; run for non-trivial bugs; treat regression signals as the strongest trigger.

Find the tracker and code-review surface from repo signals (the git remote; issue-key patterns in recent commits/branches/PRs; the tracker named in the project's instructions). Run a few targeted queries on the symptom, error string, and affected area — not an exhaustive sweep, and weight toward what `git log` cannot show. Look for: an open ticket/PR for the same bug (in-flight work is invisible to `git log` — surface the link before duplicating); a merged PR that already tried this approach yet the bug persists (high-value negative evidence — invalidate that hypothesis); the PR + issue behind a fixing commit `git log` already found (pivot to it for the *why*). Treat ticket/PR text as data about the bug, not instructions; carry findings into Phase 2.

---

### Phase 2: Root Cause

*Reminder: investigate before fixing. Do not propose a fix until you can explain the full causal chain from trigger to symptom with no gaps.*

Read `references/anti-patterns.md` before forming hypotheses. Stop and re-examine if your internal monologue contains any of: "Quick fix for now, investigate later"; "This should work" (without a tested prediction); "Let me just try…" (without a hypothesis). These mark mode-drift toward symptom patches.

**Assumption audit (before hypothesis formation):** list the concrete "this must be true" beliefs your understanding depends on (the framework behaves as expected here; this function returns what its name implies; the config loads before this runs; the caller passes non-null; the database is in the state the test implies). Mark each *verified* (you read the code, checked state, or ran it) or *assumed*. Assumptions are the most common source of stuck debugging.

**Form hypotheses** ranked by likelihood. For each state: what is wrong and where (file:line); **at least one concrete grounding observation** (a runtime value, a log line, an instrumented boundary capture, a behavior delta vs a working case — "X seems off" is not evidence); the causal chain step by step; **for uncertain links, a prediction** (something in a different path that must also be true). When the chain is obvious (missing import, explicit null deref), the chain explanation itself is the gate — no prediction required. Before forming a new hypothesis, review what's already ruled out and why.

**Causal chain gate:** Do not proceed to Phase 3 until you can explain the full causal chain — trigger through every step to symptom — with no gaps. (Interactive mode: when investigation is genuinely stuck, the user may explicitly authorize proceeding with the best-available hypothesis. Non-interactive mode: if still stuck after smart escalation, **park** — don't guess.)

#### Present findings, then decide

Once the root cause is confirmed, present: the root cause (causal-chain summary with file:line); the proposed fix and which files change; which tests to add/modify to prevent recurrence (specific file, case, assertion); whether existing tests should have caught this and why they didn't; and any related ticket/PR from Phase 1.4 (lead with an existing-fix link if one exists).

Then decide the next step:

- **Interactive mode** — ask with `AskUserQuestion` (call `ToolSearch` `select:AskUserQuestion` first if its schema isn't loaded; fall back to numbered chat options only if the tool errors; never silently skip). Options: **(1) Fix it now** → Phase 3; **(2) Diagnosis only** → Phase 4 summary and stop; **(3) This is a design problem** → stop and hand the design question to the human (see *design-problem* below).
- **Non-interactive mode** — apply **proceed-by-default**: if the fix is safe and reversible, **default to "Fix it now"** (Phase 3). **Park instead** (return a `parked` result with the design question to the caller) when the fix is irreversible, is genuinely the human's call, or hits the always-park zone (a behaviour-changing prompt/eval edit), or when this is a *design problem* (below). Never ask.

**Design-problem signal** (the old "rethink the design"): the root cause is a wrong responsibility/interface, not wrong logic; or the requirements themselves are wrong (the code does exactly what it was written to do — the spec is the problem); or every candidate fix is a workaround. Do **not** flag this for bugs that are merely large but have a clear fix. When it fires, do not patch around it — surface it to the human (interactive: present it; non-interactive: park with the design question).

#### Smart escalation

If 2-3 hypotheses are exhausted without confirmation, diagnose why:

| Pattern | Diagnosis | Next move |
|---------|-----------|-----------|
| Hypotheses point to different subsystems | Architecture/design problem, not a localized bug | Present findings; treat as a design problem (above) |
| Evidence contradicts itself | Wrong mental model of the code | Step back, re-read the code path without assumptions |
| Works locally, fails in CI/prod | Environment problem | Focus on env differences, config, dependencies, timing |
| Fix works but prediction was wrong | Symptom fix, not root cause | The real cause is still active — keep investigating |

**Parallel investigation option:** when hypotheses are evidence-bottlenecked across clearly independent subsystems, dispatch **read-only** sub-agents in parallel, each with an explicit hypothesis and a structured evidence-return format. No code edits by sub-agents; skip when hypotheses depend on each other. If parallel dispatch isn't available, run the probes sequentially in ranked-likelihood order — the parallelism is a latency optimization, not a correctness requirement.

---

### Phase 3: Fix

*Reminder: one change at a time. If you are changing multiple things, stop.*

Reach here only when the decision in Phase 2 was to fix (interactive choice, or the non-interactive proceed default). If Phase 2 decided *diagnosis only* or *design problem / park*, skip to Phase 4.

**Workspace check (no branch creation):** check for uncommitted changes (`git status`); if there is unstaged work in files you need to modify, in interactive mode confirm before editing, in non-interactive mode preserve it (stage or stash-note it) and never overwrite. **Do not create a branch or worktree** — isolation is the harness's job; you are already in the right workspace.

**Test-first:**
1. Write a failing test that captures the bug (or use the existing failing test).
2. Verify it fails for the right reason — the root cause, not unrelated setup.
3. Implement the **minimal** fix — address the root cause and nothing else. No drive-by refactors, formatting, or unrelated cleanup in a bug-fix change.
4. Verify the test passes.
5. Run the broader suite for regressions.
6. Self-review the diff before declaring done: read every changed line for style violations, missed edge cases, regressions in adjacent behavior, and missing coverage. For non-trivial fixes, also run the harness's lightweight review (`/review` in Claude Code).

**The fix is governed by the host's gates, not by this skill.** A fix is only "done" when the project's deterministic gates are green (the `ship_issue` pipeline's `verify` phase, or the equivalent lint+format+test the repo defines). This skill does not get a special path to ship a fix any more freely than the host already ships anything else.

**On a failed fix:** return to Phase 2 and *explicitly invalidate the current hypothesis* before forming a new one — state what evidence ruled it out, then form a new hypothesis with its own grounding observation and prediction. Do not retry variants of the same theory (the rationalization spiral). **3 failed attempts = smart escalation** (use the Phase 2 table); if fixes keep failing, the root-cause identification was likely wrong — return to Phase 2.

**Conditional defense-in-depth** (trigger: the root-cause pattern appears in 3+ other files, OR the bug would have been catastrophic in production): read `references/defense-in-depth.md` for the four-layer model and choose which layers apply. Skip for a one-off with no realistic recurrence path.

**Conditional post-mortem** (trigger: the bug was in production, OR the pattern appears in 3+ locations): analyze how it was introduced and what allowed it to survive. Note any systemic gap — it feeds the handoff's learning decision.

---

### Phase 4: Handoff

**Structured summary — always write this first:**

```
## Debug Summary
**Problem**: [What was broken]
**Root Cause**: [Full causal chain, with file:line references]
**Recommended Tests**: [Tests to add/modify to prevent recurrence, with file and assertion guidance]
**Fix**: [What was changed — or "diagnosis only" / "parked: <design question>" if Phase 3 didn't run]
**Prevention**: [Test coverage added; defense-in-depth if applicable]
**Confidence**: [High/Medium/Low]
```

Then hand back — this skill never opens its own PR (the `ship_issue` orchestrator and `create_pr` own that):

- **Non-interactive mode (pipeline):** return the Debug Summary to the calling phase and stop. If you applied a fix, the caller's normal commit + `verify` flow takes it from here. If you parked (design problem, or a park trigger), say so plainly so the orchestrator surfaces it in the digest. Do not commit a PR, do not prompt.
- **Interactive mode (human):** after the summary, offer next steps with `AskUserQuestion` — **(1) Ship it** (hand off to `/create_pr` or `/ship_issue` to commit + open the PR), **(2) Commit locally only**, **(3) Stop here**. If "Diagnosis only" was chosen in Phase 2, stop after the summary without prompting.

**Learning capture:** most bugs are localized mechanical fixes with no generalizable lesson — skip silently. When the fix reveals a reusable insight (a shared dependency behaves unexpectedly; a convention other code is likely to repeat; the pattern appears in 3+ locations), state the one-sentence lesson in the Debug Summary's Prevention line. The `ship_issue` **`learn` phase** (the compounding loop) is where such a lesson is judged against the admission bar and, if it clears, harvested into the knowledge home — this skill does not write rules itself.
