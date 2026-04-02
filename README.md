# messenger_app

Flutter chat app currently configured to support only `android` and `web`.

## Environment config

This project reads environment values via Flutter `--dart-define-from-file`.

1. Copy `/.env.example.json` to `/.env.json`.
2. Update the values in `/.env.json`.
3. Run Flutter with `--dart-define-from-file=.env.json`.

Example file:

```json
{
  "API_BASE_URL": "http://10.0.2.2:8080"
}
```

Example commands:

```bash
flutter run -d android --dart-define-from-file=.env.json
flutter run -d chrome --dart-define-from-file=.env.json
flutter analyze
```

Notes:

- Android emulator usually needs `http://10.0.2.2:8080` to reach a backend on your machine.
- Web usually needs a browser-reachable host such as `http://localhost:8080`.
- If `API_BASE_URL` is missing, the app now fails fast instead of silently using a hard-coded endpoint.
