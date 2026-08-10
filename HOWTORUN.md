# How to Run DURGA — A Walkthrough

This is a teaching document, not a quick-reference (that's [LOCAL_SETUP.md](LOCAL_SETUP.md)). It explains *what* each piece is and *why* it exists, so you understand the moving parts instead of just copy-pasting commands.

---

## 1. The big picture

DURGA is two separate programs that talk to each other over HTTP:

```
┌─────────────────────┐        HTTP/JSON        ┌──────────────────────┐
│   Flutter frontend   │  ───────────────────▶   │   FastAPI backend    │
│   (lib/, Dart)       │  ◀───────────────────   │   (backend/app/)     │
│   runs on your phone/│      port 8000           │   runs on your dev   │
│   browser/desktop    │                          │   machine            │
└─────────────────────┘                          └──────────┬───────────┘
                                                              │
                                                              ▼
                                                    ┌──────────────────┐
                                                    │  SQLite database │
                                                    │  backend/durga.db│
                                                    └──────────────────┘
```

They are **not** one program — you must start both, in two separate terminals (or let a script/IDE do it for you). The frontend has no idea how contacts/SOS alerts/evidence are stored; it just sends HTTP requests like `POST /api/v1/sos/trigger` and renders whatever JSON comes back. The backend has no idea what a button looks like; it just validates requests, talks to the database, and returns JSON.

This is why a symptom like "the app says login failed" can have two totally different causes — a frontend bug (wrong request shape) or a backend bug (wrong validation logic) — and why `backend/API.md` (the contract between them) is worth reading if you're debugging.

---

## 2. The backend, piece by piece

### 2.1 What's actually running

```bash
cd backend
.venv\Scripts\python.exe -m uvicorn app.main:app --port 8000
```

- **`uvicorn`** is an ASGI server — a program that listens on a TCP port, accepts HTTP connections, and hands each request to your Python code. It is to FastAPI what a web server is to a website.
- **`app.main:app`** tells uvicorn: import the `app` module inside the `app` package (i.e. `backend/app/main.py`), and inside that module there's a variable named `app` — that's the actual FastAPI application object. `app/main.py:app` is the entry point.
- **`.venv`** is a *virtual environment* — an isolated copy of Python with only this project's dependencies installed (FastAPI, SQLAlchemy, etc.), so they don't collide with other Python projects or your system Python. Every `python`/`pip` command for this project should go through `.venv\Scripts\python.exe`, not your global Python.

### 2.2 What happens on startup

Reading `backend/app/main.py` top to bottom tells the whole story:

1. **Settings load** (`app/config.py`) — every config value (`DATABASE_URL`, `SECRET_KEY`, etc.) has a built-in default, so the app boots even with zero configuration. No `.env` file required.
2. **The `lifespan` function runs once at startup** — it checks the database is reachable, and if you're on SQLite, it creates all the tables (`Base.metadata.create_all()`). This is why you never have to run a migration command for local SQLite development — the app does it itself.
3. **CORS middleware is added** — without this, a browser-based frontend (or Flutter Web) would be blocked from calling the API at all. This is a browser security feature, not a bug — same-origin policy blocks any JS running on `http://localhost:xxxx` from calling `http://localhost:8000` unless the server explicitly allows it via CORS headers.
4. **Routers are mounted** — `app/api/v1/router.py` wires up `/api/v1/auth`, `/api/v1/contacts`, etc. Each router lives in `app/api/v1/endpoints/*.py`.
5. **uvicorn starts listening** on port 8000.

### 2.3 Where data lives

- **SQLite** (the default): a single file, `backend/durga.db`. No server process, no setup — it's just a file the Python `sqlite3` library reads/writes directly. Delete the file and the "database" is gone (tables get recreated empty on next boot).
- **PostgreSQL** (optional, production-realistic): a real database server. You'd set `DATABASE_URL=postgresql+psycopg://...` in `.env` and run `alembic upgrade head` to apply schema migrations. Not needed for local dev.

### 2.4 Why a `.env` file at all, if defaults exist?

Defaults make the app *bootable*, not *correctly configured*. `SECRET_KEY` defaults to an insecure placeholder (fine for dev, dangerous in production — the app refuses to start with the default if `ENV=production`). `.env` is how you override any setting without touching code. `backend/.env.example` documents every available key.

---

## 3. The frontend, piece by piece

### 3.1 What's actually running

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

- **`flutter run`** compiles the Dart code in `lib/` and launches it on a target device (`-d chrome` = your browser, `-d windows` = a native desktop window, or an Android/iOS emulator/device id).
- **`--dart-define=API_BASE_URL=...`** injects a compile-time constant. Look at `lib/services/api_client.dart` — `ApiClient.baseUrl` reads this via `String.fromEnvironment('API_BASE_URL', ...)`. This is *not* an environment variable read at runtime — it's baked into the compiled app at build time. That's why the Android emulator, iOS simulator, and a physical phone each need a different value passed at launch (see the table in LOCAL_SETUP.md) — they each reach your dev machine differently.

### 3.2 Why `10.0.2.2` and not `localhost`?

This trips up almost everyone once. An Android emulator is itself a virtual machine — inside it, `localhost` means "the emulator," not "your laptop." Google reserves the address `10.0.2.2` inside the emulator specifically to mean "the host machine's localhost." iOS simulators don't have this problem (they share the Mac's network stack directly), which is why they use plain `127.0.0.1`.

