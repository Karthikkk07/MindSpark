# MindSpark

A motivation app for Android: a daily quote on your home screen, a searchable quote library, goals with streaks, and optional accounts that sync across devices. Built with Flutter, Kotlin and a Node.js API.

## Screenshots

| Home | Library | Goals | Goal detail | Settings |
|---|---|---|---|---|
| ![Home](docs/screenshots/home.png) | ![Library](docs/screenshots/library.png) | ![Goals](docs/screenshots/goals.png) | ![Goal detail](docs/screenshots/goal-detail.png) | ![Settings](docs/screenshots/settings.png) |

## Features

- **Daily quote** on Home, chosen from the interests you pick during onboarding.
- **Quote library**: loaded from the API and saved on the device (pull down to refresh, bundled quotes as the offline fallback). Search by text, author or tag, category filters, three sort orders, detail view.
- **Favorites** and **native share**.
- **Android home-screen widget** (small and medium) with a Next button and a deep link into the app. Works offline from a native cache.
- **Goals**: a daily action, milestones, a target date, daily check-ins, and current and longest streaks. A check-in yesterday keeps a streak alive.
- **Daily reminder**: a notification with a quote at a time you choose, including the Android 13 permission flow.
- **Accounts** (optional): sign up and sign in, session kept in secure storage. Favorites, settings and goals sync to your account and work offline.
- **AI goal coach** (signed-in users): "Suggest with AI" proposes a daily action and milestones for a goal, and "Encourage me" writes a short note from a goal's streak and progress. It runs through the backend, so the Gemini key never reaches the phone.
- **Privacy-first analytics** (opt-in): anonymous usage events and crash reports through Firebase Analytics and Crashlytics. Both are off until the user turns on **Settings > Privacy**. Events carry no goal text, quotes, names or emails.
- **Push notifications** (signed-in users, opt-in): Firebase Cloud Messaging. The phone registers its token with the API, and the server sends through the Firebase Admin SDK.
- Light and dark themes. The app is fully usable as a guest.

## Tech stack

| Part | Technology |
|---|---|
| App | Flutter (Material 3), Riverpod, go_router, shared_preferences, flutter_secure_storage, Firebase (Analytics, Crashlytics, Cloud Messaging) |
| Android native | Kotlin: share sheet, home-screen widget, reminder alarm and notification (platform channels) |
| API | Node.js, Express, Mongoose (MongoDB), zod, JWT, bcryptjs, helmet, express-rate-limit, pino |
| Tests | Flutter test, Jest, supertest, mongodb-memory-server |
| CI | GitHub Actions |

## How it fits together

The app is **local-first**: everything works offline and is saved on the device. Signed-in users additionally sync with the API. Per goal, the newer change wins. Check-ins are calendar dates (YYYY-MM-DD) in the user's own time zone, so streaks do not depend on UTC offsets.

## Getting started

Requirements: Flutter (stable), Node.js 20 or newer, an Android emulator or phone.

**Backend** (no database setup needed for development; it starts a temporary in-memory MongoDB with the quotes loaded):

```bash
cd backend
npm install
cp .env.example .env        # Windows: Copy-Item .env.example .env
# set JWT_SECRET to a random string of at least 32 characters
npm run dev:local
npm test
```

**App**:

```bash
flutter pub get
flutter run                 # the Android emulator reaches the API at http://10.0.2.2:3000/api
flutter analyze
flutter test
```

To use another API address:

```bash
flutter run --dart-define=API_BASE_URL=https://your-host.example/api
```

Plain HTTP is allowed in debug builds only (see `android/app/src/debug/AndroidManifest.xml`).

The API is deployed on Render (free tier) with MongoDB Atlas: <https://mindspark-api-xqpn.onrender.com/api/health>. After 15 minutes idle the instance sleeps, so the first request can take about a minute. To deploy your own copy, follow [docs/DEPLOY.md](docs/DEPLOY.md).

