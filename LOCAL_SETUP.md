# DURGA Safety App — Local Development & Setup Guide

Complete instructions for running the backend and frontend locally, without Docker, across Android Emulators, iOS Simulators, Desktop/Web, and physical phones.

---

## Quick start (3 commands)

Prerequisites: Python 3.12+, Flutter SDK 3.x, and (optionally) PostgreSQL 16+ — SQLite is the zero-setup default.

```bash
# 1. Backend (macOS/Linux: run_local.sh, Windows: run_local.bat)
backend/run_local.sh      # creates .venv, creates .env from .env.example if missing, boots on :8000

# 2. Frontend, in a second terminal (macOS/Linux: run_frontend.sh, Windows: run_frontend.bat)
scripts/run_frontend.sh   # flutter pub get, lists devices, launches the app

# 3. Or both at once, from the repo root
./run_all.sh              # macOS/Linux
run_all.bat                # Windows
```

The backend needs zero configuration to start: `app/config.py` gives every setting a working default (SQLite, a dev `SECRET_KEY`, permissive CORS). `.env` is optional — the scripts create one from `.env.example` for you, but deleting it entirely still works.

To confirm everything actually works end-to-end (boots with no `.env`, CORS, validation, auth, timestamps, threat scoring), run the smoke test from the repo root:

```powershell
.\verify.ps1
```

---

## IDE workflows

### VS Code / Antigravity

- **`Ctrl+Shift+B`** (Cmd+Shift+B on macOS) runs **"Start Everything"** — backend and frontend launch in parallel, each in its own dedicated terminal tab.
- **`F5`** opens Run & Debug. Pick a compound to start both with real backend breakpoints:
  - `DURGA: Backend + Android App`
  - `DURGA: Backend + Web App`
  - `DURGA: Backend + Desktop App`
  - Or a single config: `Backend (FastAPI)`, `DURGA App (Android Emulator)`, `DURGA App (Chrome/Web)`, `DURGA App (Physical Phone - Change IP in args)`.
- Other tasks available via **Tasks: Run Task**: `Seed helplines`, `Reset database`, `Run backend tests`.
- Recommended extensions (prompted on open): Dart, Flutter, Python, debugpy.

### Android Studio

Three run configurations are committed under `.run/` and appear automatically on a fresh clone — no manual setup:

- **Backend (FastAPI)** — runs uvicorn with the correct working directory and interpreter.
- **Durga (Flutter)** — `flutter run` with `--dart-define=API_BASE_URL=...` for the Android emulator.
- **Backend + App** — a compound running both together.

For a physical device or a different emulator target, edit the Flutter config's "Additional run args" to match the device/URL table below.

---

## Device → URL matrix

| Target Environment | `API_BASE_URL` |
| :--- | :--- |
| **Android Emulator** | `http://10.0.2.2:8000/api/v1` *(default)* |
| **iOS Simulator** | `http://127.0.0.1:8000/api/v1` |
| **Desktop / Web** | `http://127.0.0.1:8000/api/v1` |
| **Physical Phone** | `http://<your-LAN-IP>:8000/api/v1` |

Physical phones must be on the same Wi-Fi network as your dev machine, and your machine's LAN IP must be added to `android/app/src/main/res/xml/network_security_config.xml` (see Troubleshooting below).

---

## Troubleshooting

**`CLEARTEXT communication to 10.0.2.2 not permitted`**
Android 9+ blocks plain HTTP by default. This is handled for the emulator/localhost by `android/app/src/main/res/xml/network_security_config.xml`. If you're hitting this on a physical device over your LAN, add your machine's exact IP as a `<domain>` entry in that file — Android's network security config does not support CIDR ranges like `192.168.*`, so a wildcard can't be used.

**`Connection refused` on the emulator**
Use `10.0.2.2`, not `localhost` — the Android emulator maps `10.0.2.2` to your host machine's `localhost`. `localhost` inside the emulator refers to the emulator itself.

**`ValidationError: DATABASE_URL Field required` (or `SECRET_KEY Field required`)**
This meant an old checkout without dev defaults in `app/config.py`. On current code the app boots with defaults and no `.env` at all; if you still see this, you likely have a stray `.env` with a partial/invalid value — delete it and let `run_local.sh`/`.bat` regenerate it from `.env.example`.

**`no such table`**
On SQLite (the default), tables are created automatically at startup — restart the backend. On Postgres, run `alembic upgrade head` from `backend/` (or use the "Seed helplines" task, which also calls `create_all`).

**CORS errors in the browser console**
Check `CORS_ORIGINS` in `backend/.env`. It defaults to `*` (all origins) for local dev; if you've narrowed it for testing, make sure your frontend's actual origin is included.

**Login failing after upgrading from an older checkout**
The password hashing scheme changed (SHA-256 pre-hash before bcrypt, to avoid bcrypt's 72-byte truncation bug) — old password hashes are no longer valid. Delete `backend/durga.db` (or use the "Reset database" task) and re-register.

**Other useful facts**
- `GET /health` reports real DB connectivity — `{"database": "connected"}` means the app can actually reach the database, not just that it started.
- `backend/requests.http` has a click-to-run smoke test of the whole API if you use the VS Code REST Client extension.
- `backend/API.md` documents every endpoint: method, path, auth requirement, request/response shape, status codes.
