---
description: Port a merged scope:shared PR from one servicedesk repo to its sibling — apply the diff, resolve conflicts, open a mirror PR
accepts_args: true
argument-hint: <source-pr-number> [<source-owner>/<source-repo>]
---

Port the merged source PR #$ARGUMENTS into the sibling repo as a new mirror PR.

`$ARGUMENTS` is either `<source-pr-number>` or `<source-pr-number> <source-owner>/<source-repo>`.
Parse them now: first token is the PR number, second (optional) is the explicit source repo.

This command is repo-agnostic — it detects source/sibling at runtime. Run it from
the **sibling** working directory (the repo the port lands in). If the source
repo isn't explicitly given, the command resolves it from `.agentic-sdlc/config.json`
or falls back to a built-in mapping for the two known servicedesks.

---

## 0. Resolve source and sibling repos

```bash
# Sibling = cwd repo (where the port lands)
SIBLING_OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
SIBLING_SHORT=$(basename "$(git rev-parse --show-toplevel)")
```

**Resolve source repo:**

1. **Explicit (second arg)** → use it directly.

2. **Config file** → read `.agentic-sdlc/config.json` if it exists:
   ```json
   { "sibling": "LucaNet-Main/ai-servicedesk", "scope_default": "scope:hr-only" }
   ```
   The `sibling` value in the *current* (sibling) repo's config points at the *source*.

3. **Built-in fallback** — known servicedesks:
   - `ai-servicedesk` ↔ `hr-servicedesk` (same owner)

If none of these resolve, stop and ask the user for the source repo.

```bash
SOURCE_OWNER_REPO="<resolved-source>"     # e.g. LucaNet-Main/ai-servicedesk
SOURCE_SHORT=$(basename "$SOURCE_OWNER_REPO")
PR=$ARGUMENTS                              # first token only
```

---

## 1. Validate the source PR

```bash
gh pr view "$PR" --repo "$SOURCE_OWNER_REPO" \
  --json number,title,body,state,mergedAt,mergeCommit,labels,baseRefName,headRefName,url
```

Required state:
- **`state == MERGED`** — porting unmerged PRs is risky (the diff can still change). If `OPEN`, warn and ask the user to confirm before continuing.
- **Label `scope:shared` present** — if missing, warn: *"Source PR is not labelled `scope:shared`. Continue anyway?"* Don't auto-port unlabelled changes.

Capture the source PR's metadata into shell variables for later steps:
- `SOURCE_TITLE`, `SOURCE_BODY`, `SOURCE_MERGE_SHA`, `SOURCE_LABELS`, `SOURCE_URL`

---

## 2. Fetch the diff

```bash
mkdir -p "$CLAUDE_JOB_DIR"
gh pr diff "$PR" --repo "$SOURCE_OWNER_REPO" --patch > "$CLAUDE_JOB_DIR/source-${SOURCE_SHORT}-${PR}.patch"
```

`--patch` produces a `git-am`-compatible mailbox-style patch with author metadata. Save it for `git apply --3way` (and as evidence in the Done report).

Quick sanity check:
- Diff is non-empty
- Diff isn't dominated by paths that don't exist in the sibling (e.g. `app/it_only/...`) — if it is, this PR probably wasn't truly `scope:shared`; surface that and pause for the user.

---

## 3. Worktree setup in the sibling

```bash
git fetch origin main

# Branch name encodes the source PR for traceability
SLUG=$(echo "$SOURCE_TITLE" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40)

BRANCH="port/${SOURCE_SHORT}-${PR}-${SLUG}"
WT="../${SIBLING_SHORT}-wt-port-${PR}"

git worktree add "$WT" -b "$BRANCH" origin/main
cd "$WT"
```

All remaining work happens inside `$WT`. Switch to it now and stay there.

---

## 4. Apply the patch

Try `--3way` first — it succeeds whenever the surrounding context is recognisable, even if line numbers drifted:

```bash
git apply --3way --whitespace=fix "$CLAUDE_JOB_DIR/source-${SOURCE_SHORT}-${PR}.patch"
```

**If `--3way` succeeds with no conflicts** → skip to step 6.

**If `--3way` fails or leaves conflicts** → fall back to `--reject` so failing hunks land as `.rej` files you can read and port semantically:

```bash
git apply --reject --whitespace=fix "$CLAUDE_JOB_DIR/source-${SOURCE_SHORT}-${PR}.patch" || true
git status --short
find . -name '*.rej' -not -path './.git/*'
```

---

## 5. Resolve conflicts (agent reasoning)

For each `.rej` file or `UU` conflict:

1. **Read both sides.** Open the source-repo file at the merge SHA via `gh api`:
   ```bash
   gh api "repos/${SOURCE_OWNER_REPO}/contents/<path>?ref=${SOURCE_MERGE_SHA}" --jq .content | base64 -d
   ```
   …and the sibling-repo current file at the same path.

2. **Understand the intent.** What did the source change *mean to do*? Apply that intent to the sibling, not the literal text.

