# Taka ID — Copilot Instructions

## Project Overview
Flutter app that classifies Bangladeshi banknotes via on-device TFLite inference, with an Express.js backend persisting scan history to Supabase (PostgreSQL + Storage).

## Architecture

```
Flutter app (Riverpod)
  ├── BanknoteClassifier (on-device TFLite, lib/services/classifier.dart)
  └── ApiService (Dio → Express backend, lib/services/api_service.dart)
          │
          ▼
  Express.js (backend/src/, port 3000)
          │
          ▼
  Supabase (PostgreSQL table: history_records, Storage bucket: banknotes)
```

## Critical Domain Rules

### TFLite Model
- Input: `224×224` RGB, **raw `[0,255]` float32** — the model has a built-in `Rescaling` layer. Do NOT normalise in app code (`modelHasBuiltInRescaling = true` in [lib/services/classifier.dart](../lib/services/classifier.dart)).
- To replace the model: run `python tools/convert_model.py --model path/to/model.keras --output assets/model/banknote_classifier.tflite`, then update `assets/labels.txt` to match new class names.

### Backend URL (must match environment)
Defined in [lib/services/api_service.dart](../lib/services/api_service.dart):
- Android emulator → `http://10.0.2.2:3000/api`
- iOS simulator → `http://localhost:3000/api`
- Physical device → `http://<LAN_IP>:3000/api`

### Optimistic History Updates
`HistoryNotifier.addRecord()` in [lib/providers/history_provider.dart](../lib/providers/history_provider.dart) immediately prepends a record with `isSynced: false` before the backend responds. On success it swaps in the server record (with `id` and `imageUrl`). On failure it retains the local-only record silently. When deleting an unsynced record (`id == null`), only the local list is updated.

**Planned:** Unsynced records will be persisted across app restarts via `sqflite`. When implementing, the local DB should mirror `ClassificationRecord` fields and be the source of truth on startup, syncing to the backend when online. The `isSynced` flag is already designed for this two-phase write path.

### Multipart Upload Quirk
`topResults` is JSON-encoded to a string in the `FormData` and parsed back by the controller — it cannot be sent as a nested object in multipart form.

## Planned Features

### Authentication (Login / Signup)
History is planned to be user-scoped. When implementing:
- Use **Supabase Auth** (already available via `@supabase/supabase-js` in the backend) — avoid introducing a separate auth service.
- The Flutter client will need an `authProvider` holding the current session; `historyProvider` should depend on it and only fetch/sync when a user is authenticated.
- The backend will need to scope all `/api/history` queries by `user_id`. Add a `user_id uuid references auth.users` column to `history_records` and update RLS policies in [backend/supabase/schema.sql](../backend/supabase/schema.sql) accordingly.
- The service role key (backend) already bypasses RLS — JWT validation for user-scoped requests should be done in Express middleware, not by relying on RLS alone.
- History screen should be gated: unauthenticated users see a login prompt instead of the list.

### Offline Persistence (sqflite)
Unsynced records will survive app restarts via a local SQLite database. When implementing:
- Schema should mirror `ClassificationRecord` with an extra `is_synced INTEGER` column.
- `HistoryNotifier.build()` should read from sqflite first, then attempt a background sync with the backend.
- Keep `isSynced: false` records in sqflite until the server confirms with an `id`; then update the row.

## State Management (Riverpod)
- `classifierProvider` — `AsyncNotifier<ClassifierState>` (loads model in `build()`, disposes interpreter on provider disposal)
- `historyProvider` — `AsyncNotifier<List<ClassificationRecord>>` (fetches from backend in `build()`, falls back to `[]` when offline)
- `apiServiceProvider` — plain `Provider<ApiService>` (singleton)
- Screens use `ConsumerStatefulWidget` only when `mounted`-safe async calls are needed (e.g. `HomeScreen`); otherwise `ConsumerWidget`.

## Backend Setup
```bash
cd backend
npm install
npm run dev                   # nodemon hot-reload
```
Create `backend/.env` with these required variables (`.env.example` is a template reference only):
```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_SECRET_KEY=<service_role_key>
SUPABASE_STORAGE_BUCKET=banknotes
PORT=3000
```
Run `backend/supabase/schema.sql` once in Supabase SQL Editor to create the `history_records` table and `banknotes` storage bucket. The backend uses the **service role key** (bypasses RLS) — never expose it to the Flutter client.

> **Note:** `backend/src/models/HistoryRecord.js` is a Mongoose schema leftover from an earlier MongoDB version and is no longer used. The active persistence layer is Supabase via `backend/src/lib/supabase.js`.

## Flutter Dev Commands
```bash
flutter pub get
flutter run                   # pick device interactively
flutter build apk             # Android release
```

## Key Files
| Purpose | File |
|---|---|
| TFLite inference + preprocessing | [lib/services/classifier.dart](../lib/services/classifier.dart) |
| Backend HTTP client | [lib/services/api_service.dart](../lib/services/api_service.dart) |
| Classification state | [lib/providers/classifier_provider.dart](../lib/providers/classifier_provider.dart) |
| History + sync state | [lib/providers/history_provider.dart](../lib/providers/history_provider.dart) |
| Shared data model | [lib/models/classification_record.dart](../lib/models/classification_record.dart) |
| Express app entry | [backend/src/app.js](../backend/src/app.js) |
| Supabase DB schema | [backend/supabase/schema.sql](../backend/supabase/schema.sql) |
| Model converter | [tools/convert_model.py](../tools/convert_model.py) |
