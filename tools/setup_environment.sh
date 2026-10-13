#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$project_root/tools/install_luau.sh"

# Reuse the runner's valid package. Only install into a task-owned venv if needed.
if ! python3 -c 'import zstandard; assert zstandard.__version__ == "0.25.0"' >/dev/null 2>&1; then
    rbxl_python_root="/workspace/.spy-tools/rbxl-python"
    if [[ ! -e "$rbxl_python_root" ]]; then
        python3 -m venv "$rbxl_python_root"
        touch "$rbxl_python_root/.spyclub-managed"
    fi
    [[ -f "$rbxl_python_root/.spyclub-managed" ]] || {
        printf 'Existing Python environment is not managed by SPY CLUB; preserved.\n' >&2
        exit 1
    }
    "$rbxl_python_root/bin/python3" -m pip install --disable-pip-version-check --no-input --no-cache-dir \
        --require-hashes -r "$project_root/requirements-rbxl.txt"
    "$rbxl_python_root/bin/python3" -c 'import zstandard; assert zstandard.__version__ == "0.25.0"'
    printf 'For place tooling, prepend %s/bin to PATH.\n' "$rbxl_python_root"
fi
python3 -m py_compile "$project_root/tools/rbxl_tool.py" \
    "$project_root/tools/build_places.py" "$project_root/tools/validate.py"
printf 'SPY CLUB headless editing, compilation and place tooling prepared.\n'
