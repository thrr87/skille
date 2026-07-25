#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
set +e
OUTPUT="$(bash "$ROOT/scripts/install-app.sh" relative.app 2>&1)"
STATUS=$?
set -e

[[ "$STATUS" -eq 2 ]]
[[ "$OUTPUT" == *"absolute path ending in .app"* ]]
