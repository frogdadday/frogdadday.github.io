# Cosmic Chores — public source snapshot

**Source version:** 0.1.1 · Android version code 2  
**Android application ID:** `com.frogdadday.cosmicchores`  
**Source commit:** `c93bd7b6b8394457fff9a73b8caf930524f1e3e2`  
**Source commit date:** October 28, 2026

This snapshot is published so people can inspect, review, and audit Cosmic Chores. It includes the Flutter application, native Android implementation, XML platform resources, tests, privacy policy source, build configuration, and dependency lockfile.

This is an inspection-focused snapshot of the private `Cosmic-Chores` development repository. The private development repository remains private.

## Source-to-APK version distinction

The public website currently records **APK v0.1.0**, released October 22, 2026. This source snapshot is newer: **v0.1.1+2**. A matching v0.1.1 APK is not published or verified here. The existing v0.1.0 APK record remains unchanged and must not be treated as a binary built from this source commit.

- Existing v0.1.0 APK SHA-256: `264a23b76e2f0b0c2a7d2fbbd8b9c5c6abc5c525358f527d97e78d79f7d829ef`
- Existing signer certificate SHA-256: `1F:F3:4F:7C:F1:68:B2:D5:6F:E3:05:9C:5A:8F:B8:FF:01:3D:38:D3:A1:03:E8:B3:C6:80:F3:6E:E2:DA:85:D1`
- Existing APK record: [Cosmic Chores website page](https://frogdadday.com/apps/cosmic-chores.html)

These identifiers are copied from the existing public v0.1.0 release record. They do not attest to the newer source snapshot.

## Privacy and permissions visible in the source

The production Android manifest declares `READ_CONTACTS`, `POST_NOTIFICATIONS`, and `RECEIVE_BOOT_COMPLETED`. Contact access supports an optional user-initiated contact search; notification permission supports reminders; boot reception restores locally scheduled reminders. The production manifest does **not** declare the INTERNET permission. It includes package-visibility queries for SMS, HTTPS VIEW, and plain-text PROCESS_TEXT intents.

The app source describes local storage for chore lists and settings. Contact search is optional and processed on-device; messages are prepared for another app and are not silently sent by Cosmic Chores. The dependency manifest contains Flutter plus development-only Flutter test and lint dependencies; no advertising, analytics, Firebase, or crash-reporting package is declared there. Review the source and merged release package independently before relying on any privacy or security conclusion.

## Build and test

The project configuration specifies Flutter **3.47.8** for the local toolchain and Android compile/target API 36. From this directory, with a compatible Flutter SDK and Android SDK installed:

```sh
flutter --version
flutter pub get
flutter analyze
flutter test
```

The upstream commit does not track Gradle wrapper scripts or the wrapper JAR; only wrapper properties are present. A local Android/Gradle setup may need wrapper regeneration or equivalent configuration before an Android build. No production signing configuration or keystore is included. The project-specific local toolchain scripts are not part of this public snapshot. No reproducible-build or source-to-binary match is claimed. Tests were not rerun as part of preparing this snapshot.

## Included and excluded material

Included: Dart application source, native Android Kotlin implementation, Android manifests and XML resources, tests, privacy policy source, Gradle configuration, `pubspec.yaml`, and `pubspec.lock`.

Excluded: APK/AAB release binaries, signing keys and credentials, private SDK/toolchain caches, local machine setup scripts, internal project review/status documents, and original artwork / raster launcher image files. The Android XML launcher references are retained, but the raster launcher resources are not included; an independently supplied launcher asset set is required to complete a local Android build. Frogdadday branding and artwork remain excluded from the license grant.

## License

Original source code is provided under the custom [Source-Available Audit & Fork License 1.0](LICENSE.md). This is **source-available**, not OSI-approved open-source software. It permits personal inspection, private non-commercial study, and GitHub-native review forks only. It prohibits redistribution outside that narrow fork permission, commercial exploitation, rebranding, and publication of derivative app builds.

Frogdadday names, logos, product names, frog mascot artwork, app icons, screenshots, and other branding/artwork are excluded. Third-party components remain under their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Hosting

This snapshot is hosted inside the public [Frogdadday website repository](https://github.com/frogdadday/frogdadday.github.io), under `source/cosmic-chores/tsp-ed-0.1.1-build-2/`. It is not a standalone app-only repository. A GitHub-native fork of the parent repository includes the website as well as this source snapshot.