# DateApp Mobile

**Talk first. Reveal later.**

A production-grade social dating app built with Flutter. Anonymous text and voice matching, discovery feed, messaging, and safety-first architecture.

## Architecture

This Flutter app is the **UI layer only**. All business logic lives in the NestJS backend (`datingapp-backend`). Flutter calls REST APIs and listens to WebSocket events — it does not make matching, moderation, or premium access decisions.

```
Flutter  →  REST (Dio)  →  NestJS
Flutter  →  WebSocket (socket_io_client)  →  NestJS /match and /messages namespaces
Flutter  →  Supabase Auth (session tokens only)
Flutter  →  Supabase Storage (photo uploads)
```

## Setup

### 1. Environment variables

Copy `.env.example` to `.env` and fill in your real values:

```bash
cp .env.example .env
```

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Your Supabase anon/public key |
| `BACKEND_BASE_URL` | NestJS backend URL (e.g. `http://localhost:3000`) |

> `.env` is git-ignored. Never commit real keys.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run

```bash
flutter run
```

Target a specific device:

```bash
flutter run -d ios       # iOS simulator
flutter run -d android   # Android emulator
```

### 4. Code generation (Riverpod providers)

```bash
dart run build_runner build --delete-conflicting-outputs
# or watch mode during development:
dart run build_runner watch --delete-conflicting-outputs
```

## Tech stack

| Layer | Technology |
|---|---|
| State management | Riverpod + riverpod_generator |
| Navigation | GoRouter |
| HTTP client | Dio (JWT auto-attached via interceptor) |
| Auth session | Supabase Flutter SDK |
| Secure storage | flutter_secure_storage |
| WebSocket | socket_io_client |
| Image display | cached_network_image |
| Image upload | image_picker |
| Env config | flutter_dotenv |

## Folder structure

```
lib/
  core/
    constants/      # App-wide constants
    error/          # Exception types
    network/        # Dio client + JWT interceptor
    router/         # GoRouter configuration
    theme/          # AppTheme (dark-first)
    utils/          # Shared utilities
  features/
    auth/           # Supabase Auth integration
    onboarding/     # Profile completion flow
    discover/       # Discovery feed
    match/
      text_match/   # Anonymous text matching UI
      voice_match/  # Anonymous voice matching UI
    messages/       # Permanent conversations + chat
    profile/        # User profile view/edit
  shared/
    widgets/        # Reusable UI components
    models/         # Data models (mirrors backend API contracts)
```

## Backend

This app connects to the `datingapp-backend` NestJS service. API contracts are defined in `docs/API_CONTRACTS.md` and WebSocket events in `docs/REALTIME_EVENTS.md` in the backend repository.

## Orientation

Portrait-only. Landscape is disabled app-wide at startup — this is a firm product decision.