### 3.3 The service layer (how Dart talks to Python)

- `lib/services/api_client.dart` — one shared `Dio` (HTTP client) instance. Attaches the JWT token to every request automatically, via an interceptor.
- `lib/services/auth_service.dart`, `app_service.dart` — thin wrappers, one method per API endpoint. `AppService.getContacts()` just does `GET /contacts` and parses the JSON into a `Contact` object.
- `lib/models/*.dart` — plain Dart classes with a `fromJson`/`toJson` pair each, mirroring the backend's Pydantic schemas field-for-field. If the backend changes a response shape, these have to change too, or parsing breaks silently at runtime (a `null` where a `String` was expected, etc.) — this is the most common source of frontend/backend drift bugs.

---

## 4. Running both together

You genuinely need **two terminals** (or one script/IDE feature that manages two processes for you) because both `uvicorn` and `flutter run` are long-running foreground processes — neither returns control to your shell until you stop it.

| Method | What it does |
|---|---|
| `./run_all.sh` / `run_all.bat` | Starts the backend in the background, waits for `/health` to respond, then starts the frontend in the foreground. One command, one terminal. |
| VS Code `Ctrl+Shift+B` | Runs the "Start Everything" task — backend and frontend launch in parallel, each gets its own dedicated terminal tab inside VS Code. |
| VS Code `F5` → a `DURGA: Backend + ...` compound | Same idea, but through the debugger — you get real breakpoints in the Python backend. |
| Manual, two terminals | `backend/run_local.sh` (or `.bat`) in one, `scripts/run_frontend.sh` (or `.bat`) in the other. Most explicit, easiest to see what's happening. |
| Android Studio "Backend + App" run config | Same as the VS Code compound, for Android Studio users. |

---

## 5. Verifying it actually works

`verify.ps1` (repo root) is an automated smoke test: it boots the backend fresh (no `.env`, no existing database), then fires real HTTP requests at it and checks the responses — health check, CORS preflight, registration validation, login, an authenticated request, timestamp format, and the threat-scoring endpoint. Run it after any backend change to catch regressions fast, without opening the Flutter app at all:

```powershell
.\verify.ps1
```

`backend/requests.http` is the manual equivalent, for click-through exploration in VS Code's REST Client extension — useful when you want to see the actual JSON, not just pass/fail.

---

## 6. If something's broken

Read [LOCAL_SETUP.md](LOCAL_SETUP.md)'s Troubleshooting section first — it lists the exact error text for the most common failure modes (CLEARTEXT/CORS/missing table/etc.) and what each one actually means. If the error isn't there, `backend/API.md` documents the exact contract every endpoint is supposed to follow, which is usually the fastest way to tell whether a bug is on the frontend or backend side of the wire.
