# Model roles

The harness references **capability roles**, not model names in prose. Each role maps to a
tier alias **and an effort level**, set where Claude Code enforces it — so swapping a model is
one edit here plus the listed enforcement point, and aliases auto-ride upgrades within a tier.

Claude Code enforces routing in three places: skill frontmatter (`model`, `effort` — `model`
holds for the rest of that turn, and in a `context: fork` skill it sets the fork's model),
subagent frontmatter, and the Agent tool's per-dispatch `model` / `effort` (which override
frontmatter). Always dispatch in the foreground (`run_in_background: false`); a forked skill
needs `background: false`.

## Role → model + effort

| Role | Model | Effort | Enforced by | Used for |
|---|---|---|---|---|
| `orchestrator` | the session model, chosen by the user at launch: `opus` by default; `fable` when the issue reads as long-horizon or ambiguous at scale (an epic, or several cost-of-wrong areas at once) | `high` | effort: `ship_issue` frontmatter; model: the launch command | risk read, plan, implementation judgment, gate, digest |
| `reviewer` | session model | `xhigh` | `ship-review` frontmatter | the armed independent review (it only runs when a risk signal fired) |
| `plan-critic` | `opus` (`fable` for the hardest designs) | `high` | Agent dispatch | "would you ship this plan — what's wrong or missing?" |
| `implementer` | `sonnet` | `medium` | Agent dispatch | the delegated token-heavy coding loop |
| `simplifier` | `sonnet` | `medium` | Agent dispatch | the `code-simplifier` agent on an over-built diff |
| `reader` | `haiku` (`sonnet` when the read needs judgment) | `low`–`medium` | Agent dispatch | read-only scans: call sites, prior art, logs |

The frontmatter effort is a pin, not a floor: `ship_issue` runs at `high` even when the session
was launched at `xhigh` or `max`. To run a hard issue higher, raise the pin in
`skills/ship_issue/SKILL.md`.

## The models

Anthropic API list prices per million tokens, input / output, checked 2026-10-13. Aliases
resolve differently on Bedrock / Vertex / Foundry — check the platform's table there.

| Alias | Model | Price | Choose it for | Watch for |
|---|---|---|---|---|
| `fable` | Claude Fable 5.1 | $10 / $50 | Long-horizon autonomous work, navigating ambiguity, code review and debugging, coordinating parallel sub-agents | Single requests run many minutes at high effort; can over-plan ambiguous work; the most expensive tier, and subagents draw on the session's quota — never fan it out across many subagents |
| `opus` | Claude Opus 5.5 | $4 / $20 | The default orchestrator and reviewer: strong judgment at under half Fable's price | Thinking is always on and effort is the only control; its default is `medium`, so set effort explicitly; frontend work without named anti-patterns drifts to stock styles |
| `sonnet` | Claude Sonnet 5.5 | $2 / $10 | Multistep agentic coding in a real repository — its strongest area — at half Opus's price | Effort levels are recalibrated (start at `medium` for agentic coding); at low effort it can report a change done without running a check, so always pass the real-check instruction |
| `haiku` | Claude Haiku 5.5 | $0.10 / $0.50 (prompts ≤100K tokens; $0.50 / $2.50 beyond) | Mechanical, read-only work at a twentieth of Sonnet's price | Defaults to `medium`; at `low` in long prompts it can stop early or skip verification — keep it off writing and verification jobs |

**Cost shape.** Opus costs about 2× Sonnet, so handing a short loop to the implementer saves
less than the hand-off's context re-read costs: delegate only long, mechanical loops. Haiku
makes broad read-only scans nearly free, so spend it on readers rather than the orchestrator's
context.

## Aliases vs pinned IDs

- **Harness → tier aliases** (`fable` / `opus` / `sonnet` / `haiku`). You *want* to auto-ride
  model upgrades — that's the "rent the engine" thesis.
- **Evals → pinned model IDs** (e.g. `claude-opus-5-5`). Reproducibility is the point of a
  swap-test; a drifting alias would invalidate the comparison.

## Review horsepower — *match it to the cost of being wrong*

Whether independent review runs at all is decided by `ship_issue`'s **signal table** (S1–S11)
— one risk classifier, used for review arming, plan depth, and the operational pre-flight
alike. When it runs, it runs at `xhigh` on the session model. Auth/security (S2), migrations
(S1), LLM behavior (S4), and cross-component journeys (S9) are the cost-of-being-wrong
signals. The run can't change its own model once signals fire, so this is a launch-time
call: when the issue plainly touches several of these areas, launch `/ship_issue` on `fable`
and the orchestrator and the inherited review fork both get the top tier. Thresholds are tunable as run records accumulate
(see `design/10-harness.md`, self-pruning).

> See `design/07-build-decisions.md` and `design/09-safety-and-runtime.md` for the original
> rationale; `design/10-harness.md` for the current architecture.
