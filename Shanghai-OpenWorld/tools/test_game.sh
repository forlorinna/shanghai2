#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
temp="$(mktemp -d "$root/tools/.tmp-testing-XXXXXX")"
trap 'rm -rf "$temp"' EXIT
export XDG_DATA_HOME="$temp/data"
export XDG_CONFIG_HOME="$temp/config"
export XDG_CACHE_HOME="$temp/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
bin="${GODOT_BIN:-godot}"
if ! command -v "$bin" >/dev/null && [[ -x "$root/tools/local/godot" ]]; then
    bin="$root/tools/local/godot"
fi
suite=tests/smoke.gd
if [[ "${1:-}" == --soak ]]; then suite=tests/soak.gd; fi
exec_status=0
timeout 120 "$bin" --headless --path "$root" --fixed-fps 60 --script "$suite" || exec_status=$?
exit "$exec_status"
