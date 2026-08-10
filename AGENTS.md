# Project Briefing & Context: DURGA Safety Application

> [!IMPORTANT]
> **To any AI assistant, agent, or developer tool reading this file:**
> This is a persistent context file representing the current verified state, tech stack, constraints, and architecture of the Durga Women Safety App. 
> Do NOT assume folders, databases, or API keys exist unless they are documented below. 
> Validate all code logic and API integration pathways empirically before claiming tasks are completed.

---

## 1. Project Summary
**DURGA (Women Safety Application)** is a safety app designed to protect users in dangerous situations by offering emergency contacts CRUD, quick SOS alert broadcasting with GPS tracking, safe journey monitoring, threat classification, and cloud evidence upload. 

### Current Maturity Level
* **Backend:** A working, audited FastAPI + PostgreSQL service exists under `backend/`. It has been tested and verified locally using SQLite and Alembic migrations.
* **Frontend:** A Flutter app exists under `lib/`. It is mostly a UI shell; the network services (`ApiClient`, `AuthService`, `AppService`, and `AuthProvider`) have been scaffolded and the `ThreatCard` widget is connected to the backend, but the other screens and cards are not yet integrated with the API.

---

## 2. Tech Stack & Dependency Versions

### Flutter / Dart Frontend
* **Dart SDK:** `^3.12.2`
* **Key Dependencies:**
  * `provider: ^6.1.5` (State management)
  * `dio: ^5.7.0` (HTTP Client)
  * `flutter_secure_storage: ^9.2.4` (Keychain/Keystore JWT storage)
  * `geolocator: ^11.1.0` (GPS coordinates)
  * `google_maps_flutter: ^2.9.0` (Maps presentation)

### FastAPI Backend
* **Python Version:** `3.14.2` (locally) / `3.12-slim` (inside Docker container)
* **PostgreSQL Version:** `postgres:16-alpine` (in `docker-compose.yml`)
* **Pinned Dependencies (`requirements.txt`):**
  * `fastapi==0.115.12`
  * `uvicorn[standard]==0.34.2`
  * `sqlalchemy==2.0.41`
  * `alembic==1.15.2`
  * `psycopg[binary]==3.2.10`
  * `python-jose[cryptography]==3.4.0`
  * `bcrypt==4.0.0` or newer (directly imported in `core/security.py`)
  * `pydantic-settings==2.9.1`
  * `python-dotenv==1.1.0`
  * `python-multipart==0.0.20`

---

## 3. Repository Structure

```
DURGA-MASTER/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── app_models.dart
│   │   └── auth_models.dart
│   ├── providers/
│   │   └── auth_provider.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── safety_screen.dart
│   │   ├── safezone_screen.dart
│   │   ├── settings_screen.dart
│   │   └── ...
│   ├── services/
│   │   ├── api_client.dart
│   │   ├── app_service.dart
│   │   └── auth_service.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── colors.dart
│   └── widgets/
│       ├── buttons/
│       │   ├── copy_sos_button.dart
│       │   └── emergency_button.dart
│       └── cards/
│           ├── contacts_card.dart
│           ├── evidence_card.dart
│           ├── location_card.dart
│           ├── sos_card.dart
│           └── threat_card.dart
└── backend/
    ├── alembic/
    │   ├── env.py
    │   ├── script.py.mako
    │   └── versions/
    │       └── bf4c4e96721e_initial_migrations.py
    ├── app/
    │   ├── api/
    │   │   ├── deps.py
    │   │   └── v1/
    │   │       ├── router.py
    │   │       └── endpoints/
    │   │           ├── auth.py
    │   │           ├── contacts.py
    │   │           ├── evidence.py
    │   │           ├── helplines.py
    │   │           ├── journey.py
    │   │           ├── sos.py
    │   │           └── threat.py
    │   ├── core/
    │   │   ├── deps.py
    │   │   └── security.py
    │   ├── models/
    │   │   ├── features.py
    │   │   └── user.py
    │   ├── database.py
    │   ├── config.py
    │   └── main.py
    ├── Dockerfile
    ├── docker-compose.yml
    ├── requirements.txt
    └── alembic.ini
```

