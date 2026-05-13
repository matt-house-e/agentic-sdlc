---
description: Create a pull request following project conventions, with correct labels and a closes-link to the issue
accepts_args: true
argument-hint: <issue-number-or-url> [extra context]
---

Create a pull request that follows this repo's GitHub conventions (read `CLAUDE.md` and `docs/development/github-standards.md` if present).

## Input

`$ARGUMENTS` should include:
- Issue number or URL the PR closes (required)
- Optional extra context about the implementation

If `$ARGUMENTS` is empty, infer the issue number from the branch name (e.g. `task/472-foo` → `#472`) or from commit messages. Confirm with the user before continuing if ambiguous.

**Every PR must close its issue.** The branch name almost always contains the issue number — include `Closes #<issue-number>` in the PR body. When updating an existing PR, verify the closure link is present and add it if missing.

---

## 1. Prerequisites

Verify before creating the PR:

1. **On a feature branch**, not `main`:
   ```bash
   git branch --show-current
   ```

2. **No uncommitted changes**:
   ```bash
   git status
   ```

3. **Branch pushed to origin**:
   ```bash
   git push -u origin "$(git branch --show-current)"
   ```

4. **Lint + tests green** (run if not already done in this session). Use the repo's documented commands — typically `make check` + `make test` for Python/uv repos, otherwise the equivalent in `CLAUDE.md` (`uv run ruff …`, `npm run lint`, `pytest`, etc.).

If any check fails, fix it before opening the PR — don't open a PR with a red baseline.

---

## 2. Commit-type / scope from labels

Read the source issue's labels:

```bash
gh issue view <issue-number> --json labels --jq '.labels[].name'
```

Map `type:*` → commit type:

| Issue label | Commit type |
|---|---|
| `type:story` | `feat` |
| `type:task` | `chore` (or `refactor` / `perf` / `test` if more specific) |
| `type:bug` | `fix` |
| `type:spike` | `spike` |
| `type:epic` | `feat` |

Map `component:*` → scope. Use whichever component label the repo actually has — `component:ci` and `component:ci-cd` are both valid; don't invent. Common mappings:

| Component label | Scope |
|---|---|
| `component:workflow` | `(workflow)` |
| `component:llm` | `(llm)` |
| `component:ui` | `(ui)` |
| `component:api` | `(api)` |
| `component:service` | `(service)` |
| `component:data` / `component:database` | `(data)` / `(database)` |
| `component:testing` | `(test)` |
| `component:docs` | `(docs)` |
| `component:config` | `(config)` |
| `component:ci` / `component:ci-cd` | `(ci)` |
| `component:infra` | `(infra)` |

Final title format:

```
<type>(<scope>): <description> (#<issue-number>)
```

Example: `fix(service): pre-validate reporter before submitting (#258)`.

Keep titles under 70 characters. Body carries the detail.

---

## 3. Labels to apply

**Required labels on every AI-authored PR:**

1. Every `type:*`, `priority:*`, `component:*` label that's on the source issue — copy verbatim.
2. `ai-tool: claude-code`
3. `ai-workflow: ai-authored`

Build and pass them at PR-creation time:

```bash
ISSUE_LABELS=$(gh issue view <issue-number> --json labels --jq '[.labels[].name] | join(",")')
AI_LABELS="ai-tool: claude-code,ai-workflow: ai-authored"
PR_LABELS="${ISSUE_LABELS},${AI_LABELS}"
```

`gh pr create --label` silently no-ops on labels the repo doesn't have — verify after creation with `gh pr view <pr> --json labels`.

If the repo auto-applied `ai-workflow: human-authored` from an org-level workflow, remove it:

```bash
gh pr edit <pr-number> --remove-label "ai-workflow: human-authored" 2>/dev/null || true
```

---

## 4. Create the PR

```bash
gh pr create \
  --title "<type>(<scope>): <description> (#<issue-number>)" \
  --label "$PR_LABELS" \
  --body "$(cat <<'EOF'
## Summary
[1-2 sentences: what this PR does and why]

## Changes
- [Change 1]
- [Change 2]

## Testing
[How this was verified — lint / tests / evals / manual]

## Checklist
- [ ] Lint passes
- [ ] Tests pass
- [ ] Relevant evals pass — or skip-rationale documented
- [ ] Labels copied from source issue + `ai-tool: claude-code` + `ai-workflow: ai-authored`
- [ ] Self-reviewed
- [ ] ADR created if architectural decision made
- [ ] `CLAUDE.md` updated if architecture changed

Closes #<issue-number>
EOF
)"
```

If the PR is based on a non-`main` branch (stacked PR), add `--base <base-branch>` so the diff only shows this PR's commits.

---

## 5. Verify labels landed

```bash
gh pr view <pr-number> --json labels --jq '.labels[].name'
```

The output must include every label from `$ISSUE_LABELS` plus `ai-tool: claude-code` and `ai-workflow: ai-authored`. If anything is missing, add it with `gh pr edit <pr> --add-label "<name>"` before continuing. Downstream dashboards and auto-reviewers depend on these.

---

## Title examples

- `feat(workflow): add ticket preview before submission (#314)`
- `fix(service): correct reporter validation order (#258)`
- `chore(ci): pin claude-code-action SHA (#465)`
- `docs(invariants): forbid plain dicts for structured data`
- `refactor(llm): consolidate prompt construction helpers`

## Don't

- Don't open a PR without `Closes #<issue>` — every PR closes its issue
- Don't open a PR with red lint or tests — fix first
- Don't skip the AI-attribution labels — dashboards depend on them
- Don't invent labels — use the ones the repo already has (`gh label list`)
- Don't squash the commits into one before opening the PR — let GitHub squash on merge; the per-task commits are the implementation log