**Download the app:** [MindSpark-1.0.0.apk](https://github.com/Karthikkk07/MindSpark/releases/download/v1.0.0/MindSpark-1.0.0.apk) (Android; allow "Install unknown apps" when asked).

Release APK, pointed at the live API:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://mindspark-api-xqpn.onrender.com/api
```

Signing reads `android/key.properties` (git-ignored). Without it the release build falls back to the debug key.

## API overview

All JSON. Protected routes need `Authorization: Bearer <token>`. A Postman collection is in [docs/postman](docs/postman/MindSpark.postman_collection.json). Submission notes: [SUBMISSION.md](SUBMISSION.md).

| Area | Endpoints |
|---|---|
| Health | `GET /api/health` |
| Quotes | `GET /api/quotes` (search, category, sort, page), `/random`, `/categories`, `/category/:category`, `/:id` |
| Auth | `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me` |
| Account | `GET` and `PATCH /api/users/preferences`, `DELETE /api/users/me` |
| Favorites | `GET /api/favorites`, `POST /api/favorites/merge`, `POST` and `DELETE /api/favorites/:quoteId` |
| Goals | `GET` and `POST /api/goals`, `GET`, `PATCH`, `PUT` and `DELETE /api/goals/:id`, `POST /api/goals/:id/check-ins`, `DELETE /api/goals/:id/check-ins/:date` |
| AI | `POST /api/ai/goal-suggestions`, `POST /api/ai/encouragement` (signed in, limited per user per day) |
| Push | `POST /api/devices` (register this phone's token), `POST /api/devices/unregister`, `POST /api/devices/test` (sends a test push to your devices; 503 if push is not set up) |

## Configuration (backend)

| Variable | Meaning | Default |
|---|---|---|
| `JWT_SECRET` | Signing secret, at least 32 characters | required |
| `MONGODB_URI` | MongoDB connection string | none (needed for `npm start`) |
| `PORT` | HTTP port | 3000 |
| `CORS_ORIGIN` | Allowed browser origins, comma separated | none |
| `RATE_LIMIT_MAX` | Requests per 15 minutes per IP | 100 |
| `AUTH_RATE_LIMIT_MAX` | Sign-in and sign-up attempts per 15 minutes per IP | 20 |
| `JWT_EXPIRES_IN` | Token lifetime | 7d |
| `BCRYPT_ROUNDS` | Password hashing cost | 12 |
| `LOG_LEVEL` | pino level | info |
| `TRUST_PROXY` | Number of reverse proxies in front of the API (use 1 on Render) | 0 |
| `GEMINI_API_KEY` | Google Gemini key. Leave empty to switch the AI features off | none |
| `GEMINI_MODEL` | Gemini model id. If you get a "not found" error, copy a current id from Google AI Studio | gemini-3.1-flash-lite |
| `AI_DAILY_LIMIT` | AI requests per user per day | 10 |
| `AI_TIMEOUT_MS` | Time to wait for Gemini | 30000 |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Path to the Firebase service-account key file. On Render, a secret file named `firebase-service-account.json` is found automatically | none |
| `FIREBASE_SERVICE_ACCOUNT` | The same key as JSON text (alternative to the path). Leave both empty to switch push off | none |

## Firebase setup

The Firebase config files are private and not in git.

1. Create a Firebase project and add an Android app with package `com.karthik.mindspark`.
2. Save `google-services.json` to `android/app/`. Without it the app still builds and runs, and Firebase is simply off.
3. For server push, generate a service-account key (Project settings > Service accounts) and give it to the API through the variables above. Never commit it.
4. Collection stays off until the user opts in under Settings > Privacy. Crashlytics shows a first report after the first crash with the switch on.

## Security notes

- Passwords are hashed with bcrypt. The JWT algorithm is pinned (HS256) and tokens are checked against the stored account.
- Every request body is validated with zod and rejects unknown fields. Every user-owned query is scoped to the signed-in user, and another user's data answers 404.
- Auth endpoints are rate limited. Security headers come from helmet.
- AI requests need an account and are limited per user per day (the count is stored in the database). Goal text goes to the model as JSON data, the reply is parsed, cleaned and length-capped on the server, and suggestions only fill editable fields after the user taps "Use suggestions". Upstream errors become generic messages, and prompts and goal text are not logged.
- The app keeps its session in the Android Keystore through flutter_secure_storage. No secrets are stored in the repository.

## Limitations

- If the same goal is changed on two devices while both are offline, the later change wins and the other is lost.
- Sync times come from device clocks. The server rejects times far in the future.
- Reminders use inexact alarms (no special permission), so they can arrive a few minutes late when the phone saves battery.
- The development database is in memory, so accounts disappear when the dev server stops.
- Goal text sent to the AI goes to Google Gemini. Free-tier content may be used by Google to improve its products, so check the current terms before putting sensitive text in a goal. The free tier's limits apply to the whole project, so a few users can use them up.

## Roadmap

Uptime monitoring and a Play Store release.

## License

MIT. See [LICENSE](LICENSE).
