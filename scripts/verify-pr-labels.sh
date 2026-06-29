#!/usr/bin/env bash
# Guarantee every label on the source issue is also on the PR.
# WHY: `gh pr create --label X` silently no-ops when a label doesn't yet exist
# at create time, so labels can go missing. This re-reconciles after the fact.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
  echo "usage: $(basename "$0") <pr-number> <issue-number>" >&2
}

[[ $# -eq 2 ]] || { usage; exit 64; }
PR="$1"
ISSUE="$2"
[[ "$PR" =~ ^[0-9]+$ && "$ISSUE" =~ ^[0-9]+$ ]] || { usage; exit 64; }

# AI-attribution labels that may not exist in every repo; add only if present.
AI_LABELS=("ai-tool: claude-code" "ai-workflow: ai-authored")
STRAY_LABEL="ai-workflow: human-authored"

# label_exists <name> -- true if the repo defines this label.
# Capture-then-match (no pipe into grep) so pipefail can't misread a SIGPIPE on gh as "absent".
label_exists() {
  local name="$1" found
  found="$(gh label list --search "$name" --json name --jq '.[].name' 2>/dev/null || true)"
  grep -Fxq -- "$name" <<< "$found"
}

# Newline-separated label names for an issue or PR.
issue_labels() { gh issue view "$ISSUE" --json labels --jq '.labels[].name'; }
pr_labels()    { gh pr view "$PR" --json labels --jq '.labels[].name'; }

issue_set="$(issue_labels)"
pr_set="$(pr_labels)"

# Reconcile every issue label that's missing on the PR.
missing="$(label_diff "$issue_set" "$pr_set" || true)"
if [[ -n "$missing" ]]; then
  while IFS= read -r label; do
    [[ -n "$label" ]] || continue
    gh pr edit "$PR" --add-label "$label" \
      || echo "warn: failed to add label '$label'" >&2
  done <<< "$missing"
fi

# Add AI-attribution labels only when the repo actually has them.
for label in "${AI_LABELS[@]}"; do
  if label_exists "$label"; then
    gh pr edit "$PR" --add-label "$label" \
      || echo "warn: failed to add AI label '$label'" >&2
  fi
done

# Best-effort: drop the stray human-authored label if it slipped on.
gh pr edit "$PR" --remove-label "$STRAY_LABEL" >/dev/null 2>&1 || true

# Re-verify against the (possibly grown) issue label set.
pr_set="$(pr_labels)"
still_missing="$(label_diff "$issue_set" "$pr_set" || true)"
if [[ -n "$still_missing" ]]; then
  echo "still missing labels on PR #$PR:" >&2
  printf '%s\n' "$still_missing" >&2
  exit 1
fi

echo "all issue labels present on PR #$PR"
exit 0