---

## 4. Current Progress (Audit Handoff Status)

### Verified Working
* **Authentication:** Password hashing using direct `bcrypt`, JWT issuance, and route validation.
* **CRUD Endpoints:** Contacts (CRUD), Journeys (start/update/stop), SOS (trigger/last), Evidence (upload), Threat (server-side string analyze), Helplines (GET).
* **BOLA Prevention:** All resources query on `owner_id / user_id == current_user.id`, blocking IDOR attacks with a `404 Not Found` response.
* **SQLi Secure:** Fully parameterized via SQLAlchemy ORM mapping.
* **Database Cascades:** Deleting a user cascade-cleans up contacts, journeys, and SOS records successfully.

### Known Gaps & Deferred Items
* **FCM Push Notifications:** Backend prepares payloads, but native Firebase wiring (`google-services.json`) has been deferred.
* **Evidence Cloud Storage:** Uploaded audio/video files are stored locally on server disk (`uploads/` directory) rather than in AWS S3 or GCP buckets.
* **CORS Setup:** No CORS headers are currently enabled in `main.py` (CORS fails for browser clients).
* **Brute-Force & Rate Limiting:** No limit is enforced on `/auth/login` or `/sos/trigger` yet.

---

## 5. Architectural Decisions & Rationale

* **`dio` over `http`:** Chosen for native support of interceptors, automatic JSON serialization/deserialization, and unified base configuration.
* **`flutter_secure_storage` over `shared_preferences`:** Chosen to encrypt JWT access tokens in the device's secure vault (Keychain/Keystore) rather than plaintext storage.
* **Direct `bcrypt` over `passlib`:** Bypassed passlib's deprecated CryptContext mixin to avoid library version mismatches and `ValueError` limitations on newer python builds (3.14+).
* **Server-side Threat Classification:** Hardcoded threat keywords are hosted on the backend `/threat/analyze` path, allowing the classification algorithm to be upgraded to an ML model later without triggering a mobile app store update.
* **UUID Primary Keys:** Used `uuid4` char strings for database identifiers instead of auto-incrementing integers, making ID guessing (BOLA) virtually impossible.

---

## 6. Constraints for Future Development (Developer/Agent Rules)

* **Rule 1:** Never add new packages or native plugins without checking version constraints and getting approval.
* **Rule 2:** Do not modify native Android (`android/`) or iOS (`ios/`) directory builds or files unless specifically tasked with wiring up native modules (like FCM).
* **Rule 3:** Database modifications must occur via Alembic migrations. Do not manually modify SQLite/PostgreSQL schemas or run raw DDL scripts.
* **Rule 4:** Never fabricate mock API responses in code or tests; always map requests exactly to the current Pydantic models.
* **Rule 5:** Perform verification runs with real shell output before declaring a feature complete.

---

## 7. How to Run Locally

### Start Backend
1. Go to the `backend/` folder.
2. Build and boot PostgreSQL + FastAPI containers:
   ```bash
   docker compose up -d --build
   ```
3. Apply alembic migrations:
   ```bash
   # Inside the app container, or with python path set:
   alembic upgrade head
   ```

### Start Frontend
1. Ensure the Flutter SDK is on your PATH.
2. Run package resolver:
   ```bash
   flutter pub get
   ```
3. Launch device emulator and start app:
   ```bash
   flutter run
   ```

---

## 8. Resuming Next: Phase 3 Frontend Wiring
The immediate next task is completing **Phase 3 (Frontend Integration)**. This involves:
1. Connecting `login_screen.dart` and `register_screen.dart` to the `AuthProvider` state.
2. Confirming that JWT tokens save to `flutter_secure_storage` on login and are deleted on logout.
3. Hooking the remaining dashboard cards (Contacts, Evidence, Journey) to live API methods inside `AppService.dart`.
