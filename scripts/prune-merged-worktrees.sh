#!/usr/bin/env bash
# Remove worktrees whose branch no longer exists on origin (post-merge cleanup).
# WHY: after a PR merges, GitHub deletes the remote branch; the local worktree
# and branch linger. We reap only the plugin's own *-wt-* worktrees.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
  echo "usage: $(basename "$0") [--dry-run]" >&2
}

DRY_RUN=0
case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  "") ;;
  *) usage; exit 64 ;;
esac

removed=0
kept=0

# parse_worktrees skips the main worktree and detached entries for us.
while IFS=$'\t' read -r path branch; do
  [[ -n "$path" ]] || continue

  # Safety: only ever touch the plugin's named worktrees.
  base="$(basename "$path")"
  case "$base" in
    *-wt-*) ;;
    *) kept=$(( kept + 1 )); continue ;;
  esac

  # Branch still on origin? Keep it. Only a clean "no matching ref" (exit 2) means the
  # branch is gone; a network/other failure (128) must NOT trigger deletion.
  ls_status=0
  git ls-remote --exit-code origin "$branch" >/dev/null 2>&1 || ls_status=$?
  if [[ $ls_status -eq 0 ]]; then
    kept=$(( kept + 1 )); continue            # branch still on origin
  elif [[ $ls_status -ne 2 ]]; then
    echo "warn: ls-remote failed (status $ls_status) for '$branch'; skipping" >&2
    kept=$(( kept + 1 )); continue            # network/other error — never delete on this
  fi
  # exit 2 → branch genuinely gone from origin → reap below

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "WOULD remove: $path (branch $branch)"
  else
    echo "removing: $path (branch $branch)"
    git worktree remove "$path" || echo "warn: failed to remove $path" >&2
    git branch -D "$branch" >/dev/null 2>&1 || true
  fi
  removed=$(( removed + 1 ))
done < <(parse_worktrees "$(git worktree list --porcelain)")

echo "summary: removed=$removed kept=$kept$([[ $DRY_RUN -eq 1 ]] && echo ' (dry-run)')"
exit 0
