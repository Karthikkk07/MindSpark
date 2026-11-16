# MindSpark: submission notes

Flutter Developer Intern assignment, Sankar Group. MindSpark is a motivation app for Android: a daily quote, a searchable quote library, favorites, goals with daily check-ins and streaks, a daily reminder, an Android home-screen widget, and an optional AI goal coach.

Repository: https://github.com/Karthikkk07/MindSpark
Live API: https://mindspark-api-xqpn.onrender.com/api (health: `/api/health`)
Download the Android app: https://github.com/Karthikkk07/MindSpark/releases/download/v1.0.0/MindSpark-1.0.0.apk

## How the assignment is covered

| Task | Where |
|---|---|
| **1. Design and setup** | Material 3 theme with light and dark modes ([app_theme.dart](lib/core/theme/app_theme.dart)). Splash screen ([splash_screen.dart](lib/features/splash/splash_screen.dart)), onboarding, custom launcher icon. Layouts are scrollable and use no fixed heights, and the screenshots were taken on a 1440x3040 emulator. |
| **2. Core screens** | Login and sign-up ([auth_screen.dart](lib/features/auth/auth_screen.dart)). Home with the daily quote ([home_screen.dart](lib/features/home/home_screen.dart)). Listing: the quote library and the goals list. Details: quote details and goal details. Also Favorites, Settings and goal editing. |
| **3. Functionality** | go_router navigation with a bottom bar and nested routes. Validated forms (sign-up, sign-in, goals). Search, category filters and three sort orders in the library. Riverpod for state. |
| **4. API integration** | Own backend (Express and MongoDB). The quote list comes from `GET /api/quotes`, with loading, error and empty states and pull-to-refresh. Sign-in, favorites, settings and goals sync use the API too. Details below. |
| **5. Data management** | `shared_preferences` for settings, favorites, goals, the quote cache and the sync queue. `flutter_secure_storage` (Android Keystore) for the login token. The app is local-first and fully usable offline as a guest. |

## Architecture

```
lib/
  core/         router, theme, API client, shared widgets, preferences, platform channels
  features/     one folder per feature: auth, quotes, favorites, goals, sync,
                reminders, ai, settings, splash, onboarding, home, widget
  models/       plain data classes (Quote, QuoteCategory, UserPrefs)
  repositories/ storage and data sources behind small interfaces
backend/        Express API: routes, controllers, validators, models, services, tests
android/        Kotlin: share sheet, home-screen widget, reminder alarm (platform channels)
```

- **State management:** Riverpod. Each feature has providers (`*_providers.dart`) or a controller (`Notifier`) and screens that only watch them. Repositories sit behind interfaces, so tests replace them with fakes.
- **Local-first:** the UI reads from the device. Network work happens in the background (`ApiQuoteRepository.refresh`, the sync controller), so the app never blocks on the network.
- **Quote data flow:** bundled JSON (first run and offline fallback) -> saved copy -> latest list from the API. `loadAll()` answers immediately from the device, and a refresh at start-up or a pull-down replaces the saved copy and updates the screen.
- **Sync:** per goal, the newer change wins. Check-ins are calendar dates in the user's time zone, so streaks do not depend on UTC.
- **Backend:** layered (routes -> controllers -> models). Input is validated with zod, passwords are hashed with bcrypt, and JWTs are pinned to HS256. Every user-owned query is scoped to the signed-in user.

## Packages and tools

| Area | Choice |
|---|---|
| App | Flutter, Dart, Material 3, `flutter_riverpod`, `go_router`, `shared_preferences`, `flutter_secure_storage`, `http`, `flutter_launcher_icons` |
| Android native | Kotlin platform channels: share, home-screen widget, reminder alarm and notification |
| Backend | Node.js, Express, Mongoose (MongoDB), zod, JWT, bcryptjs, helmet, express-rate-limit, pino |
| AI | Google Gemini, called only from the backend so the key never reaches the phone |
| Quality | `flutter analyze`, 140+ Flutter tests, ~100 Jest and supertest backend tests, GitHub Actions CI |
| Tools | VS Code, Android Studio emulator, Postman, GitHub, AI coding assistance (I can explain every part of the code) |

## Run it

**Backend** (needs Node.js 20+; it starts a temporary in-memory MongoDB with the quotes loaded):

```bash
cd backend
npm install
cp .env.example .env     # Windows: Copy-Item .env.example .env
npm run dev:local        # http://localhost:3000/api
```

**App** (Flutter stable, Android emulator or phone):

```bash
flutter pub get
flutter run              # the emulator reaches the API at http://10.0.2.2:3000/api
```

Use another server with `flutter run --dart-define=API_BASE_URL=https://your-host/api`.

**APK:** `flutter build apk --debug` writes `build/app/outputs/flutter-apk/app-debug.apk`; install it with `adb install -r <file>`.

The app works without the backend: guests keep everything on the device and the quote library falls back to the bundled quotes. Signing in, sync and the AI coach need the API.

**AI coach (optional):** set `GEMINI_API_KEY` in `backend/.env`. Leave it empty to switch the AI features off.

## API and Postman

Import [docs/postman/MindSpark.postman_collection.json](docs/postman/MindSpark.postman_collection.json). Run **Register** or **Login** first and it stores the token in `{{token}}`. All routes are listed in the README under "API overview".

## Tests

```bash
flutter analyze && flutter test
cd backend && npm test
```

## Limitations and next steps

- If the same goal is changed offline on two devices, the later change wins.
- Reminders use inexact alarms, so they can arrive a few minutes late when the phone saves battery.
- The API is live on Render's free tier with MongoDB Atlas (<https://mindspark-api-xqpn.onrender.com/api>). It sleeps after 15 minutes idle, so the first request can take about a minute.
- The local development database is in memory.
- Gemini's free tier has small limits, and goal text sent to the AI goes to Google. The app says so next to the AI buttons.
