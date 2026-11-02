# Build and test — Frog File Viewer TSP ed. 0.2.1+3

## Toolchain

- Flutter 3.47 or newer
- Dart 3.13 or newer
- Android SDK with API 36 available
- Android Studio and a compatible Android Gradle Plugin/JDK 17 toolchain

The dependency lockfile is included. From this directory:

```sh
flutter pub get
dart run tool/generate_tie_dye_icons.dart
flutter analyze
flutter test
flutter build apk --debug
```

The current project snapshot does not include the owner's local Gradle wrapper scripts or signing files. If your Flutter/Android environment requires a wrapper, generate one locally from the Android directory using an installed compatible Gradle distribution or use Android Studio's Gradle tooling. Do not add a private keystore or credentials to a public fork.

## Release signing

The Android release Gradle configuration reads `android/key.properties` and deliberately fails closed if the permanent `frog-file-viewer-upload` signing setup is missing. The example file contains placeholders only. The production keystore, passwords, and real `android/key.properties` are intentionally excluded.

Do not generate a replacement key for an already-registered app identity. Do not ask the owner for the private keystore to inspect or test this source. Do not publish a build created from this source under Frogdadday branding or distribute a derivative binary; the source license restricts those uses.

## Android permissions

The production release manifest overlay explicitly removes `INTERNET` and `ACCESS_NETWORK_STATE`. The main manifest requests `CAMERA` for the optional in-app document scanner and removes `RECORD_AUDIO`, `READ_EXTERNAL_STORAGE`, and `WRITE_EXTERNAL_STORAGE`. Debug/profile manifests may differ. Inspect the merged manifest for any locally built variant before making permission claims.

## Reference APK

The public testing APK is version 0.2.1, Android version code 3, package `com.frogdadday.frog_file_viewer`. Its checksum, signer fingerprint, and audit scope are recorded in [README.md](README.md) and [RELEASE-METADATA.json](RELEASE-METADATA.json).
