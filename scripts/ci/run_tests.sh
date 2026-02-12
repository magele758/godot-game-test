#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_PATH="${PROJECT_PATH:-.}"

if ! command -v "${GODOT_BIN}" >/dev/null 2>&1; then
  if command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN="godot4"
  else
    echo "Godot binary not found. Set GODOT_BIN or install godot/godot4." >&2
    exit 1
  fi
fi

echo "Running headless test suite..."
"${GODOT_BIN}" --headless --path "${PROJECT_PATH}" --script res://tests/test_runner.gd
