#!/bin/bash
# Runs the headless regression suites and prints one line per suite plus a tally.
#
#   tools/run_suite.sh                       # every default suite
#   tools/run_suite.sh milestone_5 wildlife  # a subset
#   LABEL=stage1 tools/run_suite.sh          # logs to artifacts/suite/stage1/
#
# An entry may carry scenario arguments after a colon, comma-separated:
#   phase2_launch:encounter=salmon  ->  tests/phase2_launch.gd -- encounter=salmon
# Works from any checkout or git worktree: the repository root is this script's
# parent's parent. Godot is $GODOT, else <root>/.tools/, else the main checkout's.
# A suite passes when Godot exits 0 within the timeout and logs no SCRIPT ERROR.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_NAME=Godot_v4.7.2-stable_win64_console.exe
if [ -n "$GODOT" ]; then G="$GODOT"
elif [ -x "$ROOT/.tools/$GODOT_NAME" ]; then G="$ROOT/.tools/$GODOT_NAME"
else G="/c/Users/mmurp/1848/.tools/$GODOT_NAME"; fi
if [ ! -x "$G" ]; then echo "Godot not found: $G (set GODOT)"; exit 2; fi
LABEL="${LABEL:-latest}"
LOGS="$ROOT/artifacts/suite/$LABEL"
TIMEOUT="${SUITE_TIMEOUT:-240}"
mkdir -p "$LOGS"
DEFAULT="milestone_1 milestone_2 milestone_3 milestone_4 milestone_5 milestone_6 milestone_6_notes
milestone_7 milestone_8 milestone_9_models milestone_9 camp_layout camp_movement fishing_tension
fishery_pressure fishing_assets fishing_launch milestone_10_models milestone_10 milestone_11_models
milestone_11 simulate_tools expedition_models milestone_12 milestone_13 milestone_14
miner_game miner_art wildlife crew_models photo_mode v2_flow
phase2_launch:encounter=salmon phase2_launch:encounter=raid phase2_launch:encounter=deer
phase2_launch:encounter=bear phase2_launch:day=132"
if [ $# -gt 0 ]; then SUITES="$*"; else SUITES="$DEFAULT"; fi
cd "$ROOT" || exit 2
passed=0; failed=0; failed_names=""; total_start=$(date +%s)
for entry in $SUITES; do
  name="${entry%%:*}"; args=()
  if [ "$entry" != "$name" ]; then IFS=',' read -r -a args <<< "${entry#*:}"; fi
  log_name="$(echo "$entry" | tr ':,=' '-_-')"
  log="$LOGS/$log_name.log"
  start=$(date +%s)
  if [ ${#args[@]} -gt 0 ]; then
    timeout "$TIMEOUT" "$G" --headless --fixed-fps 60 --path . --script "tests/$name.gd" -- "${args[@]}" > "$log" 2>&1
  else
    timeout "$TIMEOUT" "$G" --headless --fixed-fps 60 --path . --script "tests/$name.gd" > "$log" 2>&1
  fi
  code=$?
  if [ $code -eq 0 ] && ! grep -q "SCRIPT ERROR" "$log"; then status=PASS; passed=$((passed+1))
  else status=FAIL; failed=$((failed+1)); failed_names="$failed_names $entry"; fi
  [ $code -eq 124 ] && note="(timeout ${TIMEOUT}s) " || note=""
  echo "$status $entry exit=$code $(( $(date +%s)-start ))s $note:: $(grep -E 'PASS|FAIL|failures|SCRIPT ERROR' "$log" | head -3 | tr '\n' ' ' | cut -c1-200)"
done
echo "SUITES: $passed passed, $failed failed of $((passed+failed)) in $(( $(date +%s)-total_start ))s; logs in artifacts/suite/$LABEL/"
[ $failed -gt 0 ] && echo "FAILED:$failed_names"
[ $failed -eq 0 ]
