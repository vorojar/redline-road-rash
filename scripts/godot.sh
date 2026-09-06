#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$ROOT/.tools/Godot.app/Contents/MacOS/Godot" ]]; then
  exec "$ROOT/.tools/Godot.app/Contents/MacOS/Godot" "$@"
elif command -v godot >/dev/null 2>&1; then
  exec godot "$@"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot "$@"
else
  echo 'Godot 4 未找到。请从 https://godotengine.org/download/macos/ 下载，或放入 .tools/Godot.app。' >&2
  exit 1
fi
