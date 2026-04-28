# Gitea Runner Flutter Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a signed Android `release` APK to Gitea Releases whenever a `v*` Git tag is pushed.

**Architecture:** Add one Gitea Actions workflow under `.gitea/workflows/` that runs in a Flutter-capable container, reconstructs Android signing material from repository secrets, builds the APK, then creates a Gitea Release and uploads the APK asset. Update Android Gradle signing so `release` uses runtime-generated `android/key.properties` instead of the current debug signing fallback.

**Tech Stack:** Flutter, Android Gradle Kotlin DSL, Gitea Actions, shell scripting in workflow steps

---

## File Structure

- Create: `.gitea/workflows/release.yml`
  - Tag-triggered release workflow
  - Restores signing secrets into runtime files
  - Runs Flutter build and publishes release asset
- Modify: `android/app/build.gradle.kts`
  - Loads `android/key.properties`
  - Defines `release` signing config from runtime values
  - Stops using debug signing for release builds
- Modify: `.gitignore`
  - Ignores `android/key.properties`
  - Ignores local keystore files
- Modify: `README.md`
  - Documents local keystore generation
  - Documents required Gitea secrets
  - Documents tag-driven release flow

### Task 1: Update Android signing configuration

**Files:**
- Modify: `android/app/build.gradle.kts:1-50`

- [ ] **Step 1: Write the failing release-build verification target**

The current file signs `release` with the debug key:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

The target behavior is:

