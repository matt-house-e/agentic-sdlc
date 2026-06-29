# 5 · Evidence

> The research behind the claims. Skim the bold lines; follow links to verify.
> 8 agents across 2 rounds; source-strength caveats at the end.

## Standards are real and converging (bet on them)

- **AGENTS.md** is the de-facto memory standard — read natively by Codex, Cursor, Gemini
  CLI, Copilot, Windsurf, Zed, Aider, Amp, Devin (~24 agents, "60k+ repos"). Donated to
  the **Linux Foundation Agentic AI Foundation (AAIF)**, Dec 2025.
- **MCP** won tool integration — Anthropic (Nov 2024) → OpenAI (Mar 2025), Google (Apr
  2025), Microsoft. 5,800+ servers by Apr 2025. Also AAIF-governed.
- **SKILL.md** — Anthropic open-sourced the spec **Dec 18 2025**; VS Code + OpenAI/Codex
  shipped support within 48h; ~32 tools now. A directory + YAML + Markdown.
- **Proprietary layers:** slash commands, subagent dispatch (Claude-only), hooks (config).
  → [agents.md](https://agents.md/) · [AAIF donation](https://www.anthropic.com/news/donating-the-model-context-protocol-and-establishing-of-the-agentic-ai-foundation) · [Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) · [Willison on Skills](https://simonwillison.net/2025/Dec/19/agent-skills/)

## Models: abstract the role, not the model

- **Prompts are the deepest coupling.** OpenAI told devs GPT-5.5 is *not* a drop-in and to
  rebuild prompts from scratch; "Model Drifting" (arXiv 2512.01420) measures the degradation.
- **APIs diverge structurally:** tool-call schemas, structured output (Claude had no native
  json_schema as of Apr 2026 — coerce via tool-use), reasoning knobs, 3 different caching
  products. **MCP is the one stabilising force.**
- **Price of fixed capability falls ~10×/yr** (Epoch), up to 280× over 18mo (Stanford AI
  Index) — swapping *toward cheaper* is routine; design for it.
  → [Model swap guide](https://www.truefoundry.com/blog/litellm-vs-openrouter) · [GPT-5.5 prompts](https://the-decoder.com/openai-says-old-prompts-are-holding-gpt-5-5-back-and-developers-need-a-fresh-baseline/) · [structured output](https://www.glukhov.org/post/2025/10/structured-output-comparison-popular-llm-providers)

## Specs as durable artifacts — but keep it minimal

- **Anthropic's 2026 Agentic Coding Trends report:** *"specs replace prompts as durable,
  executable artifacts"* — strongest vendor signal that durability lives in artifacts.
- **But the ceremony is a trap:** Martin Fowler's site (Böckeler, Oct 2025) warns SDD risks
  "inflexibility *and* non-determinism"; ThoughtWorks Radar = **Assess, not Adopt**; one
  critique measured **~10× slower** (2,577 lines md → 689 LOC). **Spec rot** is named.
- **Anthropic CLAUDE.md guidance:** keep < ~200 lines; "would removing this cause a
  mistake? if not, cut it." Bloat → ignored rules.

## The learning loop must correct via friction, not override

- Compound-engineering's retrieval agent hard-codes: *"never let a past learning silently
  override present evidence… flag the conflict."* → constitution = **justify-or-deviate**.
- It has **no constitution** (grepped, zero hits) — the overruling-authority idea is novel
  *and* contradicted by their deliberate design. Taste-vs-best-practice lives at *review
  time* (advisory) there, not baked into enforced storage.
- Steal their **5-outcome refresh** (Keep/Update/Consolidate/Replace/Delete; age≠stale;
  contradiction=replace) and an **admission bar** as the anti-bloat budget.

## Proven vs fashionable (best-practice round)

| Proven (adopt) | Fashionable / overreaching at solo scale |
|---|---|
| Verification-as-spec ("give it a check it can run") | Multi-agent orchestration *for coding* |
| Plan-then-execute (skip for 1-line diffs) | "2 engineers ship like 15" (no baseline) |
| Fresh-context review (scoped to gaps) | Heavyweight spec doc-sets |
| Sub-agents for *context isolation* | Frameworks over direct API calls |
| Lean memory, skills on demand | — |

- **Don't Build Multi-Agents** (Cognition, Jun 2025); Anthropic's pro-multi-agent paper
  **excludes coding** and notes **~15× tokens**; the 90.2% win is a *research* eval.
- **DORA 2024/2025:** AI is an *amplifier* — throughput up, **stability still negative**
  without strong testing/version-control. Measure four-keys + rework + escaped defects.
- **METR Jul 2025:** devs 19% slower while *feeling* 20% faster — **Feb 2026 update walks
  it back** (−4%, wide CIs). Cite both; treat as contested.
  → [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) · [Designing agentic loops (Willison)](https://simonwillison.net/2025/Sep/30/designing-agentic-loops/) · [DORA 2025](https://dora.dev/)

## Build-vs-buy: augment, don't replace

- Adopt **only `ce-debug`** (real gap, zero overlap); optionally brainstorm/ideate as
  disposable. **Keep** `ship_issue` / `port-pr` / `code-simplifier`.
- `ce-simplify-code` duplicates your `code-simplifier` (same 3 lenses); `ce-work`/`lfg`
  compete with `ship_issue`. Irrelevant: test-xcode/browser, riffrec, proof, product-pulse.
- **73 releases in ~3 months** (≈1/day) → don't add a live dependency; **vendor pinned**
  (MIT). Your 587-line `ship_issue` is the high-maintenance asset — fine, it's your moat.

## Source-strength caveats

- Anthropic's coding-workflow practices are **internally validated, not benchmarked**.
- Multi-agent hard numbers are **research-domain only** — don't import to coding.
- METR headline is **contested**; GitClear/Stanford churn figures vary in rigour.
- Standards-adoption counts are **vendor/community-reported**, trending fast.

→ Full per-agent reports are in the session transcript if you want to go deeper on any thread.
