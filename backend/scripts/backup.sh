#!/usr/bin/env bash
set -e

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BACKEND_DIR"

if [ -f "venv/bin/python" ]; then
    PYTHON_BIN="venv/bin/python"
else
    PYTHON_BIN="python3"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting SAPAR database backup..."
$PYTHON_BIN -m scripts.backup_db "$@"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup finished."
