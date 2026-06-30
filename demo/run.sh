#!/usr/bin/env bash
# Create a local environment and run the Phase 1 & 2 code-review notebook.
#
#   ./run.sh        # set up the env and open JupyterLab on the notebook
#   ./run.sh run    # set up the env and execute the notebook headlessly
#
# Requires: python3 (3.10+), and bash + git on PATH (the notebook has %%bash
# cells). On Windows, run this inside WSL or the provided devcontainer.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
PYTHON="${PYTHON:-python3}"

if [ ! -d .venv ]; then
  echo "Creating virtualenv at demo/.venv ..."
  if ! "$PYTHON" -m venv .venv; then
    echo >&2
    echo "venv creation failed (the 'venv' module is missing)." >&2
    echo "  Debian/Ubuntu:  sudo apt install python3-venv" >&2
    echo "  …or skip local setup and use the devcontainer (.devcontainer/) in VS Code." >&2
    rm -rf .venv
    exit 1
  fi
fi
# shellcheck disable=SC1091
. .venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt

case "${1:-lab}" in
  run)
    jupyter nbconvert --to notebook --execute --inplace \
      --ExecutePreprocessor.timeout=180 code-review-phases-1-2.ipynb
    echo "Executed in place — open code-review-phases-1-2.ipynb to read it." ;;
  lab)
    echo "Launching JupyterLab — pick the .venv kernel if prompted."
    jupyter lab code-review-phases-1-2.ipynb ;;
  *)
    echo "usage: ./run.sh [lab|run]" >&2; exit 64 ;;
esac
