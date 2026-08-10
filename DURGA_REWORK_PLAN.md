# DURGA — Backend Rework & "Make It Actually Run" Implementation Plan

**Repo:** `https://github.com/yaadhuu/Durga-Women-Safety-App`
**Stack:** Flutter (Dart) frontend · FastAPI (Python 3.12) backend · SQLAlchemy 2.0 + Alembic · SQLite (dev) / PostgreSQL (prod) · JWT auth
**Audience:** Claude Code / Antigravity agent executing this plan
**Scope:** Backend, database, API integration, and developer tooling. **Do not redesign frontend UI/visuals.** Frontend changes are limited to the service/model layer, Android config, and anything that is currently a compile error.

---

## 0. How to use this document

This is an execution brief, not a discussion. Work through the phases **in order**. Each phase has a **Definition of Done** — verify it before moving on.

Every finding below was **empirically verified** against a running instance of the server (installed deps, ran migrations, booted uvicorn, hit endpoints with curl). Findings marked ✅ VERIFIED were reproduced with an actual HTTP response. Findings marked ⚠️ INSPECTION were found by reading code and are near-certain but not runtime-reproduced.

**Ground rules for the agent:**

1. Work on a branch: `git checkout -b rework/backend-and-runnability`
2. Commit at the end of every phase with the phase name in the message.
3. Do not "improve" things not listed here. Scope discipline matters — this is a graded capstone with a defined proposal.
4. When a fix changes API shape, update the Flutter service layer in the same commit so the two never drift.
5. Add a short `# FIX:` comment above non-obvious changes explaining what was broken. The team has to defend this code in a review.
6. Preserve existing behaviour where the plan does not say otherwise.

---

## 1. Current state — what's actually wrong

### 1.1 The three bugs that stop anything from working at all

These are why "everything is getting messed up." Fix these first; nothing else matters until they're done.

| # | Bug | Effect |
|---|---|---|
| **A** | `lib/services/app_service.dart` line 2 imports `'app_models.dart'`, but the file lives at `lib/models/app_models.dart` | **Dart compile error.** The app does not build. |
| **B** | `app_service.dart` calls `ApiClient.instance` in 6 places, but `ApiClient` has no static `instance` member — only a `factory ApiClient()` and a *private* `static ApiClient? _instance` | **Dart compile error**, 6 occurrences. |
| **C** | `pubspec.yaml` declares assets `assets/images/` and `assets/icons/`; **neither directory exists in the repo** | `flutter run` fails at asset resolution before the app ever starts. |

**Any one of these alone means `flutter run` cannot succeed.** All three are present simultaneously. The backend is comparatively healthy — the frontend has never compiled against it.

### 1.2 Android runtime blockers (app builds, then immediately fails to reach the API)

