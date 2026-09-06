#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p outputs/web/licenses work
./scripts/godot.sh --headless --path "$ROOT" --editor --import --quit > work/web-import.log 2>&1
./scripts/godot.sh --headless --path "$ROOT" --export-release Web outputs/web/index.html > work/web-export.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' work/web-import.log work/web-export.log; then exit 1; fi
# Content-address the pack so a cached desktop-only build cannot survive a new page.
python3 - <<'PYTHON'
import hashlib, json, re
from pathlib import Path
root = Path("outputs/web")
pack = root / "index.pck"
name = "redline-" + hashlib.sha256(pack.read_bytes()).hexdigest()[:16] + ".pck"
pack.replace(root / name)
page = root / "index.html"
html = page.read_text()
match = re.search(r"const config=(\{[^\n]+\});", html)
if match is None:
    raise SystemExit("Godot config not found in exported HTML")
config = json.loads(match.group(1))
config["mainPack"] = name
config["fileSizes"][name] = config["fileSizes"].pop("index.pck")
page.write_text(html[:match.start()] + "const config=" + json.dumps(config, separators=(",", ":")) + ";" + html[match.end():])
for previous in root.glob("redline-*.pck"):
    if re.fullmatch(r"redline-[a-f0-9]{16}\.pck", previous.name) and previous.name != name:
        previous.unlink()
print("Game pack:", name)
PYTHON
cp web/credits.html outputs/web/credits.html
cp assets/licenses/*.md assets/licenses/*.txt outputs/web/licenses/
touch outputs/web/.nojekyll
printf 'Web export ready: outputs/web/index.html\n'
