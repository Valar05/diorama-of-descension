#!/bin/sh
set -e
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
exec godot --headless --path "$PROJECT_DIR" --scene res://tools/parry_bounce_test.tscn --quit
