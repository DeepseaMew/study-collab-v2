# Integration Tests

This directory contains Flutter integration tests for Study Collab.

---

## Prerequisites

Before running any integration test that hits Firebase services (i.e., `auth_happy_path_test.dart`), ensure the following are in place:

1. **Android emulator** — launch one with `flutter emulators --launch Pixel_7` or confirm `emulator-5554` is listed in `flutter devices`.
2. **Chrome** — available for Web runs (`chrome` device shown in `flutter devices`).
3. **ChromeDriver** — required only for `flutter drive` on Web; must be on your system `PATH` and match your Chrome version. Download from https://chromedriver.chromium.org/. Start with `chromedriver --port=4444` before running web integration tests.
4. **firebase-tools 15+** — install with `npm install -g firebase-tools`. Verify with `firebase --version`.
5. **Java 11+** — the Firestore emulator is Java-based. On this machine Java 21 is available at `C:\Program Files\Android\Android Studio\jbr\`. Set `JAVA_HOME` if `java` is not on your PATH:
   ```powershell
   $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
   $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
   ```
6. **`apps/mobile/lib/firebase_options.dart` present locally** — this file is git-ignored and must be regenerated with `flutterfire configure` if absent. Do NOT commit it.
7. **`android:usesCleartextTraffic="true"` in the debug AndroidManifest** — required for the Android emulator to reach the Firebase Auth emulator over HTTP. See [Findings for flutter-engineer](#android-cleartext-traffic-finding) below.

---

## Emulator start command

Run from the **repo root** (`C:\Users\Windows 11\study_collab_v2`):

```bash
# If java is not on PATH:
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:$PATH"

firebase emulators:start --only auth,firestore
```

Wait for both lines to appear in the output:
```
i  auth: Auth Emulator started on http://0.0.0.0:9099
i  firestore: Firestore Emulator started on http://127.0.0.1:8080
```

The emulator UI is available at http://localhost:4000.

---

## Android run commands

Run from **`apps/mobile/`**:

```bash
# Stub-based flow test (no emulators needed):
flutter test integration_test/auth_flow_test.dart -d emulator-5554

# Happy-path test (requires Firebase emulators running):
flutter test integration_test/auth_happy_path_test.dart -d emulator-5554
```

---

## Web run commands

ChromeDriver must be running on port 4444 before executing web integration tests.

```bash
# In a separate terminal — start chromedriver:
chromedriver --port=4444

# Run from apps/mobile/ using flutter drive:
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/auth_happy_path_test.dart \
  -d web-server

# Or using flutter test directly on Chrome device:
flutter test integration_test/auth_happy_path_test.dart -d chrome
```

---

## Host gotcha: 10.0.2.2 vs localhost

The Firebase emulators run on the **host machine**. When the test connects to them, the host address differs by platform:

| Platform | Host to use | Why |
|---|---|---|
| Android emulator | `10.0.2.2` | Android's special loopback alias that maps to the host machine's `127.0.0.1` |
| Web (Chrome) / Desktop | `localhost` | Browser/desktop processes share network with host directly |
| iOS simulator | `localhost` | iOS simulator shares the host network |

The test file (`auth_happy_path_test.dart`) branches automatically:

```dart
final String emulatorHost =
    defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
```

Additionally, the Firebase Auth emulator must bind to `0.0.0.0` (not just `127.0.0.1`) for `10.0.2.2` to reach it. This is configured in `/firebase.json`:

```json
"auth": { "port": 9099, "host": "0.0.0.0" }
```

**Note:** The Firestore emulator (Java-based) may still bind to `127.0.0.1` regardless of the `host` setting in `firebase.json`. If Firestore emulator calls from Android fail, run `firebase emulators:start` with the `--host 0.0.0.0` flag.

---

## Cleanup behavior

`auth_happy_path_test.dart` uses the **unique-email strategy**:

```dart
final uniqueEmail = 'test-${DateTime.now().millisecondsSinceEpoch}@mail.kmutt.ac.th';
```

Each run creates a fresh account with a timestamp-based address. No cleanup calls are needed. Re-runs never conflict. The emulator state is reset when `firebase emulators:start` is run again (in-memory only — no persistence).

---

## Two firebase.json files — by design

There are two separate Firebase config files in this repo:

| Path | Tool | Purpose |
|---|---|---|
| `/firebase.json` (repo root) | Firebase CLI | Emulator configuration, Firestore rules deployment, Hosting config |
| `/apps/mobile/firebase.json` | FlutterFire CLI | Flutter app Firebase project wiring (app IDs, API keys) |

Do **not** merge or confuse these two files. The root `firebase.json` is for the Firebase CLI (`firebase emulators:start`, `firebase deploy`). The `apps/mobile/firebase.json` is generated by `flutterfire configure` and consumed by the Flutter build system.

---

## Android cleartext traffic finding

The Firebase Auth and Firestore emulators communicate over plain HTTP. Android 9+ blocks cleartext HTTP by default. To allow the Android emulator to reach the Firebase emulators, the debug build must opt in.

**Flutter-engineer action required:**

Add `android:usesCleartextTraffic="true"` to `apps/mobile/android/app/src/debug/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:usesCleartextTraffic="true" />
</manifest>
```

This must be in the `debug` manifest only — never in the `main` or `release` manifest.

Without this flag, `FirebaseAuth.instance.createUserWithEmailAndPassword()` throws a non-`FirebaseAuthException` platform channel error that is caught and re-thrown as `AuthFailure.unknownFailure()`, making the emulator root cause invisible in logs.
