#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Isolate QA profile state from the player's working profile.
export XDG_DATA_HOME="${SCREWCRAFT_TEST_DATA:-/tmp/screwcraft-tests-data}"
export XDG_CONFIG_HOME="${SCREWCRAFT_TEST_CONFIG:-/tmp/screwcraft-tests-config}"
export XDG_CACHE_HOME="${SCREWCRAFT_TEST_CACHE:-/tmp/screwcraft-tests-cache}"
mkdir -p builds/reports
touch builds/.gdignore
./tools/godot.sh --headless --editor --path . --import
./tools/godot.sh --headless --path . --script tests/test_reducer.gd
timeout 120 ./tools/godot.sh --headless --path . --script tests/test_persistence.gd
timeout 120 ./tools/godot.sh --headless --path . --script tests/test_fuzz.gd
timeout 120 ./tools/godot.sh --headless --path . --script tests/test_audio.gd
timeout 120 ./tools/godot.sh --headless --path . --script tests/test_board.gd
timeout 120 ./tools/godot.sh --headless --path . --script tests/test_ui.gd
python3 tools/validate_geometry.py
python3 tests/test_geometry_mutations.py
