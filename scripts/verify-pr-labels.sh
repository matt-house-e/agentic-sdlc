#!/usr/bin/env bash
# Guarantee every label on the source issue is also on the PR.
# WHY: `gh pr create --label X` aborts PR creation entirely if X doesn't exist
# in the repo, so create_pr/SKILL.md never passes --label at create time.
# This applies (and reconciles) every label after the fact instead.
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
