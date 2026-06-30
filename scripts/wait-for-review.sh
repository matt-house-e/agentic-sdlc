#!/usr/bin/env bash
# Block until a PR review is submitted strictly newer than the latest commit.
# WHY: GitHub's workflow_run events carry the head_sha of the run, not the
# review, so polling workflow runs by SHA races with new pushes. Polling the
# reviews list directly and comparing timestamps is the reliable signal.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
  echo "usage: $(basename "$0") <pr-number> [timeout-seconds]" >&2
}

[[ $# -ge 1 && $# -le 2 ]] || { usage; exit 64; }
PR="$1"
TIMEOUT="${2:-600}"
[[ "$PR" =~ ^[0-9]+$ && "$TIMEOUT" =~ ^[0-9]+$ ]] || { usage; exit 64; }

POLL_INTERVAL=30

deadline=$(( $(date +%s) + TIMEOUT ))
while :; do
  # Latest review submission time and latest commit time, "" if absent.
  review_ts="$(gh pr view "$PR" --json reviews \
    --jq 'if (.reviews | length) > 0 then .reviews[-1].submittedAt else "" end')"
  commit_ts="$(gh pr view "$PR" --json commits \
    --jq 'if (.commits | length) > 0 then .commits[-1].commit.committedDate else "" end')"

  if is_review_fresh "$review_ts" "$commit_ts"; then
    gh pr view "$PR" --json reviewDecision --jq '.reviewDecision'
    exit 0
  fi

  # Stop polling once we'd sleep past the deadline.
  (( $(date +%s) + POLL_INTERVAL <= deadline )) || break
  sleep "$POLL_INTERVAL"
done

echo "TIMEOUT" >&2
exit 2
