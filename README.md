<p align="right">
  English | <a href="./README.zh.md">简体中文</a>
</p>

<h1 align="center">globi-app</h1>

<p align="center">
  Flutter-based assistive safety communication mobile client (领航助手) designed for visually impaired individuals and their families.
</p>

<p align="center">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-blue.svg">
  <img alt="Language" src="https://img.shields.io/badge/Language-Dart-00B4AB.svg">
  <img alt="Framework" src="https://img.shields.io/badge/Framework-Flutter-02569B.svg">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey.svg">
</p>

## What It Does

`globi-app` provides a secure connection between visually impaired individuals and their families. The application functions in two major operation modes depending on the user type:

| Mode | Key Features | Targets |
|---|---|---|
| **Blind Mode** | Single pairing code (no passwords), AI voice assistant chat, periodic GPS position reporting, one-key family phone calling. | Visually Impaired Users |
| **Family Mode** | Map dashboard tracking, automatic refresh location monitoring, binding managers, OAuth / secure logins. | Family Members / Guardians |

## Requirements

| Tool/Platform | Version Required | Purpose |
|---|---|---|
| **Flutter SDK** | `^3.11.1` (stable) | Cross-platform build tooling |
| **Dart SDK** | `^3.11.1` | Language execution |
| **Java / JDK** | 17 | Required by Android Gradle Plugin (AGP 8.11.1) |
| **Android Studio** | Latest | Android SDK & emulator setup |
| **Xcode** | Latest | iOS compilation (Minimum iOS target 13.0) |
| **CocoaPods** | Latest | iOS dependency manager |

## Quick Start

### 1. Project Initialization

Clone this repository and retrieve Dart/Flutter packages:
```bash
git clone https://github.com/chius-me/globi-app.git
cd globi-app
flutter pub get
```

### 2. Configure Backend Endpoint

Configure the backend server base URL inside `lib/config/constants.dart`:
```dart
static const String backendBaseUrl = 'https://api.yourdomain.com'; // Adjust to your running API URL
```

### 3. Run and Debug

- Run on your active emulator or plugged device:
  ```bash
  flutter run
  ```
- Run automated tests:
  ```bash
  flutter test
  ```

---

## Build and Release

### Android Release Build
To generate a signed Release APK locally, configure your signing properties (ignored by Git):

1. **Generate Developer Keystore (if you don't have one):**
   ```bash
   keytool -genkeypair -v \
     -keystore android/app/release-keystore.jks \
     -alias globi-key \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
2. **Create Sign configuration:**
   Create a file `android/key.properties` containing:
   ```properties
   storeFile=release-keystore.jks
   storePassword=your-store-password
   keyAlias=globi-key
   keyPassword=your-key-password
   ```
3. **Trigger Compilation:**
   ```bash
   flutter build apk --release
   ```

### iOS Release Build
Install dependencies and build:
```bash
cd ios
pod install
cd ..
flutter build ios --release
```

---

## Technical Features & Setup

### 1. OAuth2 Deep Links Callback
The OAuth flow redirects to the app via `flutty://login-callback` deep links:
- **Android**: Handled by the `intent-filter` inside `android/app/src/main/AndroidManifest.xml`
- **iOS**: Configured within `CFBundleURLTypes` inside `ios/Runner/Info.plist`

**Local Deep Link Testing:**
- **Android**: `adb shell am start -W -a android.intent.action.VIEW -d "flutty://login-callback?code=xxx" cn.tamochi.globi`
- **iOS**: `xcrun simctl openurl booted "flutty://login-callback?code=xxx"`

### 2. Audio Capture & Voice Synthesis
- Uses `record` package to record standard `.wav` files.
- Uses `just_audio` to play real-time synthesized voice files returned from the backend.

### 3. State Management & Secure Storage
- **Provider**: Standard state engine for screens.
- **flutter_secure_storage**: Secure storage of access/refresh tokens in EncryptedSharedPreferences (Android) and Keychain (iOS).
- **PKCE Flow**: Implemented in `lib/utils/pkce.dart` to prevent client-side authorization injection.

---

## Project Structure

```
globi-app/
├── android/                    # Native Android configurations (Gradle settings)
├── ios/                        # Native iOS build files (Podfile, Info.plist)
├── lib/
│   ├── main.dart               # Entrypoint (Provider injection, OAuth links listener)
│   ├── config/                 # App Constants & color schemes
│   ├── interceptors/           # HTTP Interceptors (auto JWT token refresh)
│   ├── providers/              # Application state controllers
│   ├── screens/                # UI screens (Blind mode interface, Family map)
│   ├── services/               # REST API layers
│   └── utils/                  # Cryptographic utilities (PKCE), audio encoders
├── assets/                     # SVGs and UI graphics
└── .github/workflows/          # Github Actions CI release build workflows
```

---

## Contribution & Git Flow

### Commit Convention
Commits must follow the Conventional Commit pattern to maintain a clean changelog:
- `feat: add voice recording waveforms`
- `fix: crash when gps coordinates are null`
- `refactor: extract map controller to separate utility`
- `chore: update dependencies`

### CI/CD Workflow
Pushing tags starting with `v*` (e.g. `git tag v1.0.0 && git push origin v1.0.0`) triggers a GitHub Action workflow. It builds a signed release APK and automatically publishes a new GitHub Release with the APK attached.
