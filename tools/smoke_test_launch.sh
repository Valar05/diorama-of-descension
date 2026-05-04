#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-${HOME}/bin/godot}
LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/diorama-smoke-test.XXXXXX.log")

cleanup() {
	rm -f "$LOG_FILE"
}

trap cleanup EXIT

if [ ! -x "$GODOT_BIN" ]; then
	GODOT_BIN=$(command -v godot)
fi

exec "$GODOT_BIN" \
	--headless \
	--display-driver headless \
	--audio-driver Dummy \
	--path "$ROOT_DIR" \
	--quit-after 1 \
	--log-file "$LOG_FILE"
