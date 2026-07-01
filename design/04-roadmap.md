# 4 · Roadmap

> **Build the irreducible core. Defer anything the platform is racing to give you.**

## Build / defer / cut

| Investment | Verdict | Why |
|---|---|---|
| Stop owning isolation (skills accept a workspace) | 🟢 **Build first** | Biggest portability blocker; cheap; right regardless |
| Extract load-bearing bash → tested scripts | 🟢 **Build first** | Label-verify, review-poll are untested & prose-trapped |
| Model roles in one config file | 🟢 **Build** | De-hardcodes routing; ~free; durable |
| Lean knowledge file + advisory constitution | 🟢 **Build** | The appreciating asset; content not machinery |
| Decompose monolith → `SKILL.md` skills | 🟢 **Build** (after contract) | Portable format; pays off single-harness |
| State-envelope contract | 🟢 **Build** (gates the above) | The one thing standards don't give you |
| Vendored `ce-debug` skill | 🟢 **Build** (small) | Real gap; harness-native debug is weakest |
| CLI-first integration policy (MCP only when it earns it) | 🟢 **Adopt** | Keeps context lean; CLIs are battle-tested |
| `AGENTS.md` canonical → generate `CLAUDE.md` | 🟢 **Build** | Portable knowledge home; ~free |
| Non-interactive `ship_issue` (no modal prompts) | 🟢 **Build** | Required for fire-and-forget ([doc 7](07-build-decisions.md)) |
| Roll-up wake-up digest | 🟢 **Build** (small) | The only gap vs native Agent View |
| Shared risk classifier (park + review escalation) | 🟢 **Build** | One signal, two uses |
| Golden-set evals (own git history) + reviewer catch-rate | 🟢 **Build** (Ph2-3) | Rent Inspect AI ([doc 8](08-evals.md)) |
| Parallel orchestration + worktree isolation + monitor UI | 🔴 **Cut** | Native via `claude agents` (Agent View) |
| Cheap freshness pass for invariants | 🟡 **Defer** | Valuable, but manual-prompt first; no engine |
| LiteLLM / provider gateway | 🟡 **Defer** | YAGNI at one provider; rent Cursor if needed |
| `ce-brainstorm` / `ce-ideate` | 🟡 **Defer** | Only as *disposable* pre-issue framing |
| Cross-harness converter | 🔴 **Cut** | AGENTS.md + SKILL.md + MCP already do this |
| Knowledge-GC engine / schema | 🔴 **Cut** | Native memory persists; discipline > database |
| Multi-agent coding orchestration | 🔴 **Cut** | Fragile, ~15× tokens, research-only win |
| Adopt `ce-work` / `lfg` / `ce-simplify-code` | 🔴 **Cut** | Direct duplicates of what you own |

## Sequence

**Phase 1 — De-risk & foundation** *(low risk, improves the plugin today)*
1. Skills accept a workspace; remove `git worktree add/remove` from pipeline logic.
2. Extract label-verify, review-poll, cleanup into versioned, tested scripts.
3. Add `models.toml` roles; replace inline model names with role references.

**Phase 2 — Knowledge layer** *(the moat)*
4. Split invariants into taste (enforce) vs principle (justify-or-deviate).
5. Draft the ~40-line advisory constitution. Add the admission bar.
6. Point the harvest loop at the constitution; central judging of findings.

**Phase 3 — Decompose** *(gated on a contract)*
7. Define the plan-artifact + JSON return envelope.
8. Carve `ship_issue` into `plan / work / simplify / verify / learn` skills.
9. Slash command becomes a thin invoker. Keep `port-pr` + `code-simplifier`.

**Phase 4 — Rent the edges**
10. Vendor a pinned `ce-debug`. Optionally brainstorm/ideate as throwaway.

## What "done" looks like

- A harness switch touches only thin invokers + adapters, not the logic.
- A model swap is one config edit + a golden-eval re-check.
- Every PR closes on a **real** pass/fail gate.
- The knowledge file stays under ~200 lines and *corrects* you, not just mirrors you.
- You spend your time shipping product, not maintaining infrastructure the vendors
  are commoditising for free.

## The three metrics to watch (ignore vanity)

**Cycle time · change-fail/rework rate · escaped defects.** Not LoC, PR count, or
% AI-written. If churn rises, the system is generating slop — stop and fix the loop.

🟢 **Resolved:** proceed incrementally, phase by phase, without locking the architecture
doc first. That's what happened — Phases 1-4 above have since shipped and merged (see
the top-level `README.md`'s Status log, v0.3.0 through v0.6.0).
