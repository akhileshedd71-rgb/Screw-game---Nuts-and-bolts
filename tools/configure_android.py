#!/usr/bin/env python3
"""Set non-secret local debug-export paths without running an editor SceneTree."""
import json
import os
from pathlib import Path
import re

root = Path(os.environ.get('SCREWCRAFT_TOOL_ROOT', '/workspace/.tools'))
config = Path(os.environ.get('XDG_CONFIG_HOME', str(root / 'xdg-config'))) / 'godot' / 'editor_settings-4.7.tres'
config.parent.mkdir(parents=True, exist_ok=True)
text = config.read_text() if config.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
sdk = os.environ.get('ANDROID_HOME', str(root / 'android-sdk'))
settings = {
    'export/android/android_sdk_path': sdk,
    'export/android/java_sdk_path': os.environ.get('JAVA_HOME', '/usr/lib/jvm/java-21-openjdk-amd64'),
    'export/android/debug_keystore': str(Path(sdk) / 'debug.keystore'),
    'export/android/debug_keystore_user': 'androiddebugkey',
    'export/android/debug_keystore_pass': 'android',
}
for key, value in settings.items():
    line = key + ' = ' + json.dumps(value)
    pattern = '^' + re.escape(key) + r' = .*'
    text = re.sub(pattern, line, text, flags=re.MULTILINE) if re.search(pattern, text, re.MULTILINE) else text + line + '\n'
config.write_text(text)
print('Configured local Android SDK, Java, and standard debug-signing paths.')
