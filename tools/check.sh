#!/usr/bin/env bash
# One-shot quality gate. Needs the Luau CLI tools (luau, luau-compile) on PATH or in $LUAU_DIR.
#   LUAU_DIR=/path/to/luau-release ./tools/check.sh
# Optional: API_DUMP=/path/to/API-Dump.json enables the Roblox property-name check.
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU_DIR="${LUAU_DIR:-}"
luau_bin() { if [ -n "$LUAU_DIR" ]; then echo "$LUAU_DIR/$1"; else command -v "$1"; fi; }
LUAU="$(luau_bin luau)"; COMPILE="$(luau_bin luau-compile)"

echo "== syntax (luau-compile)"
for f in $(find src tests tools -name '*.lua'); do
  "$COMPILE" --text "$f" > /dev/null || { echo "syntax error in $f"; exit 1; }
done
echo ok

echo "== unit tests (pure Engine / formulas / config validation)"
python3 tools/stage_tests.py > /dev/null
"$LUAU" .stage/test_all.lua | tail -2

echo "== balance simulation (greedy bot)"
"$LUAU" .stage/sim.lua | grep -E "rebirth available|^end" || true

echo "== integration run on mocked Roblox runtime"
LUAU="$LUAU" tools/run_mock.sh | tail -3

if [ -n "${API_DUMP:-}" ]; then
  echo "== Roblox property names"
  python3 tools/check_props.py "$API_DUMP"
fi
