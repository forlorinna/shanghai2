#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export XDG_DATA_HOME="$root/tools/local/xdg/data"
export XDG_CONFIG_HOME="$root/tools/local/xdg/config"
export XDG_CACHE_HOME="$root/tools/local/xdg/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
bin="${GODOT_BIN:-godot}"
if ! command -v "$bin" >/dev/null && [[ -x "$root/tools/local/godot" ]]; then
    bin="$root/tools/local/godot"
fi
exec "$bin" --path "$root" "$@"
