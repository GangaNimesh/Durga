#!/bin/bash
# ==============================================================================
# DURGA Safety App - Start backend + frontend together in one terminal.
# For people not using VS Code / Android Studio's IDE run configs.
# ==============================================================================

set -e
cd "$(dirname "$0")"

echo "[+] Starting backend in the background..."
bash backend/run_local.sh &
BACKEND_PID=$!

cleanup() {
    echo ""
    echo "[+] Stopping backend (pid $BACKEND_PID)..."
    kill "$BACKEND_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "[+] Waiting for backend to come up on :8000..."
for i in $(seq 1 30); do
    if curl -s -o /dev/null -m 1 http://127.0.0.1:8000/health; then
        echo "[+] Backend is up."
        break
    fi
    sleep 1
done

echo "[+] Starting frontend..."
bash scripts/run_frontend.sh