| # | Bug | Effect |
|---|---|---|
| **D** | `android/app/src/main/AndroidManifest.xml` has **no `INTERNET` permission**. It exists only in `src/debug/AndroidManifest.xml` | Debug builds work; **release builds have no network at all**. |
| **E** | No `usesCleartextTraffic` / network security config. Target API is modern; cleartext HTTP is blocked by default since Android 9 | Every call to `http://10.0.2.2:8000` fails with `CLEARTEXT communication to 10.0.2.2 not permitted`. **This is the classic "backend is running but app says connection failed."** |
| **F** | No `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `CAMERA`, `RECORD_AUDIO` declared, despite `geolocator`, `image_picker`, `permission_handler` in `pubspec.yaml` | Location and evidence capture fail at runtime. |
| **G** | `google_maps_flutter` is a dependency but there is no `com.google.android.geo.API_KEY` meta-data in the manifest | Map renders blank/grey. |

### 1.3 Backend defects — ✅ VERIFIED at runtime

| # | Bug | Evidence |
|---|---|---|
| **H** | **No `.env` → hard crash at import time.** `config.py` declares `DATABASE_URL` and `SECRET_KEY` with no defaults; `database.py` calls `get_settings()` at module scope | `pydantic_core.ValidationError: 2 validation errors for Settings` before uvicorn can start. Fresh clone = instant crash. |
| **I** | **No CORS middleware anywhere.** `main.py` never adds `CORSMiddleware` | `OPTIONS /api/v1/auth/login` → `405 Method Not Allowed`. No `Access-Control-Allow-Origin` header on any response. **Flutter Web, Chrome, and any browser client are completely blocked.** |
| **J** | **`GET /sos/last` returns HTTP 500** for any user with no active alert. Handler returns `None` but `response_model=SOSAlertResponse` is non-optional → `ResponseValidationError` | Reproduced: fresh account, no SOS ever triggered → `500 Internal Server Error`. Every new user hits this on first home-screen load. |
| **K** | **Invalid emails register successfully.** `EmailStr` is imported in `schemas/auth.py` but never used — `email` is a plain `str`. `email-validator` is not in `requirements.txt` | `POST /auth/register` with `"email": "totally-not-an-email"` → **HTTP 201 Created**. |
| **L** | **Trailing-slash 307 redirects.** `contacts` and `helplines` register routes as `"/"` only | `GET /api/v1/contacts` → `307` to `.../contacts/`. Harmless on curl; **fatal on Flutter Web** — browsers refuse redirects during CORS preflight. |
| **M** | **Partial updates impossible.** `ContactUpdate(ContactBase)` inherits required fields, so `exclude_unset=True` in the handler is dead code | `PUT /contacts/{id}` with `{"name":"Mummy"}` → `422 Field required: phone`. |
| **N** | **Datetimes have no UTC offset.** Response: `"created_at":"2026-08-09T21:30:15.720701"` | Dart's `DateTime.parse()` treats offset-less strings as **local time**. Every timestamp is wrong by the device's UTC offset — **5h30m in IST**. For a safety app, SOS timestamps being 5.5 hours off is a serious defect. |
| **O** | **Evidence upload accepts anything, any size.** No content-type allowlist, no size cap, empty file accepted | Uploaded a zero-byte file with a blank filename → `201 Created`, stored as `application/octet-stream`. Any authenticated user can fill the disk. |
| **P** | **`/threat/analyze` requires no auth and mis-scores ordinary text.** Logic: keyword hit → High; empty string → Low; **everything else → Medium** | `{"text":"hi"}` → `Medium Risk / orange`. "on my way home" would show an orange warning. Also unauthenticated. |

### 1.4 Backend defects — ⚠️ INSPECTION

| # | Bug |
|---|---|
| **Q** | `create_engine()` has no `connect_args={"check_same_thread": False}`. Sync `def` endpoints run in FastAPI's threadpool → SQLite will raise *"objects created in a thread can only be used in that same thread"* under concurrency. |
| **R** | SQLite ignores `ON DELETE CASCADE` unless `PRAGMA foreign_keys=ON` is set per connection. Models declare `ondelete="CASCADE"` — **it silently does nothing**. Deleting a user orphans their contacts, SOS alerts, journeys, evidence. |
| **S** | bcrypt **silently truncates input at 72 bytes**, but `RegisterRequest.password` allows `max_length=128`. Two different long passwords can unlock the same account. |
| **T** | `requirements.txt` declares `passlib[bcrypt]` — **never imported anywhere**. `security.py` uses `bcrypt` directly (which is only present transitively). passlib 1.7.4 + bcrypt ≥4 also emits a noisy `module 'bcrypt' has no attribute '__about__'` error on startup. |
| **U** | `HTTPBearer()` with default `auto_error=True` returns **403** when the `Authorization` header is missing entirely (should be **401**), and no response carries the RFC 6750 `WWW-Authenticate` header. Client-side "am I logged out?" logic can't distinguish states. |
| **V** | **Login user-enumeration timing leak.** On unknown email, `verify_password` is never called → response returns in ~1 ms instead of ~250 ms. Trivially harvestable. No rate limiting either. |
| **W** | **`helplines` table is dead schema.** The model and the Alembic migration both create it; the endpoint returns a hardcoded Python list and never queries the DB. |
| **X** | **SOS alerts are never resolved.** `is_active` is set `True` on create and there is no endpoint to clear it → `/sos/last` returns the user's *first ever* alert forever. No history endpoint either. |
| **Y** | **Journeys can overlap without limit.** No check for an existing active journey; no `GET /journey/active` and no list endpoint, so the app cannot restore trip state after being killed — which defeats the purpose of journey monitoring. |
| **Z** | **Evidence is write-only.** No list, no download, no delete. Uploaded files are unreachable. `file_path` also stores the full server path and returns it to the client (information leak). |
| **AA** | `os.makedirs(UPLOAD_DIR)` runs at **import time** against a **relative** path → upload location depends on the shell's cwd. Running uvicorn from repo root vs `backend/` puts files in different folders, and DB rows point at paths that no longer resolve. |
| **AB** | `os.path.splitext(file.filename)` raises `TypeError` when `filename` is `None` (browsers and some Dio `MultipartFile` calls send none). |
| **AC** | `app/models/__init__.py` is an empty comment. Harmless today, but **breaks `Base.metadata.create_all()`** — SQLAlchemy only knows about imported models, so it would silently create zero tables. |
| **AD** | No global exception handler → unhandled errors return the bare string `Internal Server Error`, not JSON. Dio's response parsing chokes on it. |
| **AE** | `app/api/deps.py` is a one-line re-export, so `get_db` is imported from two different module paths across the codebase. |
| **AF** | `/health` doesn't check the database — reports `ok` even when the DB is unreachable. |

### 1.5 Tooling defects — why "run both together" doesn't work

| # | Bug |
|---|---|
| **AG** | `.vscode/tasks.json` → **"Start Everything" hangs forever.** It uses `"dependsOrder": "sequence"` with a backend task that is `isBackground: true` and never exits. VS Code waits for a sequenced task to *complete*, so **the frontend task never launches**. Must be `"parallel"`. |
| **AH** | `.vscode/launch.json` has **no Python/FastAPI configuration at all** and **no `compounds`** — you can never debug the backend from VS Code, and cannot start both with one keypress. |
| **AI** | `backend/run_local.sh` and `.bat` **exit with an error if `.env` is missing** instead of just creating it from `.env.example`. First-run friction for every team member. |
| **AJ** | `scripts/run_frontend.sh` calls `flutter run -d "$DEVICE_ID" "$EXTRA_ARGS"` — passing an empty `EXTRA_ARGS` as a literal empty argument. Fragile. |
| **AK** | No Android Studio run configurations (`.run/*.xml`) committed, so Android Studio users get no backend integration. |
| **AL** | `modules` — a **0-byte junk file** at repo root. Delete it. |
| **AM** | `backend/run_api_tests.py` and `run_audit_tests.py` are ad-hoc scripts that spawn a server, not a real test suite. No `pytest`, no CI. |

### 1.6 Proposal-vs-reality gaps (matters for your capstone grade)

`Proposal_Report.docx` promises features the code does not implement. Either build them or restate them accurately in the report before review — a guide **will** ask.

| Promised | Reality |
|---|---|
| "AI-Based Threat Detection", "Predictive Safety Analytics", "Smart Danger Prediction" | A regex keyword list. **Calling this AI is the single most likely thing to cost you marks.** |
| "AI Safety Chatbot" | Not present. |
| Firebase Cloud Messaging push notifications | `FCM_SERVER_KEY` config exists; **zero implementation**. `sos.py` has a `# TODO` where the push should be. |
| Google Maps Platform / safe routes / heat map | Dependency added, no API key, no implementation. |
| Wearable / smartwatch / Bluetooth panic button | Not present. |
| "Offline SOS Support" | Not present. |
| PostgreSQL | Works, but the default path is SQLite. Fine for dev — just be accurate about it. |

**Recommendation:** in the report, split features into *Implemented*, *In Progress*, and *Proposed (Phase 4)*. Honest scoping reads as engineering maturity. Overclaiming reads as the opposite.

---

## 2. Target architecture

Keep the existing shape — it's sound. Layered FastAPI:

```
backend/
├── app/
│   ├── main.py              # app factory, CORS, lifespan, exception handlers
│   ├── config.py            # pydantic-settings, all values have dev defaults
│   ├── database.py          # engine, SessionLocal, Base, get_db
│   ├── core/
│   │   ├── security.py      # bcrypt + JWT
│   │   └── deps.py          # get_current_user, get_current_user_optional
│   ├── models/              # SQLAlchemy ORM
│   ├── schemas/             # Pydantic v2
│   └── api/v1/
│       ├── router.py
│       └── endpoints/       # auth, contacts, sos, journey, evidence, threat, helplines
├── alembic/
├── scripts/seed_helplines.py
├── tests/                   # NEW - pytest
├── requirements.txt
└── .env.example
```

**Principles:** the server must boot with zero configuration. SQLite by default, Postgres by env var. Every endpoint returns JSON, always. No route requires a trailing slash.

---

## 3. Implementation phases

---

### PHASE 1 — Make it compile and boot (blocking)

> **Goal:** `flutter run` builds, `uvicorn app.main:app` starts, on a clean clone with no manual setup.

#### 1.1 Fix the Dart compile errors

**`lib/services/app_service.dart`**
- Change `import 'app_models.dart';` → `import '../models/app_models.dart';`
- Replace all 6 uses of `ApiClient.instance` with a working accessor.

**`lib/services/api_client.dart`** — add a public static accessor so `ApiClient.instance` is real:

```dart
/// Public accessor. The class is a singleton via its factory constructor;
/// this just gives call sites a clearer name than `ApiClient()`.
static ApiClient get instance => ApiClient();
```

Prefer adding `instance` over rewriting the 6 call sites — it reads better and matches the singleton intent.

**`lib/models/app_models.dart`** — remove the unused `import 'dart:convert';`.
**`lib/services/auth_service.dart`** — remove the unused `import 'package:dio/dio.dart';`.

#### 1.2 Fix the missing asset directories

Create `assets/images/.gitkeep` and `assets/icons/.gitkeep` **and** commit them (verify `.gitignore` doesn't exclude them). Empty directories don't survive git; without the `.gitkeep` files this breaks again on the next clone.

*Alternative:* comment out the `assets:` block in `pubspec.yaml`. Prefer creating the directories — the app will need them.

#### 1.3 Make the backend boot with no `.env`

**`app/config.py`** — give every setting a working default:

```python
ENV: str = "development"
DATABASE_URL: str = "sqlite:///./durga.db"
SECRET_KEY: str = "dev-only-insecure-secret-change-me"
CORS_ORIGINS: str = "*"
UPLOAD_DIR: str = "uploads"
MAX_UPLOAD_BYTES: int = 25 * 1024 * 1024
ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24
ALGORITHM: str = "HS256"
FCM_SERVER_KEY: str = ""
```

Add to `get_settings()`:
- If `SECRET_KEY` is the dev default **and** `ENV == "production"` → raise `RuntimeError` with the generate-a-key command in the message.
- If it's the dev default in development → `warnings.warn(...)` with a freshly generated suggestion. Loud enough to notice, quiet enough not to block.

Add helper properties: `cors_origin_list` (splits comma-separated, handles `"*"`) and `is_sqlite`.

#### 1.4 Delete junk

Remove the 0-byte `modules` file at repo root.

> **Definition of Done — Phase 1**
> - `flutter analyze` reports **zero errors** (warnings acceptable for now)
> - `cd backend && rm -f .env && uvicorn app.main:app` starts successfully and logs a SECRET_KEY warning
> - `curl localhost:8000/health` → `200`

---

### PHASE 2 — Unblock the client (CORS, redirects, crashes)

> **Goal:** every endpoint reachable from a browser and from Dio, no 500s on empty state.

#### 2.1 CORS — the single highest-impact fix

**`app/main.py`**, added **before** `include_router`:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False,   # MUST be False when allow_origins=["*"]
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)
```

The `allow_credentials=False` pairing is not optional — browsers reject `Access-Control-Allow-Origin: *` combined with credentials, and it will fail confusingly.

#### 2.2 Kill the trailing-slash redirects

In `contacts.py`, `helplines.py`, and any new collection route, register **both** forms:

```python
@router.get("", response_model=List[ContactResponse])
@router.get("/", response_model=List[ContactResponse], include_in_schema=False)
def list_contacts(...):
```

`include_in_schema=False` on the slash variant keeps Swagger clean.

#### 2.3 Fix the `/sos/last` 500

`response_model=Optional[SOSAlertResponse]`, return the query result directly. Returning `200` + JSON `null` is correct here — "no active emergency" is a normal state, not an error. Do **not** use 404.

#### 2.4 Global exception handler + real health check

**`main.py`:**
- `@app.exception_handler(Exception)` → log the traceback, return `JSONResponse(500, {"detail": "Internal server error", "path": ...})`. Never return a bare string; Dio can't parse it.
- `/health` → execute `SELECT 1`, report `{"status", "database", "database_error", "env"}`.
- Add a `lifespan` that verifies DB connectivity on boot and, **on SQLite only**, calls `Base.metadata.create_all()` so a fresh clone works without running Alembic. On Postgres, log a reminder to run `alembic upgrade head` — migrations stay the source of truth there.
- Add `GET /` returning `{"service": "durga-api", "docs": "/docs", "health": "/health"}`.

#### 2.5 Populate `app/models/__init__.py`

Import and re-export all six models (`User`, `Contact`, `SOSAlert`, `Journey`, `Evidence`, `Helpline`). Required for step 2.4's `create_all()` to see anything.

> **Definition of Done — Phase 2**
> - `curl -i -X OPTIONS .../auth/login -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: POST"` → `200` with `Access-Control-Allow-Origin`
> - `curl -i .../api/v1/contacts -H "Authorization: Bearer $T"` → `200`, **no 307**
> - `GET /sos/last` on a brand-new account → `200` with body `null`
> - `/health` reports database status accurately

---

### PHASE 3 — Data integrity & security

#### 3.1 SQLite correctness — `database.py`

```python
_connect_args = {"check_same_thread": False} if settings.is_sqlite else {}
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, connect_args=_connect_args)
```

Add a `@event.listens_for(Engine, "connect")` hook issuing `PRAGMA foreign_keys=ON` when on SQLite — without it your `ondelete="CASCADE"` declarations do nothing.

Make `get_db()` roll back on exception before closing.

#### 3.2 UTC-correct timestamps

Create a shared `_ORMModel(BaseModel)` base in `schemas/features.py` with `model_config = {"from_attributes": True}` and a `@field_serializer("created_at", "updated_at", check_fields=False)` that attaches `timezone.utc` when `tzinfo is None` and returns `.isoformat()`. Apply to every response schema including `UserResponse`.

Verify: `created_at` in JSON must end in `+00:00`.

#### 3.3 Real validation

- `schemas/auth.py`: use `EmailStr` (add `email-validator==2.2.0` to requirements). Normalise email to lowercase in a validator — the unique index is case-sensitive on Postgres, so `Alice@x.com` and `alice@x.com` would otherwise both register.
- Password: require at least one letter and one digit.
- Phone: validate against `^\+?[0-9\s\-()]{6,20}$` in both auth and contact schemas.
- Lat/lng: `Field(ge=-90, le=90)` / `Field(ge=-180, le=180)`.
- `ContactUpdate`: make it a standalone `BaseModel` with **all fields Optional** — do not inherit `ContactBase`.
- Migrate `class Config: from_attributes` → `model_config = {"from_attributes": True}` (Pydantic v2).

#### 3.4 Password hashing

`core/security.py` — pre-hash with SHA-256 + base64 before bcrypt so input is always ≤72 bytes:

```python
def _prehash(plain: str) -> bytes:
    return base64.b64encode(hashlib.sha256(plain.encode("utf-8")).digest())
```

> ⚠️ **This changes the hash format — existing accounts can no longer log in.** On dev, delete `durga.db` / drop the Postgres DB and re-register. Note this in the commit message.

Also: catch `ExpiredSignatureError` separately from `JWTError` in `decode_access_token` so logs distinguish expired from forged. Add `iat` and `typ: "access"` claims.

#### 3.5 Auth hardening

**`core/deps.py`:**
- `HTTPBearer(auto_error=False)`, raise an explicit `401` with `WWW-Authenticate: Bearer` when credentials are absent.
- Add `get_current_user_optional()` returning `Optional[User]`, never raising.

**`endpoints/auth.py`:**
- Constant-time login: precompute a module-level `_DUMMY_HASH` and always run one `verify_password` even when the email is unknown.
- Add a simple in-process per-IP rate limiter on `/login` (deque of timestamps, 10 attempts / 5 min → `429`).
  **Comment honestly** that this is per-worker and resets on restart — adequate for a demo, not production. Use `slowapi` + Redis if this ever ships.
- `TokenResponse` gains `expires_in: int` (seconds).

#### 3.6 Fix `requirements.txt`

- **Remove `passlib[bcrypt]`** — never imported, and it collides noisily with bcrypt ≥4.
- **Add `bcrypt==4.2.1`** explicitly (it was only transitive).
- **Add `email-validator==2.2.0`** — required for `EmailStr`.
- Add `httpx` and `pytest` for Phase 6.

> **Definition of Done — Phase 3**
> - `POST /auth/register` with `"not-an-email"` → `422` (currently 201)
> - `PATCH /contacts/{id}` with only `{"name":"X"}` → `200`
> - All timestamps end in `+00:00`
> - Deleting a user cascades to their contacts on SQLite
> - Server starts with no bcrypt/passlib warnings

---

### PHASE 4 — Complete the API surface

Each of these exists because the Flutter app cannot function without it.

#### 4.1 SOS — `endpoints/sos.py`
- `POST /trigger` → status `201` (was 200). Set `is_active=True` explicitly.
- `GET /last` → `Optional[SOSAlertResponse]` (Phase 2.3).
- **`GET /history`** — NEW. Paginated, newest first, `limit` capped at 200.
- **`POST /{sos_id}/resolve`** — NEW. Sets `is_active=False`. **Without this, `/last` returns the user's first-ever alert forever.**
- Leave the FCM `# TODO` in place but make it explicit that push is unimplemented.

#### 4.2 Journey — `endpoints/journey.py`
- `POST /start` → reject with `409` if an active journey already exists (include its id in the detail).
- **`GET /active`** — NEW, `Optional[JourneyResponse]`. This is how the app restores trip state after being killed.
- **`GET ""` / `GET "/"`** — NEW, journey history.
- `PATCH /{id}` as the canonical update; keep `PUT /{id}/update` with `include_in_schema=False` for backwards compatibility.
- `POST /{id}/stop` → `409` if already stopped.

#### 4.3 Evidence — `endpoints/evidence.py`

This endpoint needs the most work.

- Anchor the upload dir to the backend package, not cwd:
  `BACKEND_ROOT = Path(__file__).resolve().parents[4]` → `UPLOAD_DIR = BACKEND_ROOT / settings.UPLOAD_DIR`
- **Content-type allowlist** mapping MIME → extension (jpeg, png, webp, heic, mp4, quicktime, mpeg, mp4 audio, aac, wav). Reject others with `415`. Derive the extension from **your own map**, never from the client-supplied filename — this also removes the `splitext(None)` crash and any path-traversal risk.
- **Stream in 1 MB chunks**, tracking bytes written. Exceed `MAX_UPLOAD_BYTES` → delete the partial file, return `413`.
- Reject zero-byte uploads with `400`.
- Store **only the opaque generated filename** in `file_path` — never the absolute server path.
- **`GET ""`** — NEW, list current user's evidence.
- **`GET /{id}/download`** — NEW, `FileResponse`, ownership-checked, with a `startswith(UPLOAD_DIR.resolve())` guard as defence in depth.
- **`DELETE /{id}`** — NEW, removes row and file.

#### 4.4 Helplines — `endpoints/helplines.py`
- Query the **`Helpline` table** (it already exists in the model and migration but was never used).
- Optional `?category=` filter.
- Keep the hardcoded list as a **fallback only when the table is empty**, so a fresh clone still shows something.
- Create **`backend/scripts/seed_helplines.py`** (idempotent) with real Indian numbers: 112, 100, 101, 108, 1091, 181, 1098, 1930, 14567, 182. Add `scripts/__init__.py`. Run with `python -m scripts.seed_helplines`.

#### 4.5 Threat — `endpoints/threat.py`
- Match on **word boundaries** via `re.findall(r"[a-z']+", text.lower())`, not substrings — currently "help" fires on "helpful" and "shelter".
- Two tiers: `HIGH_RISK` (weight 40) and `MEDIUM_RISK` (weight 15). Score = capped sum. ≥40 → High/red, ≥15 → Medium/orange, else Low/green.
  **This fixes the bug where any ordinary sentence returned Medium Risk.**
- Response gains `score: int` and `matched_keywords: list[str]` so the verdict is explainable and debuggable.
- Use `get_current_user_optional` — works logged out, but records the user when available.
- **Add a docstring stating plainly that this is rule-based keyword triage, not AI.** Do not let the proposal's "AI-Based Threat Detection" claim rest on this file.

#### 4.6 Deps cleanup
Make `app/api/deps.py` re-export `get_db`, `get_current_user`, `get_current_user_optional` with `__all__`, and add a note that new code should import from `app.core.deps` / `app.database` directly.

> **Definition of Done — Phase 4**
> - Every endpoint in the table in §5 responds as documented
> - `python -m scripts.seed_helplines` populates the table; `GET /helplines` returns DB rows
> - Uploading a `.exe` → `415`; a 30 MB file → `413`; a 0-byte file → `400`
> - `POST /threat/analyze` with `{"text":"hi"}` → **Low Risk** (currently Medium)

---

### PHASE 5 — Flutter integration layer

> **Constraint: do not touch UI/visual code.** Only `lib/services/`, `lib/models/`, and `android/` config.

#### 5.1 `lib/services/api_client.dart`
- Add the `static ApiClient get instance` accessor (Phase 1.1).
- Raise `connectTimeout`/`receiveTimeout` to 15 s; add `sendTimeout` (uploads on mobile data need it).
- **Add a 401 interceptor**: on `401`, clear the stored token so `AuthGate` falls back to login. Currently the `onError` handler is an empty passthrough and an expired token leaves the user permanently stuck on a broken home screen.
- Add a `LogInterceptor` (or a custom one) gated on `kDebugMode` — you will need request/response logs to debug integration.

#### 5.2 `lib/services/app_service.dart`
- Fix the import path.
- Use `ApiClient.instance`.
- **Drop trailing slashes** from all paths (`/contacts`, not `/contacts/`) now that Phase 2.2 supports both.
- Add the methods for the new endpoints: `updateContact`, `getLastSOS`, `getSOSHistory`, `resolveSOS`, `startJourney`, `getActiveJourney`, `updateJourney`, `stopJourney`, `listEvidence`, `deleteEvidence`, `getHelplines`.
- Wrap calls so `DioException` surfaces the server's `detail` field rather than a raw Dio message — users should see "Maximum of 10 emergency contacts reached", not `DioException [bad response]`.

#### 5.3 `lib/models/app_models.dart`
- `SOSAlert.fromJson` must tolerate the `null` body from `/sos/last`. Give `getLastSOS` return type `Future<SOSAlert?>` and null-check before parsing.
- Add `latitude`/`longitude` to `SOSAlert` — the API returns them and the map needs them.
- Add `Journey`, `Evidence`, `Helpline` models mirroring the response schemas.
- Add `createdAt` to `Contact`.
- Every `fromJson` must handle nulls defensively — a null in a non-nullable field is a runtime crash in release mode.

#### 5.4 `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>`, before `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CALL_PHONE"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

On `<application>`, add:
```xml
android:networkSecurityConfig="@xml/network_security_config"
```

Create **`android/app/src/main/res/xml/network_security_config.xml`** allowing cleartext **only** for `10.0.2.2`, `localhost`, `127.0.0.1`, and the `192.168.*` dev range, with `cleartextTrafficPermitted="false"` as the base config. Do **not** set a blanket `usesCleartextTraffic="true"` — that ships an insecure app.

Add the Maps key placeholder inside `<application>`:
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="${MAPS_API_KEY}"/>
```
Wire `MAPS_API_KEY` through `android/app/build.gradle.kts` `manifestPlaceholders`, reading from `local.properties` with an empty-string fallback so the build never breaks for a teammate without a key.

Also add matching `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist`.

> **Definition of Done — Phase 5**
> - `flutter analyze` → zero errors
> - App runs on an Android emulator, registers, logs in, and lists contacts against the local backend
> - Killing the backend produces a readable error message, not an unhandled exception

---

### PHASE 6 — One-command run (Android Studio + VS Code/Antigravity)

> This is the outcome you asked for most directly: **backend and frontend starting together, in two tabs, from one action.**

#### 6.1 Fix `.vscode/tasks.json`
- Change `"dependsOrder"` from `"sequence"` → **`"parallel"`**. This is the actual bug — a sequenced never-ending background task means the frontend never starts.
- Give the backend task a real background `problemMatcher` with `beginsPattern: ".*Started server process.*"` and `endsPattern: ".*Application startup complete.*"` so VS Code knows when it's up.
- Set `"presentation": {"panel": "dedicated", "group": "durga"}` on both → **two side-by-side terminal tabs**.
- Add utility tasks: **Seed helplines**, **Reset database**, **Run backend tests**.
- Mark "▶ Start Everything" as the default build task (`Ctrl+Shift+B`).

#### 6.2 Rewrite `.vscode/launch.json`
- Add a **`debugpy`** configuration launching `uvicorn` as a module with `cwd: backend`, `PYTHONPATH` set, and `envFile` pointing at `backend/.env`. This gives real backend breakpoints — currently impossible.
- Keep the Flutter configs; add a Chrome/Web one.
- Add **`compounds`**: `"DURGA: Backend + Android App"`, `"+ Web App"`, `"+ Desktop App"`, each with `"stopAll": true` so one stop kills both.

#### 6.3 Add `.vscode/settings.json` and `extensions.json`
Point `python.defaultInterpreterPath` at `backend/venv`, add `backend` to `python.analysis.extraPaths`, exclude `__pycache__`/`.dart_tool`/`venv` from the explorer. Recommend the Dart, Flutter, Python, and debugpy extensions.

#### 6.4 Android Studio support
Commit **`.run/`** configurations:
- `.run/Backend_FastAPI.run.xml` — a Python run config invoking uvicorn with the right working directory and interpreter.
- `.run/Durga_Flutter.run.xml` — Flutter run with the `--dart-define` arg.
- `.run/Backend_and_App.run.xml` — a **compound** running both.

IntelliJ/Android Studio reads `.run/*.xml` from the project root automatically, so teammates get the configs on clone with no setup.

#### 6.5 Harden the shell scripts
- `run_local.sh` / `.bat`: **auto-create `.env` from `.env.example`** when missing instead of erroring out (fix AI). Print the resolved `DATABASE_URL` (password masked). Detect whether Alembic or SQLite `create_all` applies and act accordingly. Keep it idempotent.
- `run_frontend.sh` / `.bat`: build the argument array properly so an empty `EXTRA_ARGS` isn't passed as a literal empty arg. Auto-detect a running backend on `:8000` and warn if it's down before launching.
- Add a top-level **`run_all.sh` / `run_all.bat`** that starts both in one terminal for people not using an IDE.

#### 6.6 Rewrite `LOCAL_SETUP.md`
Structure it as: **Quick start (3 commands)** → **IDE workflows (VS Code / Antigravity / Android Studio)** → **Device→URL matrix** → **Troubleshooting**.

The troubleshooting section must cover, with exact symptom text:
- `CLEARTEXT communication not permitted` → network security config
- `Connection refused` on the emulator → use `10.0.2.2`, not `localhost`
- `ValidationError: DATABASE_URL Field required` → missing `.env`
- `no such table` → run migrations or seed
- CORS errors in the browser console → `CORS_ORIGINS`
- Login failing after the Phase 3.4 hash change → delete the DB and re-register

> **Definition of Done — Phase 6**
> - **F5 → "DURGA: Backend + Android App"** starts both, with a working backend breakpoint
> - **`Ctrl+Shift+B`** opens two dedicated terminals, both running
> - Android Studio shows all three run configs on a fresh clone
> - A teammate can clone and be running in under 5 minutes using only `LOCAL_SETUP.md`

---

### PHASE 7 — Tests & documentation

#### 7.1 Real test suite
Create `backend/tests/` using `pytest` + `httpx.ASGITransport` against a temporary SQLite file, with `get_db` dependency-overridden per test.

Cover, at minimum, every ✅ VERIFIED bug so they cannot regress:
- `test_register_rejects_invalid_email` → expects `422`
- `test_sos_last_returns_null_when_empty` → expects `200` + `null`
- `test_contacts_no_trailing_slash_redirect` → expects `200`, not `307`
- `test_cors_preflight_allowed` → expects `200` + `Access-Control-Allow-Origin`
- `test_partial_contact_update` → expects `200`
- `test_timestamps_are_utc_aware` → asserts `+00:00`
- `test_upload_rejects_bad_mime` / `test_upload_rejects_oversize`
- `test_cannot_read_another_users_contacts` → **ownership isolation, the most important security test in the suite**
- `test_login_rate_limited`
- `test_threat_ordinary_text_is_low_risk`

Then **delete `run_api_tests.py` and `run_audit_tests.py`** — superseded.

#### 7.2 Docs
- **`backend/API.md`** — every endpoint: method, path, auth, request, response, status codes.
- Update **`README.md`** with accurate feature status (see §1.6) and an architecture diagram.
- Add **`backend/requests.http`** for the REST Client extension — a click-to-run smoke test of the whole API.

#### 7.3 CI (optional but cheap)
`.github/workflows/ci.yml`: install deps, run `pytest`, run `flutter analyze`. Catches the exact class of compile error that is currently in `main`.

---

## 4. Do NOT do these

- **Do not redesign the UI.** Out of scope.
- **Do not add new dependencies** beyond `email-validator`, `bcrypt`, `httpx`, `pytest`.
- **Do not implement FCM, the AI chatbot, wearables, or safe-route ML.** Those are Phase 4 of the *project*, not this rework. Fix the foundation first.
- **Do not switch the default DB to Postgres.** SQLite-by-default is why a fresh clone works; Postgres stays one env var away.
- **Do not delete the Alembic migration.** It is correct. Add new revisions if models change.
- **Do not commit `.env`, `durga.db`, `venv/`, or `uploads/`.** Verify `.gitignore` covers all four.

---

## 5. API reference after rework

`*` = new endpoint · **bold** = changed behaviour

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/health` | – | **now checks DB** |
| GET | `/` | – | * service info |
| POST | `/api/v1/auth/register` | – | **EmailStr, 409 on duplicate** |
| POST | `/api/v1/auth/login` | – | **constant-time, rate-limited, `expires_in`** |
| GET | `/api/v1/auth/me` | ✅ | |
| GET | `/api/v1/contacts` | ✅ | **no trailing slash** |
| POST | `/api/v1/contacts` | ✅ | **max 10, dup phone → 409** |
| PATCH | `/api/v1/contacts/{id}` | ✅ | * **partial update works** |
| DELETE | `/api/v1/contacts/{id}` | ✅ | |
| POST | `/api/v1/sos/trigger` | ✅ | **201** |
| GET | `/api/v1/sos/last` | ✅ | **200 + null, no more 500** |
| GET | `/api/v1/sos/history` | ✅ | * |
| POST | `/api/v1/sos/{id}/resolve` | ✅ | * |
| POST | `/api/v1/journey/start` | ✅ | **409 if one active** |
| GET | `/api/v1/journey/active` | ✅ | * |
| GET | `/api/v1/journey` | ✅ | * |
| PATCH | `/api/v1/journey/{id}` | ✅ | * |
| POST | `/api/v1/journey/{id}/stop` | ✅ | |
| POST | `/api/v1/evidence/upload` | ✅ | **MIME allowlist, size cap** |
| GET | `/api/v1/evidence` | ✅ | * |
| GET | `/api/v1/evidence/{id}/download` | ✅ | * |
| DELETE | `/api/v1/evidence/{id}` | ✅ | * |
| POST | `/api/v1/threat/analyze` | optional | **scored + explainable** |
| GET | `/api/v1/helplines` | – | **DB-backed** |

---

## 6. Verification script

Run this after Phase 4. Every line must pass.

```bash
cd backend && rm -f durga.db .env
uvicorn app.main:app --port 8000 &   # must start with NO .env
sleep 5
B=http://127.0.0.1:8000

curl -s $B/health | grep -q '"database":"connected"'                    || echo "FAIL health"
curl -s -o /dev/null -w "%{http_code}" -X OPTIONS $B/api/v1/auth/login \
  -H "Origin: http://x.com" -H "Access-Control-Request-Method: POST" | grep -q 200 || echo "FAIL cors"
curl -s -o /dev/null -w "%{http_code}" -X POST $B/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"bad","password":"pass1234","full_name":"X","phone":"+911234567890"}' | grep -q 422 || echo "FAIL email validation"

curl -s -X POST $B/api/v1/auth/register -H 'Content-Type: application/json' \
  -d '{"email":"t@t.com","password":"pass1234","full_name":"T","phone":"+911234567890"}' > /dev/null
T=$(curl -s -X POST $B/api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"t@t.com","password":"pass1234"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

curl -s -o /dev/null -w "%{http_code}" $B/api/v1/contacts -H "Authorization: Bearer $T" | grep -q 200 || echo "FAIL trailing slash"
curl -s $B/api/v1/sos/last -H "Authorization: Bearer $T" | grep -q null                || echo "FAIL sos/last null"
curl -s $B/api/v1/auth/me  -H "Authorization: Bearer $T" | grep -q '+00:00'             || echo "FAIL utc timestamps"
curl -s -X POST $B/api/v1/threat/analyze -H 'Content-Type: application/json' \
  -d '{"text":"hi"}' | grep -q "Low Risk"                                               || echo "FAIL threat scoring"
echo "verification complete"
```

---

## 7. Suggested commit sequence

```
fix(build): resolve Dart compile errors and missing asset directories
fix(backend): boot without .env by giving all settings dev defaults
feat(backend): add CORS middleware, global exception handler, DB health check
fix(api): eliminate trailing-slash 307s and the /sos/last 500
fix(db): SQLite thread safety and foreign key enforcement
fix(security): bcrypt 72-byte truncation, constant-time login, 401 semantics
fix(schemas): EmailStr validation, optional update fields, UTC-aware timestamps
feat(api): SOS resolve/history, journey active/list, evidence list/download
feat(api): DB-backed helplines with seed script
fix(api): word-boundary threat scoring with explainable output
fix(flutter): API client singleton, 401 interceptor, new service methods
fix(android): INTERNET + location permissions, network security config
feat(tooling): parallel VS Code tasks, compound launch, Android Studio run configs
test(backend): pytest suite covering all verified regressions
docs: rewrite LOCAL_SETUP with troubleshooting; add API.md
```

---

## 8. One-paragraph brief (paste this to start)

> Read `DURGA_REWORK_PLAN.md` in full before writing any code. Then execute Phase 1, run its Definition of Done checks, and report results before continuing. Work on branch `rework/backend-and-runnability`, commit after each phase using the messages in §7. The three blocking bugs are: a wrong import path in `lib/services/app_service.dart`, six references to a non-existent `ApiClient.instance`, and two asset directories declared in `pubspec.yaml` that don't exist. Fix those first — the app has never compiled. Do not touch UI code, do not add dependencies beyond the four listed in §4, and do not implement FCM/chatbot/wearables.
