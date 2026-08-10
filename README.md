# 🛡️ DURGA - SafeConnect



### Women's Safety & Emergency Response Application

A modern Flutter application designed to enhance women's safety through instant SOS alerts, live location sharing, emergency contacts, AI-powered threat analysis, and quick access to emergency services.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android-green)
![License](https://img.shields.io/badge/License-MIT-orange)

</div>

---

# 📱 Overview

**DURGA - SafeConnect** is a mobile safety application built using Flutter that helps users quickly access emergency services during unsafe situations.

The app combines real-time location services, emergency contact management, evidence collection, and AI-assisted threat analysis into one intuitive interface.

---

# ✨ Features

## 🚨 SOS Emergency Alert

- One-tap SOS button
- Sends emergency alert
- Shares current location
- Designed for rapid response

---

## 👥 Trusted Contacts

- Add multiple emergency contacts
- Save contacts locally
- Easy management
- Future SMS integration

---

## 🔎 Keyword-Based Threat Triage

> **Note:** this is rule-based keyword scoring, not AI/ML. There is no model or training involved — see the honest feature status table below.

Word-boundary matches free text against a weighted keyword list.

Example keywords:

- Help, scared, alone, unsafe (Medium)
- Danger, attack, threat, followed, harassment (High)

Displays

- 🟢 Low Risk
- 🟠 Medium Risk
- 🔴 High Risk

---

## 📍 Live Location

- GPS Location
- Latitude & Longitude
- Refresh Location
- Open directly in Google Maps

---

## 📷 Evidence Collection

Capture emergency evidence using:

- Camera
- Video Recorder

Useful during emergency situations.

---

## ☎ Emergency Helplines

Quick access to

- 112 National Emergency
- 181 Women Helpline

---

## 📋 Copy Last SOS

Copies the latest SOS message to clipboard.

Useful if messaging services are unavailable.

---

## 🌐 Multi-language Support

Planned support

- English
- Telugu
- Tamil

---

## 🌙 Dark Mode

Upcoming feature.

---

# ✅ Feature Status

Honest scoping of what's implemented vs. proposed. "Backend" means the API endpoint exists and is tested; "Frontend" means a real screen/widget calls it — no more static mockups with backend endpoints sitting unused.

| Feature | Backend | Frontend |
|---|---|---|
| SOS trigger / resolve / history | ✅ | ✅ Home SOS button + FAB trigger; Safety tab shows history, resolves alerts |
| Trusted contacts (CRUD, 10-contact cap) | ✅ | ✅ Home contacts card — list, add, delete |
| Live location (GPS, share, open in Maps) | — | ✅ Home location card — real device GPS, refresh, open in Maps |
| Evidence upload/list/download/delete | ✅ | ✅ Home evidence card — camera/video capture uploads, lists, deletes |
| Journey tracking (start/active/stop) | ✅ | ✅ SafeZone tab — start/stop with live status |
| Emergency helplines (DB-backed) | ✅ | ✅ Home quick-dial buttons + full list on Safety tab |
| Keyword-based threat triage | ✅ | ✅ Home threat card (rule-based, **not** AI) |
| User profile / logout | ✅ | ✅ Settings tab + header account menu |
| Firebase Cloud Messaging push alerts | 🚧 Config exists, unimplemented | — |
| Google Maps rendering (map key wiring) | — | 🚧 Dependency + key plumbing exists, no in-app map view |
| AI safety chatbot | 📋 Proposed | 📋 Proposed |
| Predictive/AI threat detection | 📋 Proposed | 📋 Proposed |
| Wearable / Bluetooth panic button | 📋 Proposed | 📋 Proposed |
| Offline SOS support | 📋 Proposed | 📋 Proposed |
| Multi-language support | 📋 Proposed | 📋 Proposed |

---

# 🏗️ Project Structure

```
lib/
│
├── models/
├── services/
├── screens/
│   ├── home_screen.dart
│   ├── safety_screen.dart
│   ├── safezone_screen.dart
│   └── settings_screen.dart
│
├── theme/
│   ├── colors.dart
│   └── app_theme.dart
│
├── widgets/
│   ├── buttons/
│   ├── cards/
│   ├── common/
│   └── navigation/
│
├── utils/
│
└── main.dart
```

---

# 🛠️ Built With

- Flutter
- Dart
- Material Design 3

Packages used

- provider
- geolocator
- geocoding
- permission_handler
- image_picker
- url_launcher
- shared_preferences
- google_fonts
- flutter_svg
- google_maps_flutter
- intl

---

# 🚀 Installation

### Frontend (Flutter App)

1. Clone the repository:
   ```bash
   git clone https://github.com/GangaNimesh/Durga.git
   ```
2. Go to project directory:
   ```bash
   cd Durga
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the application:
   ```bash
   flutter run
   ```

### Backend (FastAPI API Server)

### Quick Start (Local, No Docker, No Setup)

The backend boots with zero configuration — SQLite by default, every setting has a dev default. See [LOCAL_SETUP.md](LOCAL_SETUP.md) for the full quick-reference guide, IDE workflows, and troubleshooting — or [HOWTORUN.md](HOWTORUN.md) for a walkthrough of *why* each piece works the way it does, written for learning the codebase rather than just copy-pasting commands.

```bash
backend/run_local.sh      # macOS/Linux — Windows: backend\run_local.bat
```

Or run both frontend and backend together:
- **VS Code:** `Ctrl+Shift+B` (Cmd+Shift+B on macOS) runs "Start Everything".
- **CLI:** `./run_all.sh` (or `run_all.bat` on Windows) from the repo root.
- **Android Studio:** the "Backend + App" run configuration (committed under `.run/`).

Postgres is supported and production-ready — set `DATABASE_URL` in `backend/.env` and run `alembic upgrade head` — but it is opt-in, not required for local development.

Optional Docker path (Postgres + API in containers):
```bash
cd backend
docker compose up -d --build
alembic upgrade head
```

---

# 📦 Requirements

* **Frontend:** Flutter SDK 3.x, Dart SDK 3.x
* **Backend:** Python 3.12+ (PostgreSQL and Docker are optional — SQLite is the local default)

---

# 📌 Future Improvements

See the Feature Status table above for what's proposed vs. implemented. Near-term priorities:

* **Native FCM Push Alerts:** wire up the existing `FCM_SERVER_KEY` config to actually notify emergency contacts.
* **Cloud Evidence Storage:** move uploaded evidence off local disk to S3/GCS.
* **Map screen:** use the now-wired `MAPS_API_KEY` to render live location and safe routes.

---

# 🎯 Application Workflow

```
User Opens App
        │
        ▼
   Login / Register
        │
        ▼
 Home Dashboard ──┬─► SOS Alert (real-time trigger)
                  ├─► Threat Analysis
                  ├─► Live Location
                  ├─► Trusted Contacts
                  ├─► Evidence Collection
                  └─► Emergency Calls
        │
        ├─► Safety tab    — SOS history + helplines
        ├─► SafeZone tab  — journey start/active/stop
        └─► Settings tab  — profile + logout
```

---

# 📄 License

This project is licensed under the MIT License.

---

# 👨‍💻 Developer

**GangaNimesh**

B.Tech Computer Science Engineering

Flutter Developer | [GitHub](https://github.com/GangaNimesh/Durga)

---

# ❤️ Acknowledgements

- Flutter Team
- Material Design
- Android Location Services
- Open Source Community

---

## ⭐ Support

If you like this project, consider giving it a **⭐ Star** on GitHub.

It helps others discover the project!

---

<div align="center">

### DURGA - SafeConnect

**Empowering Safety Through Technology**

</div>
