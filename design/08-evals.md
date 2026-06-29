# 8 · Evals — how we measure "how we're doing"

> **Mine your own git history as the golden set; grade deterministically; rent the runner;
> don't build an eval platform.**

You can't measure improvement without a baseline — so the *first* eval action is to build
the control, not the pipeline.

## Two levels

**Level 1 — Outcomes (is the software good?).** Three metrics, nothing else:
**cycle time · change-fail/rework rate · escaped defects.** Ignore LoC / PR-count / %-AI
(vanity). DORA evidence: AI adoption *helps throughput but hurts stability* unless gated by
strong testing — so weight the dashboard toward **change-fail / escaped-defects**, not velocity.

**Level 2 — Pipeline behaviour (does the workflow do its job?).** A golden issue set run
after each phase, with deterministic assertions.

## Golden set — mine your own history

This is literally the **SWE-bench recipe**: a closed issue + its merged PR, where the PR
added a test that **fails before / passes after** (`FAIL_TO_PASS`). That test is your
**deterministic oracle** — no LLM judge needed.

| Source | Use for | Limit |
|---|---|---|
| **Your git history** (`FAIL_TO_PASS`) | "how we're doing" on your real distribution | needs one-time validation per case |
| **Seeded bugs** (`mutmut` / `cosmic-ray`) | reviewer catch-rate | synthetic, not real failures |
| **SWE-bench Verified / Aider polyglot** | the **model swap-test** only | contaminated/memorised — relative, not absolute |

> **Critical:** mine from the **servicedesk repos where `ship_issue` runs**, not the plugin
> repo (which has almost no history). The pipeline is evaluated *against product repos*.

## Ground truth: deterministic graders first

Anthropic's explicit order: *"deterministic graders where possible, LLM graders where
necessary, human graders judiciously."* Grade in CI (`pytest` / **Inspect AI**):
PR-opens-green · invariants hold · the **seeded violation is caught**. **No LLM judge in the
gate.** Reserve LLM-as-judge for open-ended output (PR description quality), and only after
calibrating to your own labels (≥~90% agreement). Never let the model under test grade itself.

## The single most important eval: reviewer catch-rate

The reviewer is your quality gate *and* the constitution's enforcement arm — so eval it
directly. Seed known invariant/constitution violations (`mutmut`/`cosmic-ray` for bugs;
hand-crafted diffs for convention violations) and measure **catch-rate (recall)** +
**false-positive rate (precision)**. Deterministic, no judge. This is the eval that tells
you whether *"correct me, don't just mimic me"* actually works.

## Tooling — rent, don't build

- **Inspect AI** (UK AISI, MIT, local, strong agent/tool-use support) or **DeepEval** — code-first, no lock-in.
- **Langfuse** (OSS) if you want a hosted dashboard. **Avoid** OpenAI hosted Evals (sunset 2026); Braintrust/Galileo are enterprise-heavy.
- Writing your own eval runner *is* the maintenance trap. Don't.

## Solo-scale sequence (don't over-build)

1. **Baseline now** — hand-score 3-5 recent issues through the *current* pipeline. The control.
2. **Mine ~20-50 golden cases** with their `FAIL_TO_PASS` tests; validate each once.
3. **Grade in CI** deterministically; gate on real pass/fail.
4. **Reviewer catch-rate** via seeded bugs — the highest-signal eval.
5. **Track DORA stability metrics** (change-fail, escaped defects) from git/CI.
6. **Model swap-test** on public benchmarks — relative scores only.

> Practitioner consensus: manual trace review → failure taxonomy in a spreadsheet → ~3 code
> assertions in CI → *only then* a judge or platform. Platforms adopted first become burden.
