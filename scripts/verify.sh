#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p work outputs
run_checked() {
  local report="$1"
  shift
  ./scripts/godot.sh "$@" > "$report" 2>&1
  if rg -n 'SCRIPT ERROR|ERROR:|FAIL:' "$report"; then
    cat "$report"
    return 1
  fi
}
run_checked work/verify-import.log --headless --path "$ROOT" --editor --import --quit
run_checked work/verify-rules.log --headless --path "$ROOT" --script res://tests/test_race.gd
cat work/verify-rules.log
run_checked work/verify-core.log --headless --path "$ROOT" --script res://tests/core_v03.gd --fixed-fps 60
cat work/verify-core.log
run_checked work/verify-garage-burst.log --headless --path "$ROOT" --script res://tests/garage_burst.gd
cat work/verify-garage-burst.log
run_checked work/verify-boost-regression.log --headless --path "$ROOT" --script res://tests/boost_regression.gd
cat work/verify-boost-regression.log
run_checked work/verify-experience.log --headless --path "$ROOT" --script res://tests/experience_v05.gd
cat work/verify-experience.log
run_checked work/verify-arcade-cornering.log --headless --path "$ROOT" --script res://tests/arcade_cornering.gd
cat work/verify-arcade-cornering.log
run_checked work/verify-duel.log --headless --path "$ROOT" --script res://tests/duel_pacing.gd
cat work/verify-duel.log
run_checked work/verify-touch.log --headless --path "$ROOT" --script res://tests/touch_controls.gd
cat work/verify-touch.log
run_checked work/verify-pine.log --headless --path "$ROOT" --script res://tests/drive_soak.gd --fixed-fps 60
rg 'SOAK_FINISH FINISH' work/verify-pine.log
run_checked work/verify-coast.log --headless --path "$ROOT" --script res://tests/drive_soak.gd --fixed-fps 60 -- --coast
rg 'SOAK_FINISH FINISH' work/verify-coast.log
