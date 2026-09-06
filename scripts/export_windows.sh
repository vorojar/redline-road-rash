#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p outputs/windows work
./scripts/godot.sh --headless --path "$ROOT" --editor --import --quit > work/windows-import.log 2>&1
./scripts/godot.sh --headless --path "$ROOT" --export-release 'Windows Desktop' outputs/windows/REDLINE.exe > work/windows-export.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' work/windows-import.log work/windows-export.log; then exit 1; fi
python3 scripts/package_windows.py
