#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p builds/linux builds/web builds/android builds/reports
touch builds/.gdignore
./tools/godot.sh --headless --editor --path . --import
./tools/godot.sh --headless --path . --export-release Linux builds/linux/Screwcraft.x86_64
./tools/godot.sh --headless --path . --export-release Web builds/web/index.html
if [[ "${1:-}" == "--android" ]]; then
  SDK_PATH="${ANDROID_HOME:-${SCREWCRAFT_TOOL_ROOT:-/workspace/.tools}/android-sdk}"
  if [[ ! -f "$SDK_PATH/debug.keystore" ]]; then
    keytool -genkeypair -keystore "$SDK_PATH/debug.keystore" -storepass android -alias androiddebugkey -keypass android -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
  fi
  python3 tools/configure_android.py
  ./tools/godot.sh --headless --path . --export-debug Android builds/android/Screwcraft-debug.apk
  "$SDK_PATH/build-tools/36.0.0/apksigner" verify builds/android/Screwcraft-debug.apk
fi

python3 tools/package_builds.py
