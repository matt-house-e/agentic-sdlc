#!/usr/bin/env bash
# Shared pure-logic library for the plugin's worktree/PR helper scripts.
# Everything here is string/list processing only: NO gh/git/network calls,
# so the plain-bash test harness can exercise these functions directly.
set -euo pipefail

# label_diff <listA> <listB>
# Prints lines present in listA but not in listB.
# Both args are newline-separated lists; order/duplicates don't matter.
# WHY comm -23: it's the simplest correct set-difference, but it REQUIRES
# sorted input, so we sort -u both sides here rather than trusting callers.
label_diff() {
  local a="${1:-}" b="${2:-}"
  comm -23 \
    <(printf '%s\n' "$a" | grep -v '^$' | sort -u) \
    <(printf '%s\n' "$b" | grep -v '^$' | sort -u)
}

# is_review_fresh <reviewTimestamp> <commitTimestamp>
# Returns 0 (truthy) if the review is strictly newer than the commit.
# WHY string compare: ISO-8601 / RFC-3339 timestamps in the same zone sort
# lexicographically == chronologically, so [[ a > b ]] is correct and avoids
# any date(1) parsing.
is_review_fresh() {
  local review="${1:-}" commit="${2:-}"
  # Empty review means "no review yet" -> never fresh.
  [[ -n "$review" ]] || return 1
  [[ "$review" > "$commit" ]]
}

# parse_worktrees <porcelain-text>
# Reads `git worktree list --porcelain` text on the first arg (or stdin) and
# emits "path<TAB>branch" lines. Skips the FIRST entry (the main worktree) and
# any detached-HEAD entries, since we only ever prune named, branch-backed
# linked worktrees.
parse_worktrees() {
  local input
  if [[ $# -gt 0 ]]; then
    input="$1"
  else
    input="$(cat)"
  fi

  local path="" branch="" detached=0 first=1
  # Porcelain emits a blank line between worktree records; flush on blank/EOF.
  _flush() {
    if [[ -n "$path" ]]; then
      if [[ $first -eq 1 ]]; then
        first=0  # drop the main worktree (always listed first)
      elif [[ $detached -eq 0 && -n "$branch" ]]; then
        printf '%s\t%s\n' "$path" "$branch"
      fi
    fi
    path="" branch="" detached=0
  }

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "worktree "*) path="${line#worktree }" ;;
      "branch "*)
        # Normalize refs/heads/foo -> foo
        branch="${line#branch }"
        branch="${branch#refs/heads/}"
        ;;
      "detached") detached=1 ;;
      "") _flush ;;
    esac
  done <<< "$input"
  _flush  # final record may not be followed by a blank line
  unset -f _flush
}
