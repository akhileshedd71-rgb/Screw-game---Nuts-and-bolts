#!/usr/bin/env bash
set -euo pipefail
SCREWCRAFT_TOOL_ROOT="${SCREWCRAFT_TOOL_ROOT:-/workspace/.tools}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$SCREWCRAFT_TOOL_ROOT/xdg-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$SCREWCRAFT_TOOL_ROOT/xdg-config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$SCREWCRAFT_TOOL_ROOT/xdg-cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
SCREWCRAFT_GODOT="${GODOT_BIN:-$SCREWCRAFT_TOOL_ROOT/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$SCREWCRAFT_GODOT" ]]; then
  SCREWCRAFT_GODOT="$(command -v godot)"
fi
exec "$SCREWCRAFT_GODOT" "$@"
