# DURGA Backend API Reference

Base URL: `http://<host>:8000` — versioned endpoints are under `/api/v1`.

All request/response bodies are JSON. Authenticated endpoints require `Authorization: Bearer <access_token>`.

---

## Health & meta

### `GET /`
No auth. Returns `{"service": "durga-api", "docs": "/docs", "health": "/health"}`.

### `GET /health`
No auth. Returns `{"status", "database", "database_error", "env"}`. `database` is `"connected"` or `"unreachable"` based on a live `SELECT 1`.

---

## Auth — `/api/v1/auth`

### `POST /register`
No auth. Body: `{email, password, full_name, phone}`.
- `email`: validated (`EmailStr`), lowercased before storage.
- `password`: 8-128 chars, must contain a letter and a digit.
- `phone`: `^\+?[0-9\s\-()]{6,20}$`.
- **201** → `UserResponse`. **409** if email already registered. **422** on validation failure.

### `POST /login`
No auth. Body: `{email, password}`.
- **200** → `TokenResponse` (`access_token`, `token_type`, `expires_in` seconds).
- **401** on wrong credentials (constant-time — same latency whether the email exists or not).
- **403** if the account is deactivated.
- **429** after 10 failed attempts from the same IP within 5 minutes (in-process, per-worker, resets on restart).

### `GET /me`
Auth required. Returns the current user's `UserResponse`.

---

## Contacts — `/api/v1/contacts`

Max 10 contacts per user. Duplicate phone number within a user's contact list → `409`.

| Method | Path | Notes |
|---|---|---|
| GET | `` / `/` | List the current user's contacts. |
| POST | `` / `/` | Create. `409` if at the 10-contact cap or phone is a duplicate. |
| PATCH | `/{id}` | Partial update — any subset of `name`, `phone`, `relation`. |
| DELETE | `/{id}` | **204** on success, `404` if not found / not owned. |

---

## SOS — `/api/v1/sos`

| Method | Path | Notes |
|---|---|---|
| POST | `/trigger` | Body: `{latitude?, longitude?}`. **201**. Creates an alert with `is_active=true`. |
| GET | `/last` | Returns the most recent **active** alert, or `null` (200) if none. |
| GET | `/history?limit=` | Newest-first list, `limit` capped at 200 (default 50). |
| POST | `/{id}/resolve` | Sets `is_active=false`. Without this, `/last` would return the same alert forever. |

FCM push on trigger is **not implemented** — the `FCM_SERVER_KEY` config exists but nothing sends a notification yet.

---

## Journey — `/api/v1/journey`

| Method | Path | Notes |
|---|---|---|
| POST | `/start` | Body: `{start_latitude?, start_longitude?, dest_latitude?, dest_longitude?}`. **409** if the user already has an active journey. |
| GET | `/active` | The user's current active journey, or `null`. Used to restore trip state after the app is killed. |
| GET | `` / `/` | Journey history, newest first. |
| PATCH | `/{id}` | Partial update (`dest_latitude`, `dest_longitude`, `is_active`). |
| PUT | `/{id}/update` | Deprecated alias for `PATCH /{id}` — kept for backwards compatibility, hidden from `/docs`. |
| POST | `/{id}/stop` | Sets `is_active=false`. `409` if already stopped. |

---

## Evidence — `/api/v1/evidence`

| Method | Path | Notes |
|---|---|---|
| POST | `/upload` | Multipart `file`. MIME allowlist (jpeg/png/webp/heic images, mp4/mov/mpeg video, mp4/aac/wav audio) → `415` otherwise. Streamed in 1MB chunks, capped at `MAX_UPLOAD_BYTES` (default 25MB) → `413` if exceeded. Empty file → `400`. **201** → `EvidenceResponse`. |
| GET | `` / `/` | List the current user's evidence. |
| GET | `/{id}/download` | `FileResponse`, ownership-checked. |
| DELETE | `/{id}` | Removes DB row and the file on disk. **204**. |

`file_path` in responses is always an opaque server-generated filename — never a filesystem path.

---

## Threat — `/api/v1/threat`

### `POST /analyze`
Auth optional (records the user when a valid token is present, works logged out too). Body: `{text}`.

Word-boundary keyword scoring — **not** AI/ML. Returns `{risk_level, color, score, matched_keywords}`. Score ≥40 → High/red, ≥15 → Medium/orange, else Low/green.

---

## Helplines — `/api/v1/helplines`

### `GET /?category=`
No auth. DB-backed; falls back to a small hardcoded list only if the table is empty (fresh clone that hasn't run the seed script). Seed with:
```bash
cd backend && python -m scripts.seed_helplines
```

---

## Error shape

Unhandled exceptions return `500` with `{"detail": "Internal server error", "path": "..."}` — always JSON, never a bare string. Validation errors follow FastAPI's standard `422` shape. Missing/invalid auth returns `401` with a `WWW-Authenticate: Bearer` header.
