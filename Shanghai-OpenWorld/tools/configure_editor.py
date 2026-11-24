#!/usr/bin/env python3
"""Set the Java and Android paths in the workspace-local Godot editor settings."""
import json
from pathlib import Path
import re
import subprocess
import sys

base = Path(__file__).resolve().parent
version_output = subprocess.check_output([str(base / 'godot.sh'), '--version'], text=True)
version = re.search(r'(\d+\.\d+)\.\d+\.stable', version_output)
if not version:
    raise SystemExit('A stable Godot 4.x editor is required.')
target = base / 'local/xdg/config/godot' / ('editor_settings-' + version[1] + '.tres')
target.parent.mkdir(parents=True, exist_ok=True)
if target.exists():
    text = target.read_text()
else:
    text = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
for key, raw in [('export/android/android_sdk_path', sys.argv[1]), ('export/android/java_sdk_path', sys.argv[2])]:
    line = key + ' = ' + json.dumps(str(Path(raw).resolve()))
    pattern = r'^' + re.escape(key) + r' = .*?$'
    if re.search(pattern, text, re.M):
        text = re.sub(pattern, lambda _: line, text, flags=re.M)
    else:
        text = text.rstrip() + '\n' + line + '\n'
target.write_text(text)
