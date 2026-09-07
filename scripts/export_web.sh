#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p outputs/web/licenses work
# Web uses an explicit resource list; fail before exporting an incomplete game.
python3 - <<'CHECK_RESOURCES'
import configparser, re
from pathlib import Path
config = configparser.ConfigParser(interpolation=None)
config.read("export_presets.cfg")
preset = next(config[section] for section in config.sections() if config[section].get("name") == '"Web"')
listed = set(re.findall(r'"(res://[^"]+)"', preset["export_files"]))
required = {"res://" + path.as_posix() for path in Path("game").rglob("*") if path.suffix in {".gd", ".gdshader", ".tscn"}}
missing = sorted(required - listed)
if missing:
    raise SystemExit("Web export missing runtime resources: " + ", ".join(missing))
CHECK_RESOURCES
uv run scripts/build_web_font.py
./scripts/godot.sh --headless --path "$ROOT" --editor --import --quit > work/web-import.log 2>&1
./scripts/godot.sh --headless --path "$ROOT" --export-release Web outputs/web/index.html > work/web-export.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' work/web-import.log work/web-export.log; then exit 1; fi
python3 scripts/finalize_web.py
cp web/credits.html outputs/web/credits.html
cp assets/licenses/*.md assets/licenses/*.txt outputs/web/licenses/
touch outputs/web/.nojekyll
printf 'Web export ready: outputs/web/index.html\n'
