# CallVault Critical Recording Prototype

Minimal Flutter + Kotlin app to **detect a real SIM/cellular call, record available audio, save a file, and play it back** on Android 10+ (API 29).

This is **not** the full CallVault product. It exists to answer one question on your physical phone:

> Can this device capture your voice, the remote party, both, or neither during a cellular call?

## Important limitation

**Two-way call audio is not guaranteed.** Android restricts ordinary third-party apps from freely capturing voice-call uplink/downlink audio. Being a default dialer does not automatically grant both sides. This prototype reports which `MediaRecorder` audio source started (`VOICE_COMMUNICATION` then `MIC` fallback) and leaves verification to **listening**.

If the remote party is silent in the recording, treat that as an OS/device limitation — do not spend weeks “fixing” it in Flutter UI.

## Requirements

- Flutter SDK (stable)
- Physical Android phone with a working SIM (emulator is insufficient for cellular audio)
- Android 10 or newer (minSdk 29)
- USB debugging enabled

## Project layout

```
lib/
  main.dart
  bridge/call_bridge.dart
  prototype/prototype_screen.dart
android/.../kotlin/com/callvault/prototype/
  MainActivity.kt
  bridge/CallVaultBridge.kt
  telecom/CallStateMonitor.kt
  recorder/CallRecorder.kt
  recorder/RecordingService.kt
```

Package / application id: `com.callvault.prototype`

## Build & install

```bash
flutter pub get
flutter run
```

Or build an APK:

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## On-device test checklist

1. Install the debug build on a **physical** phone.
2. Open **CallVault Prototype**.
3. Tap **Request permissions** (microphone, phone state, notifications on Android 13+).
4. Tap **Start monitor**. Confirm call state updates.
5. Leave **Auto-record when call active** enabled.
6. Place or receive a **real SIM call**. Speak from both ends for 20–30 seconds.
7. End the call. Confirm recording state becomes `stopped` and a file appears under Saved recordings.
8. Tap **Play last file** (or the play icon on a list item).
9. Mark the listen checklist:
   - Your voice recorded?
   - Other person’s voice recorded?
   - Both sides recorded?

### Optional: pull the file

Recordings are stored under app-specific storage, for example:

`Android/data/com.callvault.prototype/files/Recordings/proto_YYYYMMDD_HHmmss.m4a`

```bash
adb shell "run-as com.callvault.prototype ls files/Recordings"
```

(Exact `run-as` / pull path can vary by device and whether the app is debuggable.)

## Channel API

| Method | Purpose |
|--------|---------|
| `ping` | Native bridge health check |
| `checkPermissions` / `requestPermissions` | Mic, phone, notifications |
| `openAppSettings` | Deep link to system app settings |
| `startCallMonitor` / `stopCallMonitor` | Telephony call-state listener |
| `startRecording` / `stopRecording` | Foreground service + MediaRecorder |
| `getLastRecordingPath` / `listRecordings` | Saved `.m4a` files |

Events (`EventChannel`): `onCallState`, `onRecordingState`.

## What this prototype does **not** include

Full dialer UI, default-dialer role polish, Drift/SQLite, contacts, notes, favorites, app lock, dual-SIM picker, storage manager.

## After a successful both-sides result

Only if both sides are audible on your target device(s), proceed to the full CallVault MVP (Telecom dialer integration, Drift, recordings library, etc.), promoting this native bridge rather than rewriting it.