3. **Translate domain tokens — narrowly.** The two servicedesks differ in surface vocabulary; never rewrite logic, only contextual strings:
   - Repo names in paths/comments/log strings (`ai-servicedesk` ↔ `hr-servicedesk`)
   - Domain labels in UI copy (`IT support` ↔ `HR support`) — only where the source change *is* domain copy; never invent translations.
   - Brand spelling: **always `Lucanet` with lowercase `n`** — never `LucaNet` even if the source PR has a typo (fix it).

4. **Don't paper over real divergence.** If a source-PR change references a file or function that genuinely doesn't exist in the sibling (e.g. it relies on a service that only lives in IT), stop and surface this to the user — the PR may not actually be `scope:shared`, or it needs a precursor port first.

5. **Delete `.rej` files after resolution.**
   ```bash
   find . -name '*.rej' -not -path './.git/*' -delete
   ```

---

## 6. Verify

Run the sibling repo's lint + tests:

```bash
make check        # or the repo's documented equivalent
make test         # or the repo's documented equivalent
```

In a worktree, prefix Python tests with `PYTHONPATH=$PWD` if the parent shell exports one — same gotcha as `ship_issue` step 7.

If a relevant eval framework exists (`test -d evals/`) and the source PR touched agent-observable behavior, run the matching scenarios. Don't run the full eval suite.

Fix any failures. The port is not done if the sibling is red.

---

## 7. Commit

Single squash-style commit (the port is one logical unit, even if the source had many commits):

```bash
git add -A
git commit -m "$(cat <<EOF
${SOURCE_TITLE} (ports #${PR})

Ports ${SOURCE_OWNER_REPO}#${PR}.

Source PR: ${SOURCE_URL}
Source merge SHA: ${SOURCE_MERGE_SHA}

[2-3 line summary of what landed and any sibling-specific adjustments
 made during conflict resolution — paths translated, tokens swapped, etc.]
EOF
)"
```

Do **not** add `Closes #X` — the issue (if any) lives in the source repo.

---

## 8. Open the mirror PR

```bash
git push -u origin "$BRANCH"

# Build label list:
# - Always: scope:shared (this is a port; future humans need to see that)
# - Always: ai-tool: claude-code, ai-workflow: ai-authored
# - Carry over any type:* / priority:* / component:* from the source PR if the
#   sibling repo has identically-named labels (check `gh label list` first)

gh pr create \
  --title "${SOURCE_TITLE} (ports #${PR})" \
  --base main \
  --label "scope:shared,ai-tool: claude-code,ai-workflow: ai-authored,<carried-over>" \
  --body "$(cat <<EOF
## Summary

Mirrors ${SOURCE_OWNER_REPO}#${PR}.

**Source PR:** ${SOURCE_URL}
**Source merge SHA:** \`${SOURCE_MERGE_SHA}\`

## What changed

[2-3 bullets summarising the source PR's effect, in this repo's language]

## Port notes

[Anything non-trivial about applying the diff to the sibling — conflicts
resolved, paths translated, tokens swapped. Empty if it applied cleanly.]

## Checklist

- [x] Source PR is merged and labelled \`scope:shared\`
- [x] Diff applied (\`git apply --3way\` or rejection-resolved)
- [x] Lint passes
- [x] Tests pass
- [x] Domain tokens translated where contextually appropriate
- [x] Mirrored intent, not just the literal diff

EOF
)"
```

**Verify labels landed** the same way `ship_issue` does — `gh pr create --label` silently no-ops on missing labels:

```bash
gh pr view <pr-number> --json labels --jq '.labels[].name'
```

Add any missing labels with `gh pr edit <pr-number> --add-label`.

---

## 9. Enable auto-merge

Same as `ship_issue` step 13:

```bash
gh pr merge <pr-number> --auto --squash --delete-branch
```

This works with `REVIEW_REQUIRED` branch protection — the PR sits in auto-merge until the reviewer workflow approves it.

---

## 10. Done

Report:
- Mirror PR URL
- Source PR URL (`${SOURCE_URL}`)
- Apply mode used (`--3way clean` / `--3way with conflicts resolved` / `--reject + manual`)
- Files where domain tokens were translated (if any)
- Auto-merge state (enabled / blocked with reason)
- Worktree path (`$WT`) — stays until the PR merges
- Any sibling-specific follow-ups discovered during the port (e.g. "sibling lacks `service X`; this port relies on it being added separately")

After the mirror PR merges:

```bash
git worktree remove "$WT"
git branch -d "$BRANCH"
```

---

## When to bail

- **Source PR isn't `scope:shared`** — confirm with user before porting; the absence of the label is itself a signal
- **Source PR isn't merged** — the source diff can still change; either wait for merge or accept the risk with the user
- **>50% of hunks reject and require manual reasoning** — the PR isn't really shared; ask the user to split it into a port-friendly piece and a domain-specific piece
- **Patch references files that don't exist in the sibling and aren't trivially renameable** — there's an unstated dependency; surface it

---

## Future: auto-dispatch on merge

A GitHub Action on the source repo (`on: pull_request: types: [closed]`,
filter `merged == true && contains(labels.*.name, 'scope:shared')`) can
`workflow_dispatch` a port-pr job in the sibling repo. This needs a PAT with
cross-repo workflow permissions and a Claude API key in sibling-repo secrets.
Not wired in this version — run `/port-pr <N>` on demand from the sibling
worktree.
