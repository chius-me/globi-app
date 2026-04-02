# Globi Mobile

Flutter mobile client for the Globi FastAPI backend.

The app now provides two entry modes:

- Blind mode: accessible UI, no login required
- Family mode: authenticated UI backed by Authentik and FastAPI

## App Modes

When the app starts for the first time, users choose one of two identities:

- `我是盲人`: enters the accessibility-first UI without authentication
- `我是盲人家属`: enters the current authenticated UI and uses browser-based login

The choice is stored locally and can be changed later from the UI.

## Auth Setup

The app uses:

- Backend: `https://server.globi.lan.tamochi.cn`
- Auth provider: Authentik
- Redirect URI: `flutty://login-callback`
- Login flow: Authorization Code + PKCE + system browser

## What is Implemented

- Fetch backend auth config from `/api/auth/config`
- Generate PKCE verifier/challenge/state/nonce
- Open the browser with `/api/auth/authorize-url`
- Handle callback from `flutty://login-callback`
- Exchange authorization code via `/api/auth/token`
- Save tokens with `flutter_secure_storage`
- Restore session on app restart
- Refresh access token automatically through Dio interceptor
- Fetch current user via `/api/auth/me`
- Logout via `/api/auth/logout`

## Platform Configuration

Already configured in this repo:

- Android intent filter for `flutty://login-callback`
- iOS URL scheme `flutty`

## Windows Verification Notes

This Linux workspace does not have a Flutter runtime configured, so the code was updated without running Flutter commands locally.

After moving to your Windows machine, run:

1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter run`

Then verify:

1. App cold start first shows the role selection screen
2. Choosing `我是盲人` enters the no-login accessible UI
3. Choosing `我是盲人家属` enters the authenticated flow
4. Tapping login opens system browser
5. Authentik redirects back to `flutty://login-callback`
6. App reaches authenticated home screen
7. Restarting app restores the previously selected mode
8. Family mode restores the session when tokens are still valid
9. Protected requests still work after access token refresh
10. Switching identity returns to the role selection screen
