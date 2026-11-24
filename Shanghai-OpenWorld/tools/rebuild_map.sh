#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export PYTHONPATH="$root/tools/local${PYTHONPATH:+:$PYTHONPATH}"
python3 tools/generate_map.py "$@"
tools/godot.sh --headless --script tools/bake_map.gd
