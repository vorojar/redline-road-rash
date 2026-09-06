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
run_checked work/verify-steering-comfort.log --headless --path "$ROOT" --script res://tests/steering_comfort.gd
cat work/verify-steering-comfort.log
run_checked work/verify-road-follow.log --headless --path "$ROOT" --script res://tests/road_follow.gd
cat work/verify-road-follow.log
run_checked work/verify-arcade-cornering.log --headless --path "$ROOT" --script res://tests/arcade_cornering.gd
cat work/verify-arcade-cornering.log
run_checked work/verify-duel.log --headless --path "$ROOT" --script res://tests/duel_pacing.gd
cat work/verify-duel.log
run_checked work/verify-combat-pack.log --headless --path "$ROOT" --script res://tests/combat_pack.gd
cat work/verify-combat-pack.log
run_checked work/verify-combat-personality.log --headless --path "$ROOT" --script res://tests/combat_personality.gd
cat work/verify-combat-personality.log
run_checked work/verify-mouse-combat.log --headless --path "$ROOT" --script res://tests/mouse_combat.gd
cat work/verify-mouse-combat.log
run_checked work/verify-engine-voice.log --headless --path "$ROOT" --script res://tests/engine_voice.gd
cat work/verify-engine-voice.log
run_checked work/verify-finish-presentation.log --headless --path "$ROOT" --script res://tests/finish_presentation.gd
cat work/verify-finish-presentation.log
run_checked work/verify-touch.log --headless --path "$ROOT" --script res://tests/touch_controls.gd
cat work/verify-touch.log
run_checked work/verify-pine.log --headless --path "$ROOT" --script res://tests/drive_soak.gd --fixed-fps 60
rg 'SOAK_FINISH FINISH' work/verify-pine.log
run_checked work/verify-coast.log --headless --path "$ROOT" --script res://tests/drive_soak.gd --fixed-fps 60 -- --coast
rg 'SOAK_FINISH FINISH' work/verify-coast.log
