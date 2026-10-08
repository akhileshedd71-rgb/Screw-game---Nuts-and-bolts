#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DISPLAY:-}" ]]; then
  echo 'Set DISPLAY to an available X11 display for actual rendered captures.' >&2
  exit 2
fi
capture_profile=$(mktemp -d /tmp/screwcraft-capture-XXXXXXXX)
export XDG_DATA_HOME="$capture_profile/data"
export XDG_CONFIG_HOME="$capture_profile/config"
export XDG_CACHE_HOME="$capture_profile/cache"
mkdir -p builds/reports/redesign
touch builds/.gdignore
./tools/godot.sh --headless --editor --path . --import > builds/reports/redesign/import.log 2>&1
sizes=(720x1280 360x800 768x1024)
if [[ -n "${1:-}" ]]; then
  sizes=("$1")
fi
for capture_size in "${sizes[@]}"; do
	export XDG_DATA_HOME="$capture_profile/$capture_size/data"
	export XDG_CONFIG_HOME="$capture_profile/$capture_size/config"
	export XDG_CACHE_HOME="$capture_profile/$capture_size/cache"
  timeout 120 ./tools/godot.sh --path . --display-driver x11 --audio-driver Dummy \
    --script tools/capture_redesign.gd -- --size="$capture_size" \
    > "builds/reports/redesign/capture-$capture_size.log" 2>&1
  if rg -q 'SCRIPT ERROR|^ERROR:|Assertion failed' "builds/reports/redesign/capture-$capture_size.log"; then
    cat "builds/reports/redesign/capture-$capture_size.log" >&2
    exit 1
  fi
  tail -n 1 "builds/reports/redesign/capture-$capture_size.log"
done
