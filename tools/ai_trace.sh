#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-${HOME}/bin/godot}

if [ ! -x "$GODOT_BIN" ]; then
	GODOT_BIN=$(command -v godot)
fi

exec "$GODOT_BIN" \
	--headless \
	--display-driver headless \
	--audio-driver Dummy \
	--path "$ROOT_DIR" \
	-- \
	--ai-trace \
	--ai-trace-frames="${AI_TRACE_FRAMES:-180}" \
	--ai-trace-sample-every="${AI_TRACE_SAMPLE_EVERY:-1}" \
	--ai-trace-extra-enemies="${AI_TRACE_EXTRA_ENEMIES:-6}" \
	--ai-trace-fail-on-multi-attackers="${AI_TRACE_FAIL_ON_MULTI_ATTACKERS:-1}"
