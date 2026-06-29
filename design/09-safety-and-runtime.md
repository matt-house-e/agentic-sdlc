# 9 · Safety & runtime (AFK)

> **Auto-mode gates *interruption*, not *blast radius*. Contain the agent with
> platform-native environment config — sandbox + branch protection + credential
> hygiene — not custom code. Only the auto-merge gate is risk-keyed.**

## The distinction that matters

Running fire-and-forget means no human is there to catch a bad action. Two different layers:

| Layer | Controls | Our setting |
|---|---|---|
| **Permission mode** | Whether the agent *stops to ask* | **Auto mode** — keep it (you want no prompts AFK) |
| **Isolation** | What the agent *can do* without asking | **Was missing** — this doc fixes it |

Anthropic's own docs are explicit: auto-mode is *"a per-action control, not an isolation
boundary,"* with a measured **~17% false-negative rate** (dangerous actions wrongly
approved). It's a real improvement over skip-permissions — **not** a containment guarantee.
([auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode) ·
[sandboxing](https://www.anthropic.com/engineering/claude-code-sandboxing))

## Why instruction-based rules don't work

System-prompt rules are advisory, not enforceable. Documented unattended-agent incidents:

- **Replit** — agent deleted a production DB *during a code freeze*, wiped 1,200+ records, then fabricated that rollback was impossible (Fortune, 2025-07).
- **PocketOS** — agent deleted a prod DB in **9 seconds** via an unrelated over-scoped token (Zenity, 2026).
- **`rm -rf` / drive wipes** despite the user typing "DO NOT RUN ANYTHING" (Cursor, Antigravity, Claude Code #10077).

The lesson: **containment must be environmental, not a written rule** the model can ignore.

## The minimal effective set (the 80/20)

Almost everything irreversible funnels through **one chokepoint — auto-merge to main.** So
contain the environment, gate the chokepoint, and stop:

| Catastrophic op | Cheapest control | Type |
|---|---|---|
| `rm -rf`, disk wipe | **Sandbox/devcontainer** — host unreachable | env config |
| Secret exfil / phone-home | Network egress allowlist; creds outside sandbox | env config |
| Drop/migrate prod DB | **No prod creds in the worktree env**; hold high-risk for human | env + gate |
| Force-push / rewrite main | **Branch protection** (block force-push, linear history) | platform |
| Bad code auto-merged | **Required green CI** as merge gate | platform |
| Over-scoped token abuse | Least-privilege, short-lived tokens | env config |

**Note the column on the right: almost none of this is code we write.** It's sandbox +
branch protection + credential hygiene — all platform-native. (Setup tracked in
[issue #6](https://github.com/matt-house-e/agentic-sdlc/issues/6).)

## The one risk-keyed control: auto-merge gate

The only safety logic that lives in the pipeline:

- **Low-risk** change → auto-merge while you sleep.
- **High-risk** change (migrations / auth / secrets / CI / infra) → **hold for human merge**, surfaced in the digest.

This is the **third consumer of the shared risk classifier** (after park-vs-proceed and
review-tier escalation). One signal, three uses — which is what justifies one classifier
over three ad-hoc rules.

## What we deliberately do NOT build

A bespoke **always-block list** — research flags it as the over-build: it just
re-implements auto-mode's per-action classifier, with the same false-negative problem.
Containment is the **sandbox**, not a denylist the agent could still find a way around.

## Defense in depth

Keep **auto mode** (better than skip-permissions). But the **sandbox is mandatory**, not
optional — the ~17% residual false-negative rate is *exactly why* you don't rely on the
permission classifier as your only line.
