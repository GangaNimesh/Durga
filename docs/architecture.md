# Durga — Architecture & Implementation Notes

> Reference document for the app's architecture, what's been built, and what's pending.

---

## App Flow

```
[ First Launch ]
  ↓
OnboardingScreen (3 slides — one-time)
  ├── Slide 1: Welcome (protection illustration)
  ├── Slide 2: Phone + Email (saved to Supabase `users`)
  └── Slide 3: Add Trusted Contacts (saved to Supabase `emergency_contacts`)
  ↓
BottomNav → NewHomeScreen (main hub)
  ├── Safety Profile pill → SafetyProfileScreen (medical info + permissions)
  ├── SOS button → Phone dialer with 100
  ├── Trusted Contacts → ManageContactsSheet
  ├── Nearest Help → Google Maps (hardcoded for now)
  ├── Emergency Helplines → Expandable list with dialer
  └── Quick Actions Bar:
      ├── Fake Call → FakeCallScreen
      ├── Silent Record → SilentRecorder service
      ├── Share Trip → (not implemented yet)
      └── Emergency → Emergency contacts dialer

[ Subsequent Launches ]
  ↓
BottomNav → NewHomeScreen (skips onboarding)
```

---

## Data Layer

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Supabase** | PostgreSQL (cloud) | Persistent storage for user data, contacts, medical profile, permissions |
| **SharedPreferences** | Local key-value | Fast local flags (onboarding complete, device UUID) |
| **Device UUID** | Generated once, stored locally | User identifier across all Supabase tables |

---

## Dependencies Added

| Package | Version | Purpose |
|---------|---------|---------|
| `supabase_flutter` | ^2.8.0 | Supabase SDK for database operations |
| `flutter_contacts` | ^1.1.9+2 | Pick contacts from phone address book |
| `record` | ^5.1.2 | Silent audio recording |

---

## What's Implemented ✅

- [x] Onboarding carousel (3 slides, one-time, deep plum theme)
- [x] Onboarding colors and reusable layout widgets
- [x] Custom protection illustration (CustomPainter)
- [x] Page indicator dots
- [x] SharedPreferences-based onboarding gate
- [ ] Supabase integration
- [ ] Functional onboarding (data persistence)
- [ ] Homepage redesign
- [ ] Safety profile flow
- [ ] Contact management
- [ ] Fake call
- [ ] Silent recording
- [ ] SOS dialer
- [ ] Nearest help
- [ ] Emergency helplines

---

## What's Pending 🔲

### High Priority
- Supabase table creation and service layer
- Functional onboarding with data persistence
- Homepage redesign matching mockup
- Contact management (add from phone, display on homepage)

### Medium Priority
- Safety profile completion flow (medical + permissions)
- SOS long-press → dialer
- Emergency helplines expandable card
- Fake call simulation

### Low Priority / Future
- Google Places API integration for nearest help
- Share Trip / live location sharing
- Supabase Auth migration (replace device UUID with real accounts)
- Push notifications for SOS alerts
- Journey tracking migration to Supabase

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Supabase init, onboarding gate |
| `lib/services/supabase_service.dart` | All Supabase CRUD operations |
| `lib/screens/onboarding_screen.dart` | 3-slide onboarding carousel |
| `lib/screens/new_home_screen.dart` | Redesigned homepage |
| `lib/screens/safety_profile_screen.dart` | Medical info + permissions flow |
| `lib/screens/fake_call_screen.dart` | Incoming call simulation |
| `lib/services/silent_recorder.dart` | Audio recording service |
| `lib/theme/onboarding_colors.dart` | Dark plum color palette |
| `lib/theme/colors.dart` | Main app color palette |
| `docs/supabase_tables.md` | Database schema documentation |
