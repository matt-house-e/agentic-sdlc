---
description: Create a git branch from a GitHub issue, with the right type prefix and a derived slug
accepts_args: true
argument-hint: <issue-number>
---

Create a git branch for issue #$ARGUMENTS.

## 1. Fetch the issue

```bash
gh issue view $ARGUMENTS --json number,title,labels
```

## 2. Parse the type

From the issue's `type:*` label, map to a branch prefix:

| Issue label | Branch prefix |
|---|---|
| `type:epic` | `epic/` |
| `type:story` | `feat/` |
| `type:task` | `task/` |
| `type:bug` | `fix/` |
| `type:spike` | `spike/` |
| (no `type:*` label) | `feat/` (default) |

These match Conventional Commits and the `gh pr create` defaults across the repos. If a repo's history uses different prefixes (e.g. `feature/` instead of `feat/`), match what `git for-each-ref --format='%(refname:short)' refs/remotes/origin/` shows — consistency with existing history beats this default.

## 3. Derive the slug

From the title:
- Strip the `[Type]: [Component]` prefix if present
- Lowercase
- Replace whitespace and special chars with `-`
- Collapse multiple `-` into one
- Trim to ~40 characters

## 4. Pre-checkout safety

```bash
# Confirm clean state
git status
# Ensure main is current
git checkout main
git pull origin main
```

If you're already on main with no local changes, the checkout is a no-op. If you're on a feature branch, decide whether to stash / commit before switching — don't lose work.

## 5. Create the branch

```bash
git checkout -b <type>/<issue-number>-<slug>
```

Examples:

- `feat/45-add-file-upload`
- `fix/89-conversation-node-crash`
- `task/67-refactor-llm-service`
- `spike/123-investigate-rate-limits`
- `epic/200-multi-tenancy-rollout`

## 6. Confirm

Report:
- The branch name created
- The full issue title for reference
- Current branch: `git branch --show-current`
- Suggested next step: *"Ready to ship? Run `/ship_issue $ARGUMENTS` to go end-to-end."*

## Don't

- Don't include `[Type]:` or `[Component]` brackets in the branch name
- Don't include special characters
- Don't keep the description too long (~40 chars max)
- Don't branch from a stale `main` — pull first
