# Frog Cleaner: verification record

This document records the verification scope associated with the source and public APK. It is not a security certification or a guarantee that every Android device behaves identically.

## Public APK identity audit

The published v1.0.2 APK audit completed successfully on October 27, 2026:

- Android APK signature: valid
- APK SHA-256: `7262c8801a2e85564ec7ec742d17dab3d90044aa576c500542e429890f1dd764`
- GitHub asset digest: matches
- Package ID: `com.frogdadday.frog_cleaner`
- Version name: `1.0.2`
- Version code: `4`
- Signing certificate SHA-256: `bcc04bc2e3db292321aa8a19fa495279c5341ef4e802c67cb0b79d3e5b96fa3e`

Audit workflow: https://github.com/frogdadday/frogdadday.github.io/actions/runs/40536073046

The audit does not check Google Play App Signing compatibility, does not prove the APK was reproducibly built from this source commit, and does not perform real-device behavior testing for this exact artifact.

## Development validation recorded by the project

The development notes recorded successful Flutter analysis, automated tests, Android debug APK compilation, and real-device checks for installation, navigation, settings handoffs, selected-folder scan flow, previews, Storage Map, duplicate review, local cache cleanup, scan restoration, and Cosmic Mode on a Moto G Power 5G (2023), Samsung SM-S176V, and Android 16 virtual profiles.

The same notes identify real-device checks still pending for Android Trash, permanent deletion, and enabled Accessibility automation. Large media previews and cache cleanup on lower-memory devices also require continued validation.

These are historical project test notes, not independent verification of the exact public release APK. Use disposable files for destructive-action testing.