#!/bin/bash
# ==============================================================================
# DURGA Safety App - Backend Local Startup Script (Linux / macOS)
# Runs virtual environment setup, migrations, and FastAPI uvicorn server.
# ==============================================================================

set -e

# Change directory to backend folder (where this script resides)
cd "$(dirname "$0")"

# Set PYTHONPATH so alembic and app modules resolve correctly
export PYTHONPATH=.

# ------------------------------------------------------------------------------
# Step 1: Virtual Environment Setup (Idempotent)
# Check if .venv exists. If missing, create it and install requirements.
# ------------------------------------------------------------------------------
if [ -d ".venv" ]; then
    echo "[+] Virtual environment found. Activating..."
    source .venv/bin/activate
else
    echo "[+] Virtual environment not found. Creating .venv..."
    python3 -m venv .venv
    source .venv/bin/activate
    echo "[+] Installing dependencies from requirements.txt..."
    pip install -r requirements.txt
fi

# Ensure key dependencies are available in activated environment
if ! command -v uvicorn &> /dev/null; then
    echo "[+] Installing/refreshing backend requirements..."
    pip install -r requirements.txt
fi

# ------------------------------------------------------------------------------
# Step 2: Environment Configuration (.env Check)
# FIX: this used to exit with an error if .env was missing, forcing a manual
# copy step on every teammate's first run. Auto-create it from .env.example
# instead - the app boots with dev defaults either way (see app/config.py).
# ------------------------------------------------------------------------------
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "[+] backend/.env created from .env.example."
    else
        echo "[!] No .env or .env.example found - continuing with built-in dev defaults."
    fi
else
    echo "[+] backend/.env verified."
fi

# Print the resolved DATABASE_URL with any password masked.
if [ -f ".env" ]; then
    DB_URL=$(grep -m1 '^DATABASE_URL=' .env | cut -d'=' -f2- | sed -E 's#(://[^:]+:)[^@]+(@)#\1****\2#')
fi
echo "[+] DATABASE_URL: ${DB_URL:-sqlite:///./durga.db (built-in default)}"

# ------------------------------------------------------------------------------
# Step 3: Apply schema
# Postgres: Alembic is the source of truth. SQLite: the app itself creates
# tables on startup (see app/main.py lifespan), so skip Alembic there to
# keep a fresh clone friction-free.
# ------------------------------------------------------------------------------
if echo "${DB_URL:-sqlite}" | grep -qi '^postgres'; then
    echo "[+] Postgres detected - running Alembic migrations (alembic upgrade head)..."
    if ! alembic upgrade head; then
        echo ""
        echo "[!] ERROR: Database migration / connection failed."
        echo "[!] If you don't have PostgreSQL running locally, set"
        echo "[!] DATABASE_URL=sqlite:///./durga.db in backend/.env instead."
        echo ""
        exit 1
    fi
else
    echo "[+] SQLite detected - tables are created automatically on startup, skipping Alembic."
fi

# ------------------------------------------------------------------------------
# Step 4: Start FastAPI Backend Server
# Launch uvicorn with hot-reloading on port 8000.
# ------------------------------------------------------------------------------
echo "[+] Starting FastAPI server on http://0.0.0.0:8000 ..."
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
