# TakaID — Bangladeshi Banknote Identifier

A Flutter application that **identifies Bangladeshi banknotes on-device** using a TFLite deep learning model and reads the result aloud in Bengali. Scan history is persisted locally via SQLite and synced to a Node.js/Express backend backed by Supabase (PostgreSQL + Storage).

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup — Flutter App](#setup--flutter-app)
- [Setup — Backend](#setup--backend)
- [Database Schema](#database-schema)
- [TFLite Model](#tflite-model)
- [API Reference](#api-reference)
- [State Management](#state-management)
- [Key Files](#key-files)

---

## Features

| Feature | Details |
|---|---|
| **On-device inference** | TFLite model classifies 9 Bangladeshi denominations (2 ৳ → 1000 ৳) with no internet required |
| **Bengali TTS** | Announces the detected denomination in Bengali using `flutter_tts` |
| **Top-3 confidence** | Shows a ranked confidence breakdown for the top 3 predictions |
| **Auth (Supabase)** | Email/password sign-up and login; history is user-scoped |
| **Offline-first history** | Records saved to local SQLite (`sqflite`) immediately; synced to backend in the background when authenticated |
| **Cloud sync** | Banknote images uploaded to Supabase Storage; metadata stored in PostgreSQL |
| **Optimistic UI** | New scans appear instantly in history with an `isSynced: false` badge; replaced by confirmed server record on success |
| **Detail view** | Full-screen image, confidence badge, top-K breakdown, timestamp, delete with confirm |

---

## Architecture

```
Flutter app (Riverpod)
  ├── BanknoteClassifier  — on-device TFLite inference
  ├── LocalDb (sqflite)   — offline-first source of truth
  └── ApiService (Dio)    — authenticated HTTP to Express backend
          │  Bearer JWT (Supabase access token)
          ▼
  Express.js REST API  (backend/src/, port 3000)
  ├── verifyToken middleware  — validates Supabase JWT
  ├── multer                 — multipart image upload → temp disk
  └── Supabase SDK (service role)
          │
          ▼
  Supabase
  ├── PostgreSQL  — history_records table (user-scoped, RLS enabled)
  └── Storage     — banknotes bucket (public read, service-role write)
```

---

## Tech Stack

### Flutter App

| Package | Purpose |
|---|---|
| `flutter_riverpod ^2.6.1` | State management |
| `tflite_flutter ^0.11.0` | On-device TFLite inference |
| `image ^4.2.0` | Image decoding & resize for model preprocessing |
| `supabase_flutter ^2.8.4` | Auth (sign-in/sign-up, session management) |
| `sqflite ^2.4.1` | Local SQLite persistence (offline history) |
| `dio ^5.7.0` | HTTP client for backend API |
| `flutter_tts ^4.2.5` | Bengali text-to-speech |
| `image_picker ^1.1.2` | Camera & gallery image selection |
| `intl ^0.20.1` | Date formatting |
| `loading_animation_widget ^1.3.0` | Loading animations |

### Backend

| Package | Purpose |
|---|---|
| `express ^4.21.2` | REST API server |
| `@supabase/supabase-js ^2.49.1` | Supabase DB & Storage client (service role) |
| `multer ^1.4.5-lts.1` | Multipart file upload |
| `cors ^2.8.5` | Cross-origin resource sharing |
| `morgan ^1.10.0` | HTTP request logging |
| `dotenv ^16.4.7` | Environment variable loading |
| `nodemon ^3.1.9` | Dev hot-reload |

---

## Project Structure

```
taka_id/
├── lib/
│   ├── main.dart                             # App entry point, Supabase init
│   ├── config/
│   │   └── supabase_config.dart              # Supabase URL + anon key (gitignored)
│   ├── models/
│   │   └── classification_record.dart        # ClassificationRecord + TopResult models
│   ├── providers/
│   │   ├── auth_provider.dart                # Supabase auth state, currentUser, accessToken
│   │   ├── classifier_provider.dart          # AsyncNotifier wrapping BanknoteClassifier
│   │   └── history_provider.dart             # AsyncNotifier: sqflite + backend sync
│   ├── services/
│   │   ├── classifier.dart                   # TFLite inference + image preprocessing
│   │   ├── api_service.dart                  # Dio HTTP client (CRUD on /api/history)
│   │   └── local_db.dart                     # sqflite wrapper (upsert / query / delete)
│   ├── screens/
│   │   ├── home_screen.dart                  # Camera/gallery scan + TTS result display
│   │   ├── history_screen.dart               # Authenticated scan history list
│   │   ├── detail_screen.dart                # Full record detail + delete
│   │   └── auth_screen.dart                  # Login / Sign-up form (Supabase Auth)
│   └── widgets/
│       ├── confidence_bar.dart               # Animated confidence progress bar
│       ├── history_tile.dart                 # History list item tile
│       └── app_loader.dart                   # Full-screen / overlay loading indicator
├── assets/
│   ├── labels.txt                            # 9 class labels (one per line)
│   └── model/
│       └── banknote_classifier.tflite        # Active TFLite model
├── backend/
│   ├── .env                                  # Runtime secrets (not committed)
│   ├── package.json
│   └── src/
│       ├── server.js                         # HTTP server bootstrap
│       ├── app.js                            # Express app, middleware, routes
│       ├── routes/history.js                 # Route definitions for /api/history
│       ├── controllers/historyController.js  # Request handlers (CRUD + image upload)
│       ├── middleware/
│       │   ├── verifyToken.js                # Supabase JWT validation middleware
│       │   └── upload.js                     # Multer config (10 MB, JPEG/PNG/WebP)
│       └── lib/supabase.js                   # Supabase client (service role)
│   └── supabase/
│       └── schema.sql                        # Idempotent DB + Storage setup script
└── tools/
    └── convert_model.py                      # Keras → TFLite conversion utility
```

---

## Prerequisites

- **Flutter** >= 3.x (SDK `^3.10.4`)
- **Dart** >= 3.x
- **Node.js** >= 18 and **npm**
- A **Supabase** project (free tier works)
- Android emulator, iOS simulator, or a physical device

---

## Setup — Flutter App

### 1. Install dependencies

```bash
git clone <repo-url>
cd taka_id
flutter pub get
```

### 2. Configure Supabase credentials

```bash
cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart
```

Edit `lib/config/supabase_config.dart`:

```dart
abstract final class SupabaseConfig {
  static const String url     = 'https://YOUR_PROJECT_REF.supabase.co';
  static const String anonKey = 'YOUR_ANON_KEY_HERE'; // Publishable key only
}
```

> Find these in **Supabase Dashboard → Project Settings → API Keys**.

### 3. Configure the backend URL

Edit the `baseUrl` constant in `lib/services/api_service.dart`:

| Environment | URL |
|---|---|
| Android emulator | `http://10.0.2.2:3000/api` *(default)* |
| iOS simulator | `http://localhost:3000/api` |
| Physical device | `http://<YOUR_LAN_IP>:3000/api` |
| Production | `https://your-domain.com/api` |

### 4. Run the app

```bash
flutter run          # pick device interactively
flutter build apk    # Android release APK
```

---

## Setup — Backend

### 1. Install dependencies

```bash
cd backend
npm install
```

### 2. Create the environment file

Create `backend/.env` (do **not** commit this file):

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SECRET_KEY=<service_role_key>
SUPABASE_STORAGE_BUCKET=banknotes
PORT=3000
```

> The **service role key** is at **Supabase Dashboard → Project Settings → API Keys → Secret key**. Never expose it to the Flutter client.

### 3. Initialise the database

Run `backend/supabase/schema.sql` once in **Supabase Dashboard → SQL Editor**. The script is idempotent and safe to re-run. It creates:

- `public.history_records` table with RLS policies
- `banknotes` public storage bucket
- Indexes on `timestamp` and `user_id`

### 4. Start the server

```bash
npm run dev    # hot-reload via nodemon (development)
npm start      # production
```

The server listens on `http://localhost:3000`.  
**Health check:** `GET /health` → `{ "status": "ok" }`

---

## Database Schema

```sql
public.history_records
  id               uuid        PK   default gen_random_uuid()
  user_id          uuid        FK → auth.users(id)  ON DELETE CASCADE
  label            text        NOT NULL
  confidence       float8      CHECK (0 <= confidence <= 1)
  top_results      jsonb       default '[]'
  image_url        text        (Supabase Storage public URL)
  local_image_path text        (device-side absolute path)
  timestamp        timestamptz default now()
  created_at       timestamptz default now()
```

**Row Level Security** is enabled. The Express backend uses the **service role key** which bypasses RLS. Direct Supabase Studio / client queries are restricted to `auth.uid() = user_id`.

---

## TFLite Model

### Supported denominations (9 classes)

`2 ৳` · `5 ৳` · `10 ৳` · `20 ৳` · `50 ৳` · `100 ৳` · `200 ৳` · `500 ৳` · `1000 ৳`

### Model configuration (`lib/services/classifier.dart`)

| Constant | Value | Notes |
|---|---|---|
| `inputSize` | `128` | Model expects 128×128 RGB input |
| `confidenceThreshold` | `0.40` | Below this → reported as "Not a Banknote" |
| `modelHasBuiltInRescaling` | `false` | Preprocessing is done in-app |
| `useMobileNetNormalization` | `false` | MobileNet [-1, 1] normalisation off |
| `useResNet50Preprocessing` | `false` | ResNet50 caffe-mode off |

**Default preprocessing:** raw pixel values scaled to `[0, 1]` (`pixel / 255.0`).

### Replacing the model

1. Convert your Keras model:
   ```bash
   python tools/convert_model.py --model path/to/model.keras \
                                  --output assets/model/banknote_classifier.tflite
   ```
2. Update `assets/labels.txt` — one class name per line, matching the model's output order.
3. Update `inputSize` and the preprocessing flags in `lib/services/classifier.dart` to match your training pipeline.

---

## API Reference

All `/api/history` routes require `Authorization: Bearer <supabase_access_token>`.

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Health check (no auth required) |
| `POST` | `/api/history` | Save a new classification record + image (multipart/form-data) |
| `GET` | `/api/history` | List all records for the authenticated user (newest first) |
| `GET` | `/api/history/:id` | Get a single record by UUID |
| `DELETE` | `/api/history/:id` | Delete a record and its image from Storage |

### POST `/api/history` — multipart fields

| Field | Type | Notes |
|---|---|---|
| `image` | file | JPEG / PNG / WebP, max 10 MB |
| `label` | string | Top predicted class name |
| `confidence` | string | Float encoded as string, e.g. `"0.9732"` |
| `topResults` | string | **JSON-encoded** array of `{label, confidence}` objects |
| `timestamp` | string | ISO 8601 datetime string |
| `localImagePath` | string | Device-side absolute file path |

> `topResults` must be sent as a JSON string because multipart form data does not support nested objects directly.

### Response shape

```json
{
  "success": true,
  "data": {
    "_id": "uuid",
    "label": "100 Taka",
    "confidence": 0.9732,
    "topResults": [{ "label": "100 Taka", "confidence": 0.9732 }],
    "imageUrl": "https://<project>.supabase.co/storage/v1/object/public/banknotes/banknote_xxx.jpg",
    "localImagePath": "/data/user/0/.../cache/image.jpg",
    "timestamp": "2026-03-11T10:00:00.000Z"
  }
}
```

---

## State Management

The app uses **Riverpod** with `AsyncNotifier` throughout. All state lives in providers — screens are as thin as possible.

| Provider | Type | Responsibility |
|---|---|---|
| `classifierProvider` | `AsyncNotifierProvider` | Loads TFLite model in `build()`, runs inference, disposes interpreter on disposal |
| `historyProvider` | `AsyncNotifierProvider` | Reads sqflite on startup; background-syncs with backend when authenticated |
| `apiServiceProvider` | `Provider` | Singleton `ApiService`; rebuilt whenever the auth token changes |
| `supabaseClientProvider` | `Provider` | Raw `SupabaseClient` |
| `authStateProvider` | `StreamProvider` | Live stream of auth state changes (login / logout / token refresh) |
| `currentUserProvider` | `Provider<User?>` | Currently authenticated user or `null` |
| `accessTokenProvider` | `Provider<String?>` | Current session JWT injected into every API request |
| `localDbProvider` | `Provider<LocalDb>` | SQLite database singleton |

### Offline-first write path

```
User scans a banknote
  │
  ├─ 1. Record saved to sqflite immediately  (isSynced: false)
  ├─ 2. Optimistically prepended to in-memory history list
  └─ 3. If user is authenticated → POST to backend
           ✓ Success: sqflite row updated with server id + imageUrl
                      in-memory placeholder swapped for confirmed record
           ✗ Failure: local-only record retained silently
                      survives app restart via sqflite
```

---

## Key Files

| Purpose | File |
|---|---|
| App entry point | `lib/main.dart` |
| TFLite inference + preprocessing | `lib/services/classifier.dart` |
| Backend HTTP client | `lib/services/api_service.dart` |
| SQLite offline store | `lib/services/local_db.dart` |
| Classifier state + notifier | `lib/providers/classifier_provider.dart` |
| History state + sync notifier | `lib/providers/history_provider.dart` |
| Auth providers | `lib/providers/auth_provider.dart` |
| Shared data models | `lib/models/classification_record.dart` |
| Home / scan screen | `lib/screens/home_screen.dart` |
| History list screen | `lib/screens/history_screen.dart` |
| Detail view screen | `lib/screens/detail_screen.dart` |
| Login / sign-up screen | `lib/screens/auth_screen.dart` |
| Express app + middleware | `backend/src/app.js` |
| History CRUD controller | `backend/src/controllers/historyController.js` |
| JWT verification middleware | `backend/src/middleware/verifyToken.js` |
| Supabase client (service role) | `backend/src/lib/supabase.js` |
| DB + Storage schema | `backend/supabase/schema.sql` |
| Keras → TFLite converter | `tools/convert_model.py` |