```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

signingConfigs {
    create("release") {
        val storeFilePath = keystoreProperties.getProperty("storeFile")
        if (!storeFilePath.isNullOrBlank()) {
            storeFile = file(storeFilePath)
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

- [ ] **Step 2: Verify the current file fails the target review**

Run:

```bash
rg 'signingConfigs.getByName\("debug"\)' android/app/build.gradle.kts
```

Expected: one match in the `release` build type, proving release signing is still incorrect.

- [ ] **Step 3: Implement the minimal Gradle signing change**

Replace the file content with this structure:

```kotlin
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val ciNdkPath = System.getenv("ANDROID_NDK_HOME") ?: System.getenv("ANDROID_NDK_ROOT")
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.globi_mobile"
    compileSdk = flutter.compileSdkVersion
    if (!ciNdkPath.isNullOrBlank()) {
        ndkPath = ciNdkPath
    } else {
        ndkVersion = flutter.ndkVersion
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (!storeFilePath.isNullOrBlank()) {
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "cn.tamochi.globi"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
```

- [ ] **Step 4: Verify the debug signing fallback is removed**

Run:

```bash
rg 'signingConfigs.getByName\("debug"\)' android/app/build.gradle.kts
```

Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add android/app/build.gradle.kts
git commit -m "build: load android release signing from key properties"
```

### Task 2: Ignore runtime signing files

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Write the failing ignore-rule verification target**

The target ignore block is:

```gitignore
android/key.properties
*.jks
*.keystore
```

- [ ] **Step 2: Verify the current ignore rules are missing**

Run:

```bash
rg 'android/key.properties|\.jks|\.keystore' .gitignore
```

Expected: no matches, or only partial matches that do not cover all three rules.

- [ ] **Step 3: Add the minimal ignore entries**

Append this block to `.gitignore` if the entries are not already present:

```gitignore
android/key.properties
*.jks
*.keystore
```

- [ ] **Step 4: Verify the ignore rules exist**

Run:

```bash
rg 'android/key.properties|\.jks|\.keystore' .gitignore
```

Expected: matches for all three entries.

- [ ] **Step 5: Commit**

```bash
git add .gitignore
git commit -m "build: ignore android signing artifacts"
```

### Task 3: Add the Gitea release workflow

**Files:**
- Create: `.gitea/workflows/release.yml`

- [ ] **Step 1: Write the failing workflow presence check**

Run:

```bash
test -f .gitea/workflows/release.yml
```

Expected: non-zero exit status because the workflow file does not exist yet.

- [ ] **Step 2: Define the workflow content**

Create `.gitea/workflows/release.yml` with this structure:

```yaml
name: Release Android APK

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/cirruslabs/flutter:stable

    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Validate signing secrets
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_STORE_PASSWORD: ${{ secrets.ANDROID_STORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          test -n "$ANDROID_KEYSTORE_BASE64"
          test -n "$ANDROID_STORE_PASSWORD"
          test -n "$ANDROID_KEY_ALIAS"
          test -n "$ANDROID_KEY_PASSWORD"

      - name: Restore Android keystore
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: |
          printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/release-keystore.jks

      - name: Generate key.properties
        env:
          ANDROID_STORE_PASSWORD: ${{ secrets.ANDROID_STORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          cat > android/key.properties <<EOF
          storeFile=release-keystore.jks
          storePassword=$ANDROID_STORE_PASSWORD
          keyAlias=$ANDROID_KEY_ALIAS
          keyPassword=$ANDROID_KEY_PASSWORD
          EOF

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze project
        run: flutter analyze

      - name: Build release APK
        run: flutter build apk --release

      - name: Prepare asset name
        run: cp build/app/outputs/flutter-apk/app-release.apk "globi-mobile-${GITHUB_REF_NAME}-release.apk"

      - name: Ensure release does not already exist
        env:
          GITEA_TOKEN: ${{ secrets.GITEA_RELEASE_TOKEN }}
        run: |
          gh release view "$GITHUB_REF_NAME" --repo "$GITHUB_REPOSITORY" && exit 1 || exit 0

      - name: Create Gitea release
        env:
          GITEA_TOKEN: ${{ secrets.GITEA_RELEASE_TOKEN }}
        run: |
          gh release create "$GITHUB_REF_NAME" \
            "globi-mobile-${GITHUB_REF_NAME}-release.apk" \
            --repo "$GITHUB_REPOSITORY" \
            --title "$GITHUB_REF_NAME"
```

Notes for implementation while applying the plan:

- Confirm whether the runner environment exposes `gh` against Gitea. If it does not, replace the last two steps with `curl` calls to the Gitea Releases API using the same `GITEA_RELEASE_TOKEN` secret.
- Keep the release behavior strict: if the release already exists, stop before uploading.

- [ ] **Step 3: Verify the workflow file exists and includes the tag trigger**

Run:

```bash
test -f .gitea/workflows/release.yml && rg "tags:" .gitea/workflows/release.yml
```

Expected: zero exit status and a visible `tags:` match.

- [ ] **Step 4: Verify the workflow references all required secrets**

Run:

```bash
rg 'ANDROID_KEYSTORE_BASE64|ANDROID_STORE_PASSWORD|ANDROID_KEY_ALIAS|ANDROID_KEY_PASSWORD|GITEA_RELEASE_TOKEN' .gitea/workflows/release.yml
```

Expected: matches for all five secret names.

- [ ] **Step 5: Commit**

```bash
git add .gitea/workflows/release.yml
git commit -m "ci: add tag-driven android release workflow"
```

### Task 4: Document release setup and usage

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the failing documentation verification target**

The README currently does not explain Android release signing or Gitea release automation. The target content must cover:

```markdown
## Android Release Pipeline

### Generate a keystore
### Configure Gitea secrets
### Push a release tag
```

- [ ] **Step 2: Verify the current README is missing the section**

Run:

```bash
rg 'Android Release Pipeline|Generate a keystore|Configure Gitea secrets|Push a release tag' README.md
```

Expected: no matches.

- [ ] **Step 3: Add the minimal release documentation**

Append this section to `README.md`:

````markdown
## Android Release Pipeline

Generate a release keystore locally and keep it in a safe place. This key must be reused for future Android updates.

### Generate a keystore

```bash
keytool -genkeypair -v -keystore globi-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias globi-release
```

Record these values when prompted:

- keystore password
- key alias: `globi-release`
- key password

Convert the keystore to Base64 on PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('globi-release.jks')) | Set-Content -NoNewline globi-release.jks.base64
```

Or on Linux:

```bash
base64 -w 0 globi-release.jks > globi-release.jks.base64
```

### Configure Gitea secrets

Add these repository secrets in Gitea:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `GITEA_RELEASE_TOKEN`

`GITEA_RELEASE_TOKEN` must be able to create releases and upload release assets for this repository.

### Push a release tag

Create and push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Pushing the tag starts the Gitea workflow, builds a signed Android `release` APK, creates the matching Gitea Release, and uploads the APK asset.
````

- [ ] **Step 4: Verify the README section exists**

Run:

```bash
rg 'Android Release Pipeline|Generate a keystore|Configure Gitea secrets|Push a release tag' README.md
```

Expected: matches for all required headings.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: add android release pipeline setup"
```

### Task 5: Validate the integrated release flow

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `.gitignore`
- Create: `.gitea/workflows/release.yml`
- Modify: `README.md`

- [ ] **Step 1: Run local static verification of the changed files**

Run:

```bash
flutter analyze
```

Expected: `No issues found!` or the repository's equivalent successful analyze output.

- [ ] **Step 2: Verify the workflow file syntax by inspection commands**

Run:

```bash
rg '^name:|^on:|^jobs:|runs-on:|container:|flutter build apk --release|gh release create' .gitea/workflows/release.yml
```

Expected: matches for the workflow header, job definition, container usage, build step, and release creation step.

- [ ] **Step 3: Verify no signing artifacts were accidentally staged**

Run:

```bash
git status --short
```

Expected: only `.gitea/workflows/release.yml`, `README.md`, `.gitignore`, and `android/app/build.gradle.kts` appear as intended changes.

- [ ] **Step 4: Push a test tag after secrets are configured in Gitea**

Run:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Expected: Gitea starts the workflow for the tag push.

- [ ] **Step 5: Confirm release publication in Gitea UI**

Manual verification target:

```text
Release tag: v0.1.0
Expected asset: globi-mobile-v0.1.0-release.apk
Expected result: release exists and APK is downloadable
```

- [ ] **Step 6: Commit**

```bash
git add .gitea/workflows/release.yml README.md .gitignore android/app/build.gradle.kts
git commit -m "release: publish signed android apk from gitea tags"
```

## Self-Review

- Spec coverage: the plan covers signed release setup, tag-triggered workflow creation, release upload, documentation, and end-to-end verification.
- Placeholder scan: no unresolved placeholders or undefined file references remain.
- Type consistency: secret names, file paths, tag pattern, and asset naming are consistent across all tasks.
