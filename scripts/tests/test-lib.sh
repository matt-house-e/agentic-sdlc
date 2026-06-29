#!/usr/bin/env bash
# Unit tests for the pure functions in scripts/lib.sh.
# Plain bash, no bats: each test calls assert_eq and we tally failures.
set -uo pipefail  # NOTE: no -e; we want all assertions to run and report.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
. "$TEST_DIR/../lib.sh"

FAILS=0
PASSES=0

# assert_eq <expected> <actual> <message>
assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASSES=$(( PASSES + 1 ))
  else
    FAILS=$(( FAILS + 1 ))
    echo "FAIL: $msg" >&2
    echo "  expected: [$expected]" >&2
    echo "  actual:   [$actual]" >&2
  fi
}

# --- label_diff -----------------------------------------------------------
assert_eq "b" \
  "$(label_diff $'a\nb\nc' $'a\nc')" \
  "label_diff: issue [a,b,c] vs pr [a,c] -> b"

assert_eq "" \
  "$(label_diff $'a\nc' $'a\nb\nc')" \
  "label_diff: subset issue -> empty"

assert_eq "" \
  "$(label_diff '' $'a\nb')" \
  "label_diff: empty issue -> empty"

assert_eq $'a\nb' \
  "$(label_diff $'a\nb' '')" \
  "label_diff: empty pr -> all issue labels"

assert_eq $'bug\nscope: shared' \
  "$(label_diff $'bug\nscope: shared\ntype: feat' $'type: feat')" \
  "label_diff: labels with spaces preserved"

assert_eq "b" \
  "$(label_diff $'a\nb\na\nb' $'a')" \
  "label_diff: duplicates collapsed"

# --- is_review_fresh ------------------------------------------------------
if is_review_fresh "2026-06-29T12:00:00Z" "2026-06-29T11:00:00Z"; then
  PASSES=$(( PASSES + 1 ))
else
  FAILS=$(( FAILS + 1 )); echo "FAIL: is_review_fresh: newer review should be fresh" >&2
fi

if is_review_fresh "2026-06-29T10:00:00Z" "2026-06-29T11:00:00Z"; then
  FAILS=$(( FAILS + 1 )); echo "FAIL: is_review_fresh: older review should NOT be fresh" >&2
else
  PASSES=$(( PASSES + 1 ))
fi

if is_review_fresh "2026-06-29T11:00:00Z" "2026-06-29T11:00:00Z"; then
  FAILS=$(( FAILS + 1 )); echo "FAIL: is_review_fresh: equal timestamps should NOT be fresh" >&2
else
  PASSES=$(( PASSES + 1 ))
fi

if is_review_fresh "" "2026-06-29T11:00:00Z"; then
  FAILS=$(( FAILS + 1 )); echo "FAIL: is_review_fresh: empty review should NOT be fresh" >&2
else
  PASSES=$(( PASSES + 1 ))
fi

# --- parse_worktrees ------------------------------------------------------
# Sample: main + two linked (one matching naming) + one detached.
PORCELAIN="worktree /home/u/repo
HEAD aaaa1111
branch refs/heads/main

worktree /home/u/repo/.claude/worktrees/foo-wt-1
HEAD bbbb2222
branch refs/heads/feat/foo

worktree /home/u/repo/.claude/worktrees/bar-wt-2
HEAD cccc3333
branch refs/heads/fix/bar

worktree /home/u/repo/.claude/worktrees/detached-one
HEAD dddd4444
detached
"

EXPECTED=$'/home/u/repo/.claude/worktrees/foo-wt-1\tfeat/foo
/home/u/repo/.claude/worktrees/bar-wt-2\tfix/bar'

assert_eq "$EXPECTED" \
  "$(parse_worktrees "$PORCELAIN")" \
  "parse_worktrees: main skipped, detached skipped, two linked pairs"

# Single (main only) -> nothing emitted.
assert_eq "" \
  "$(parse_worktrees $'worktree /home/u/repo\nHEAD aaaa\nbranch refs/heads/main\n')" \
  "parse_worktrees: main-only -> empty"

# --- summary --------------------------------------------------------------
echo "test-lib: $PASSES passed, $FAILS failed"
[[ $FAILS -eq 0 ]]
