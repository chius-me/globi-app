# Globi Mobile

Flutter mobile client for the Globi FastAPI backend.

The app now provides two entry modes:

- Blind mode: accessible UI, no login required
- Family mode: authenticated UI backed by Authentik and FastAPI

## Android Release Pipeline

The release workflow runs when you push a tag that matches `v*`. It builds a signed Android release APK and uploads it to the Gitea Release for that same tag.

1. Generate a release keystore locally:

```powershell
keytool -genkeypair -v -keystore release-keystore.jks -alias globi-mobile -keyalg RSA -keysize 2048 -validity 10000
```

2. Convert the keystore to Base64 in PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\release-keystore.jks"))
```

3. In the Gitea repository, add these Actions secrets:

- `ANDROID_KEYSTORE_BASE64`: Base64 output of `release-keystore.jks`
- `ANDROID_STORE_PASSWORD`: keystore password
- `ANDROID_KEY_ALIAS`: key alias, for example `globi-mobile`
- `ANDROID_KEY_PASSWORD`: key password

The workflow already uses the built-in `GITEA_TOKEN` to create the release and upload the APK, so you do not need to add a separate release token secret. In the repository's Gitea Actions settings, make sure that token is allowed to write releases and repository contents, or the workflow can still fail during release creation or APK upload.

4. Push a release tag to trigger the workflow:

```powershell
git tag v1.0.0
git push origin v1.0.0
```
