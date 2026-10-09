#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
DATA="$ROOT/.codespace-data"

mkdir -p "$DATA"

if curl -fsS --max-time 2 http://127.0.0.1:8080/health >/dev/null 2>&1; then
  exit 0
fi

cd "$APP"
export ADDR=":8080"
export DATA_PATH="$DATA/notes.json"
export SEED_PATH="$APP/seed.json"

nohup go run . > "$DATA/quicknotes.log" 2>&1 < /dev/null &
