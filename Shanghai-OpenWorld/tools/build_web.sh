#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mkdir -p builds/web
tools/godot.sh --headless --editor --import
tools/godot.sh --headless --export-release Web "$root/builds/web/index.html"
python3 tools/finalize_web.py
(cd builds/web && zip -q -9 "$root/builds/Shanghai-OpenWorld-v0.1.0-web.zip" index.*)
unzip -tq "$root/builds/Shanghai-OpenWorld-v0.1.0-web.zip"
