#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p outputs work
./scripts/verify.sh
./scripts/godot.sh --headless --path "$ROOT" --export-release macOS outputs/REDLINE-v0.5.zip > work/export.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' work/export.log; then
  exit 1
fi
ditto -x -k outputs/REDLINE-v0.5.zip outputs/macos
printf 'Local macOS app exported to outputs/macos\n'
