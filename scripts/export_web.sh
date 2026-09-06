#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p outputs/web/licenses work
./scripts/godot.sh --headless --path "$ROOT" --editor --import --quit > work/web-import.log 2>&1
./scripts/godot.sh --headless --path "$ROOT" --export-release Web outputs/web/index.html > work/web-export.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' work/web-import.log work/web-export.log; then exit 1; fi
cp web/credits.html outputs/web/credits.html
cp assets/licenses/*.md assets/licenses/*.txt outputs/web/licenses/
touch outputs/web/.nojekyll
printf 'Web export ready: outputs/web/index.html\n'
