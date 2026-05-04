#!/bin/sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
exec godot --headless --path "$PROJECT_DIR" --scene res://tools/enemy_facing_test.tscn --quit
