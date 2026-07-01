#!/usr/bin/env bash
# Remove worktrees whose branch has a merged PR (post-merge cleanup).
# WHY: a branch being gone from origin isn't a reliable "safe to delete" signal --
# it's indistinguishable from a branch that was simply never pushed. Ask GitHub
# directly whether a MERGED PR exists for the branch name instead: that's correct
# regardless of merge strategy (squash rewrites the SHA; merge/rebase don't) and
# regardless of whether delete_branch_on_merge already removed the ref.
# We reap only worktrees automation itself creates: ship_issue's own `*-wt-*`
# fallback, and the harness's `.claude/worktrees/*` (EnterWorktree) -- never a
# human's own manually-named worktree.
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

# is_plugin_worktree <path> -- true only for worktrees automation itself creates.
is_plugin_worktree() {
  local path="$1" base
  case "$path" in
    */.claude/worktrees/*) return 0 ;;
  esac
  base="$(basename "$path")"
  case "$base" in
    *-wt-*) return 0 ;;
  esac
  return 1
}

# merged_pr_head_sha <branch> -- prints the head commit SHA GitHub actually
# merged for this branch name (empty if no merged PR exists). A gh failure
# (auth/network/no such repo) must NOT be read as "found" -- `|| true` only
# swallows the "no merged PR" case (empty jq result), not a real command error,
# because that would already print nothing on stdout either way; the caller
# treats empty output as "leave it alone" regardless of why it's empty.
merged_pr_head_sha() {
  local branch="$1"
  gh pr list --head "$branch" --state merged --json headRefOid --jq '.[0].headRefOid // empty' 2>/dev/null || true
}

removed=0
kept=0
diverged=0

# parse_worktrees skips the main worktree and detached entries for us.
while IFS=$'\t' read -r path branch; do
  [[ -n "$path" ]] || continue

  if ! is_plugin_worktree "$path"; then
    kept=$(( kept + 1 )); continue
  fi

  merged_sha="$(merged_pr_head_sha "$branch")"
  if [[ -z "$merged_sha" ]]; then
    kept=$(( kept + 1 )); continue
  fi

  # Only force-delete the branch if its tip is EXACTLY what GitHub merged --
  # otherwise there are commits here (e.g. typed after the PR merged) that
  # exist nowhere else, and `git branch -D` would destroy them. The worktree
  # checkout itself is never unique data, so it's always safe to remove.
  local_sha="$(git rev-parse "$branch" 2>/dev/null || true)"
  if [[ -n "$local_sha" && "$local_sha" != "$merged_sha" ]]; then
    echo "warn: '$branch' has a merged PR but its local tip differs from what merged -- keeping the branch, removing only the worktree" >&2
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "WOULD remove worktree only (keep branch, diverged): $path"
    else
      git worktree remove "$path" || echo "warn: failed to remove $path" >&2
    fi
    diverged=$(( diverged + 1 ))
    continue
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "WOULD remove: $path (branch $branch, merged PR confirmed, tip matches)"
  else
    echo "removing: $path (branch $branch, merged PR confirmed, tip matches)"
    git worktree remove "$path" || echo "warn: failed to remove $path" >&2
    git branch -D "$branch" >/dev/null 2>&1 || true
  fi
  removed=$(( removed + 1 ))
done < <(parse_worktrees "$(git worktree list --porcelain)")

echo "summary: removed=$removed diverged=$diverged kept=$kept$([[ $DRY_RUN -eq 1 ]] && echo ' (dry-run)')"
exit 0
