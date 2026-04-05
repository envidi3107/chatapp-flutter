# Contributor Guide

This guide helps coding agents and contributors work safely in the Chat App Flutter client.

## Table of Contents

1. Policies & Mandatory Rules
2. Project Structure Guide
3. Operation Guide

## Policies & Mandatory Rules

### Platform Rules

- Use conditional imports for platform-specific code (web vs native).
- Guard native-only calls with `kIsWeb` checks.
- Do not call native Firebase APIs directly from web-only code paths.

### Dependency Injection and State Rules

- Register shared services with `Provider.value()`.
- Keep provider wiring centralized in `lib/app.dart`.
- Keep app bootstrap and service initialization in `lib/main.dart`.

### Configuration Rules

- Load runtime environment values with `--dart-define-from-file=.env.json`.
- If config keys change, update `.env.example.json` and `README.md` in the same change.
- Never commit real API keys or private credentials.

### Build Before Commit Rule

- **ALWAYS build before commit**: run `flutter analyze` and ensure no errors.
- **Check for Android SDK**: run `flutter doctor --android-licenses --dry-run` or check if `ANDROID_HOME` is set. If Android SDK is available, also run `flutter build apk --debug` and ensure it passes before committing.

## Project Structure Guide

### Repo Layout

- `lib/main.dart`: App startup and service initialization.
- `lib/app.dart`: Provider graph, app shell, and navigation bootstrap.
- `lib/services/`: API, realtime, FCM, notifications, and domain services.
- `lib/providers/`: App state and screen-level orchestration.
- `lib/screens/`: UI screens by feature.

### Tech Stack

- Flutter + Provider.
- HTTP REST + STOMP real-time messaging.
- Firebase Cloud Messaging + local notifications.
- Android package: `com.group10.chatappflutter`.

## Operation Guide

### Common Commands

- Install deps: `flutter pub get`.
- Run Android: `flutter run -d android --dart-define-from-file=.env.json`.
- Run Web: `flutter run -d chrome --dart-define-from-file=.env.json`.
- Analyze: `flutter analyze`.
- Test: `flutter test`.

### Change Checklist

- Ensure mobile and web paths both compile after platform-specific edits.
- Keep new services injectable and testable via providers.
- Validate notification and realtime flows when touching messaging features.
