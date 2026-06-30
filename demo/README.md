# Running the code-review notebook

`code-review-phases-1-2.ipynb` walks through Phases 1 & 2 with live-executed cells.
It uses a Python 3 kernel; most demo cells are `%%bash`, so you need **bash + git**
on PATH (already true on Linux/macOS/WSL; on native Windows use WSL or the devcontainer).

The notebook auto-detects the repo root, so you can launch it from anywhere in the repo.

## Option A — one command (Linux / macOS / WSL)

```bash
cd demo
./run.sh        # creates demo/.venv, installs deps, opens JupyterLab
./run.sh run    # same, but executes the notebook headlessly instead
```

## Option B — VS Code devcontainer (best on Windows)

1. Install the **Dev Containers** extension.
2. Command Palette → **Dev Containers: Reopen in Container** (uses `.devcontainer/`).
3. Open `demo/code-review-phases-1-2.ipynb` and **Run All**. The Python + Jupyter
   extensions and deps are preinstalled; bash/git are present in the container.

## Option C — manual venv

```bash
python3 -m venv demo/.venv
source demo/.venv/bin/activate        # Windows PowerShell: demo\.venv\Scripts\Activate.ps1
pip install -r demo/requirements.txt
jupyter lab demo/code-review-phases-1-2.ipynb
```

## In VS Code without a container

Install the **Jupyter** + **Python** extensions, open the notebook, and select the
`demo/.venv` interpreter as the kernel. (On Windows, open the folder via **WSL** so the
`%%bash` cells work.)
