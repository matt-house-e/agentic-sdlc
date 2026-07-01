# Vendored: ce-debug

This skill is **vendored** (copied in, pinned to a fixed version) — not a live dependency.
We own no diagnosis logic here; we rent it. Debugging is a commodity step, and the upstream
plugin ships ~daily (73 releases in ~3 months), so we take one frozen copy instead of tracking it.

## Source & pin

| Field | Value |
|---|---|
| Upstream | [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) |
| Skill | `skills/ce-debug/` |
| Pinned tag | `compound-engineering-v3.16.0` |
| Pinned commit | `3157993648fc5822e120b6beb542ada15ebdc656` (2026-06-30) |
| License | MIT — see below |

## What we took vs dropped

**Vendored verbatim** (the rented knowledge — do not edit; re-pull from upstream to update):
- `references/anti-patterns.md`
- `references/defense-in-depth.md`
- `references/investigation-techniques.md`

**Dropped** (upstream-specific infra / coupling we don't use):
- `references/repo-profile-cache.md`, `references/agents/repo-profiler.md`, `scripts/repo-profile-cache.py`
  — the profile-cache machinery. Replaced with reading the testing conventions inline from `AGENTS.md`/`CLAUDE.md`.
- Sibling-skill calls `/ce-commit-push-pr`, `/ce-commit`, `/ce-compound`, `/ce-brainstorm` (and a
  negative reference to the heavier `/ce-code-review`, replaced with the harness's `/review`).

## Adaptations to `SKILL.md` (why it differs from upstream)

- **Two modes** added: interactive (human `/ce-debug`) keeps the blocking question gates;
  non-interactive (the `/ship_issue` pipeline) substitutes our **proceed-by-default, park-by-exception**
  rule and never asks. Matches our three-surfaces model (debug = interactive surface).
- **No branch/worktree creation** — removed upstream's `git checkout -b`; isolation is the harness's job.
- **No profile cache** — read testing conventions inline from the knowledge home.
- **Handoff re-pointed** — drops upstream's commit/PR/compound tail; hands the fix to our `create_pr` /
  `ship_issue`, and routes any generalizable lesson to the `ship_issue` `learn` phase (the compounding
  loop with the admission bar) rather than writing rules itself.
- **"Rethink the design"** (`/ce-brainstorm`) → surfaced as a **design-problem park** to the human.
- **Fix governed by the host's gates** — a fix is only done when the project's deterministic gates
  (the `verify` phase) are green; this skill gets no special path to ship.

## To update the pin

Re-pull `SKILL.md` + the three `references/*.md` from a newer upstream tag, then re-apply the
adaptations above. Bump the tag/commit in this file.

## License (MIT)

```
MIT License

Copyright (c) 2025 Every

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
