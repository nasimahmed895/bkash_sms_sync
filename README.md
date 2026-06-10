# bKash SMS Payment Verification & Webhook Sync

A production-grade Flutter Android app that captures bKash received-payment
SMS messages, stores them locally, and guarantees delivery to your backend
webhook — even through app kills, reboots, and offline periods.

## How the "no payment can ever be lost" guarantee works

```
Incoming SMS
   │
   ├─ keyword + regex validation (received / Tk / Balance / TrxID)
   │     └─ not bKash? → ignored, no API call
   │
   ├─ INSERT INTO payments ... (trxID UNIQUE)        ← persisted FIRST
   │     └─ duplicate trxID? → ignored, no webhook
   │
   ├─ status = pending_sync
   │
   ├─ immediate webhook attempt (if online)
   │     ├─ success            → status = synced, store backend id
   │     ├─ backend "failed"   → status = failed (backend owns it)
   │     └─ transient error    → stays pending_sync, retry scheduled
   │
   └─ WorkManager retry chain: 30s → 1m → 5m → 15m → 30m → 1h → every 6h
        (network-constrained, survives reboot & app kill)
```

Three independent recovery paths cover every failure scenario:

1. **Background SMS isolate** (`another_telephony` `onBackgroundMessage`) —
   captures and persists SMS even when the Flutter app is killed.
2. **WorkManager** — escalating one-off retries plus a 6-hour periodic
   safety-net task with `NetworkType.connected` constraint. Reschedules
   itself after reboot (RECEIVE_BOOT_COMPLETED is registered by the plugin).
3. **Connectivity listener** — flushes the pending queue the instant
   internet returns while the app is alive.

Duplicate protection is enforced at the database level: `trxID` has a
`UNIQUE` constraint with `ConflictAlgorithm.ignore`, which is safe across
all isolates.

## Project structure (Clean Architecture)

```
lib/
├── core/                  constants, logger, SMS parser
├── domain/
│   ├── entities/          Payment, SyncStatus, PaymentStats
│   └── repositories/      PaymentRepository (abstract)
├── data/
│   ├── local/             PaymentDb (sqflite, UNIQUE trxID)
│   ├── remote/            ApiClient (Dio, typed WebhookResult)
│   ├── models/            PaymentListItem (remote list)
│   └── repositories/      PaymentRepositoryImpl
├── services/
│   ├── sms_service.dart           SMS capture (fg + bg entry point)
│   ├── sync_engine.dart           queue → webhook delivery
│   ├── background_tasks.dart      WorkManager dispatcher + scheduling
│   ├── connectivity_service.dart  instant flush on internet recovery
│   └── service_locator.dart       GetIt (idempotent, isolate-safe)
└── presentation/
    ├── providers/          Riverpod state (stats, list, search, filter)
    ├── screens/            Dashboard, Payment List
    └── widgets/            PaymentTile (copy / call actions)
```

## Setup

1. **Create platform scaffolding** (this repo ships `lib/`, `pubspec.yaml`,
   manifest, MainActivity, and tests; generate the rest of the Android
   boilerplate in place):

   ```bash
   flutter create --org com.example --platforms android .
   ```

   Then re-check that `android/app/src/main/AndroidManifest.xml` still
   contains the SMS/boot/network permissions from this repo (flutter create
   won't overwrite existing files, but verify).

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure your backend** in `lib/core/constants.dart`:
   - `baseUrl` → your real API host (HTTPS only)
   - `bkashSenderIds` → confirm the sender IDs your SIM actually receives

4. **Gradle requirements** (`android/app/build.gradle`):
   - `minSdkVersion 26` (Android 8+)
   - `targetSdkVersion 34` (or latest stable)

5. **Run tests**

   ```bash
   flutter test
   ```

6. **Build**

   ```bash
   flutter build apk --release
   ```

## Important notes

- **Google Play policy**: apps using `RECEIVE_SMS` / `READ_SMS` are heavily
  restricted on the Play Store (reserved for default SMS handlers and a few
  approved use cases). Plan to distribute this APK privately (direct
  install / MDM / internal distribution), which matches the typical bKash
  merchant verification use case.
- **Battery optimization**: on aggressive OEMs (Xiaomi, Oppo, Vivo, etc.),
  ask the user to exclude the app from battery optimization so WorkManager
  and the SMS receiver fire reliably. `permission_handler`'s
  `Permission.ignoreBatteryOptimizations` can prompt for this.
- **Sender verification**: messages matching the bKash pattern but from an
  unknown sender are currently stored with a warning log. To hard-reject
  them, return early in `handleIncomingSms` when
  `isKnownBkashSender` is false.
- **HTTPS only**: `usesCleartextTraffic="false"` is set in the manifest;
  Dio talks to `https://` endpoints only.

## API contract

- `POST /webhook/verification-payment` — body:
  `{ number, amount, balance, trxID, at }`
  - `status: success` → store `data.id`, mark `synced`, never retry
  - `status: failed` → mark `failed`, stop retrying (backend handles it)
  - anything else / network error → stays `pending_sync`, retried
- `GET /api/payment-list?page=N` — powers the Payment List screen
  (pull-to-refresh, search, status filters, infinite-scroll pagination).
