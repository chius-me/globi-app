# Gitea Runner Flutter Release Design

## Goal

Enable this Flutter project to publish a signed Android `release` APK automatically when a Git tag such as `v1.0.0` is pushed to Gitea.

## Current Project Context

- The repository is a standard Flutter multi-platform app.
- There is no existing Gitea workflow in the repository.
- Android release builds currently use the `debug` signing config in `android/app/build.gradle.kts`, which is not suitable for formal release publishing.
- App version currently comes from `pubspec.yaml`.

## Requirements

- A pushed tag should trigger a release pipeline in Gitea Runner.
- The pipeline should run inside a Flutter-capable container.
- The pipeline should build a signed Android `release` APK.
- The resulting APK should be published to the matching Gitea Release.
- The pipeline should use repository secrets rather than committed signing files.
- Tag values are only used as release triggers; they do not need to be validated against `pubspec.yaml`.

## Recommended Approach

Use a Gitea Actions workflow that listens for version-like tags (`v*`), restores a Base64-encoded Android keystore from Gitea secrets at runtime, generates a temporary `android/key.properties`, builds the APK with `flutter build apk --release`, creates or updates the release for that tag, and uploads the APK as a release asset.

This approach is preferred because it works cleanly with containerized runners, avoids binding the pipeline to a specific host path, and keeps release credentials outside the repository.

## Alternative Approaches Considered

### 1. Store the keystore on the runner host

Pros:

- The keystore file is not stored in Gitea secrets.

Cons:

- Ties the workflow to one runner host.
- Makes migration and scaling harder.
- Adds implicit machine-level configuration that is easy to forget.

### 2. Build unsigned or debug-signed releases first

Pros:

- Simplest initial setup.

Cons:

- Does not meet the requirement for formal release publishing.
- Would require a second redesign later for proper signing.

## Release Signing Design

### Signing Source of Truth

The Android release signing key will be generated locally by the project owner and then stored in Gitea as secrets.

Required secret values:

- `ANDROID_KEYSTORE_BASE64`: Base64 content of the `.jks` file
- `ANDROID_STORE_PASSWORD`: keystore password
- `ANDROID_KEY_ALIAS`: alias name inside the keystore
- `ANDROID_KEY_PASSWORD`: key password for the alias

### Runtime Secret Restoration

During CI execution, the workflow will:

1. Decode `ANDROID_KEYSTORE_BASE64` into a temporary file inside the workspace.
2. Generate `android/key.properties` from secret values.
3. Run the Android release build using the generated signing configuration.
4. Ensure the temporary files are only runtime artifacts and are not committed.

### Android Project Changes

`android/app/build.gradle.kts` should be updated so the `release` build type no longer uses the `debug` signing config. Instead, it should:

- load `android/key.properties` if present
- define a `release` signing config from those values
- fall back only as needed for non-release local development, not for release publishing

`android/key.properties` should not be committed with real values.

`.gitignore` should explicitly ignore:

- `android/key.properties`
- release keystore files such as `*.jks` or the specific chosen keystore name if stored locally in the repo tree

## Workflow Design

### Trigger

The workflow should trigger on Git tag push events matching `v*`.

Examples:

- `v1.0.0`
- `v1.0.1`
- `v2.0.0-beta.1` if tag patterns are configured to allow it

### Build Steps

The workflow should perform these steps in order:

1. Check out the repository.
2. Restore the signing keystore and `key.properties` from secrets.
3. Install or use a Flutter-enabled container image.
4. Run `flutter pub get`.
5. Run lightweight validation with `flutter analyze` before the release build.
6. Run `flutter build apk --release`.
7. Locate the generated APK at the standard Flutter output path.
8. Create the Gitea Release for the pushed tag.
9. Upload the APK as a release asset.

### Artifact Naming

The uploaded asset should use a stable, descriptive name, for example:

- `globi-mobile-v1.0.0-release.apk`

This makes the release page easy to scan and avoids ambiguous generic filenames.

## Release Publishing Behavior

The workflow should treat the pushed tag as the release key.

Because the selected design uses the tag only as a trigger, the workflow does not need to compare the tag version against `pubspec.yaml`. The APK version metadata can continue to come from Flutter's existing version configuration.

For release creation behavior, use a strict path:

- if the Gitea Release does not exist, create it
- if it already exists, fail the workflow clearly and stop before asset upload

This keeps the first version predictable and avoids silent overwrites or duplicate assets.

## Error Handling

The pipeline should fail early and clearly in these cases:

- any required signing secret is missing
- Base64 decoding fails
- `key.properties` generation fails
- Flutter dependency resolution fails
- Flutter release build fails
- Release creation or asset upload fails

The workflow should not claim success if the APK build or upload step fails.

## Security Constraints

- Real signing files must not be committed to git.
- Secrets must only be read from Gitea secret storage.
- The workflow should avoid printing secret values.
- Temporary signing files created during CI should remain workspace-local and ephemeral.

## Files Expected To Change

- Create: `.gitea/workflows/release.yml`
- Modify: `android/app/build.gradle.kts`
- Modify: `.gitignore`
- Modify: `README.md`

Optional supporting file:

- `android/key.properties` template or runtime-only generated file path handling

## Validation Plan

### Local Preparation

1. Generate a new Android release keystore locally.
2. Record its store password, alias, and key password.
3. Convert the keystore to Base64.
4. Save the four signing values as Gitea repository secrets.

### End-to-End Verification

1. Push a test tag such as `v0.1.0`.
2. Confirm the Gitea Runner starts the workflow.
3. Confirm the Flutter container can restore signing material.
4. Confirm `flutter build apk --release` succeeds.
5. Confirm a Gitea Release appears for the tag.
6. Confirm the signed APK is attached to the release.

## Out of Scope

- AAB publishing
- Google Play deployment
- iOS release automation
- Tag-to-`pubspec.yaml` version consistency enforcement
- Multi-runner host keystore management

## Implementation Notes

- Keep the first version minimal: only signed APK release publishing for tag pushes.
- Prefer repository-level secrets and runtime file generation over persistent files.
- Preserve the project's existing Flutter versioning unless a later requirement says tags must drive version numbers.
