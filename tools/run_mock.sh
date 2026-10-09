#!/usr/bin/env bash
# Builds the bundle and runs the mocked-runtime integration test. Requires `luau` on PATH (or $LUAU).
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
python3 tools/build_mock_bundle.py
cp tests/mock_roblox.lua tests/mock_run.lua .stage/
"$LUAU" .stage/mock_run.lua
