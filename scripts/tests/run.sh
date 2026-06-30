#!/usr/bin/env bash
# Test driver: syntax-check every script, then run the lib unit tests.
set -uo pipefail  # no -e: collect every failure before reporting.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$TEST_DIR/.." && pwd)"

FAILURES=()

# 1) bash -n syntax check on all top-level scripts and the lib + tests.
for f in "$SCRIPTS_DIR"/*.sh "$TEST_DIR"/*.sh; do
  [[ -e "$f" ]] || continue
  if bash -n "$f"; then
    echo "syntax OK: $f"
  else
    FAILURES+=("syntax: $f")
  fi
done

# 2) Run the pure-function unit tests.
if bash "$TEST_DIR/test-lib.sh"; then
  echo "unit tests OK"
else
  FAILURES+=("unit: test-lib.sh")
fi

echo "----------------------------------------"
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  echo "ALL PASS"
  exit 0
fi
echo "FAILURES:"
printf '  - %s\n' "${FAILURES[@]}"
exit 1
