# Frog Cleaner — TSP edition 1.0.2 (build 4)

This is a public source snapshot published for independent inspection, privacy review, and code transparency.

- App version: 1.0.2
- Android version code: 4
- Package ID: `com.frogdadday.frog_cleaner`
- Source commit: `abd623a880acb750d4a1bee2f067d8985f7b4a13`
- APK: [Frog-Cleaner-v1.0.2.apk](https://github.com/frogdadday/frogdadday.github.io/releases/download/frog-cleaner-v1.0.2/Frog-Cleaner-v1.0.2.apk)
- APK SHA-256: `7262c8801a2e85564ec7ec742d17dab3d90044aa576c500542e429890f1dd764`
- Signing certificate SHA-256: `bcc04bc2e3db292321aa8a19fa495279c5341ef4e802c67cb0b79d3e5b96fa3e`

## Why this source is public

You should not have to take my word for how Frog Cleaner works. Inspect the Flutter and native Android code, manifests, permissions, storage handling, cache-cleaning accessibility service, tests, dependency lockfile, and privacy policy.

## Permission boundaries

- The production/main manifest has no INTERNET permission. Debug and profile manifests include INTERNET only for Flutter development tooling.
- The production app declares `MANAGE_EXTERNAL_STORAGE` for optional full-device shared-storage review. The user must enable this special access in Android Settings.
- An optional Android Accessibility service supports a user-started cache-cleaning session. It reads visible Android Settings UI and is designed to press only Clear cache for apps the user selected. This is not a general-purpose accessibility tool or a guarantee across every device and Settings layout.
- Android backup is disabled. Scan metadata remains in app-private on-device storage.
- File deletion is user-directed. Files are not selected automatically. Permanent deletion cannot be undone.

## Build and inspect

See `BUILD.md` and `SOURCE_SETUP.md`. The resolved Dart dependency graph is preserved in `pubspec.lock`.

## APK audit and source correspondence

The public APK audit passed Android signature validation, package/version identity checks, and GitHub asset digest comparison. The source project's `pubspec.yaml` version is `1.0.2+4`, matching APK version name 1.0.2 and version code 4.

This is a version-and-identity match, not a reproducible-build attestation. No reproducible build proves the published APK was produced from this exact source commit. The audit did not check Google Play App Signing compatibility or real-device behavior for this exact APK.

Audit workflow: https://github.com/frogdadday/frogdadday.github.io/actions/runs/40536073046

## Project status

Review `RELEASE_SCOPE.md`, `PRIVACY_POLICY.md`, and `VERIFICATION.md`. Android all-files access and Accessibility-service automation have additional platform and Google Play policy requirements. Publishing this source does not mean those permissions have been approved by Google Play.

## Ownership and license

Original Frogdadday source is covered by `LICENSE.md`, a custom source-available license allowing inspection, audit, private non-commercial study, and narrowly defined GitHub-native review forks. It does not grant permission to publish compiled builds, redistribute source outside GitHub-native forking, rebrand, or commercially exploit the app.

Frogdadday branding, logos, screenshots, app icon artwork, and frog mascot artwork are excluded. Third-party components retain their own licenses; see `THIRD_PARTY_NOTICES.md`.