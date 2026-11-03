# Cosmic Spinner — public source snapshot

**Source version:** 1.0.3 · Android version code 4  
**Android application ID:** `com.frogdadday.cosmicspinner`  
**Source commit:** `a40aba27a1c9192e40eff2599731162560335ff7`  
**Source commit date:** October 28, 2026

This snapshot is published so people can inspect, review, and audit Cosmic Spinner. It includes the Flutter application, native Android implementation, launcher resources, privacy policy source, tests, build configuration, and dependency lockfile.

This is a flattened, inspection-focused snapshot of the `cosmic_spinner/` project directory from the private development repository. The private development repository remains private.

## Source-to-APK version distinction

The public website currently records **APK v1.0.2**, released October 22, 2026. This source snapshot is newer: **v1.0.3+4**. A matching v1.0.3 APK is not published or verified here. The older APK record remains unchanged and must not be treated as a binary built from this source commit.

- Existing v1.0.2 APK SHA-256: `233fca614355d3aa5e1f57daf828459ec68ae344c058dc193017337f4e038dec`
- Existing signer certificate SHA-256: `53:DD:1C:E7:E8:24:70:A3:56:B6:CC:2F:A5:9D:9E:08:C6:6E:65:A2:36:29:62:CF:CD:A3:C0:2C:77:5F:EB:64`
- Existing APK record: [Cosmic Spinner website page](https://frogdadday.com/apps/cosmic-spinner.html)

These identifiers are copied from the existing public v1.0.2 release record. They do not attest to the newer source snapshot.

## Privacy and permissions visible in the source

The production Android manifest does not declare Android runtime permissions or the INTERNET permission. It includes package-visibility queries for HTTPS VIEW intents and plain-text PROCESS_TEXT handling. The app's support and privacy-policy buttons open fixed external destinations through Android; that is different from the app itself uploading spinner content.

The reviewed app stores saved wheels, drafts, and preferences in private Android app storage. The source privacy policy explains Android backup caveats, the optional support link, and the local keyword-based support message. It states that the app does not use analytics SDKs, advertising, user tracking, accounts, or cloud sync. Review the source and merged release package independently before relying on any privacy or security conclusion.

## Build and test

The repository's CI workflow uses Flutter **3.47.8** and runs `flutter pub get`, `flutter analyze`, `flutter test`, and a debug APK build. The source manifest and Gradle configuration target the Android application ID above.

From this directory, with Flutter and Android SDK installed:

```sh
flutter --version
flutter pub get
flutter analyze
flutter test
```

The upstream project does not track Gradle wrapper scripts or the wrapper JAR in this commit. A local Android/Gradle setup may therefore need wrapper regeneration or equivalent configuration before an APK build. No production signing configuration or keystore is included. No reproducible-build or source-to-binary match is claimed.

## Included and excluded material

Included: Dart source, Android manifests and native Kotlin activity, Android launcher resources, adaptive icon foreground asset, tests, privacy policy source, Gradle configuration, `pubspec.yaml`, and `pubspec.lock`.

Excluded: APK/AAB release binaries, signing keys and credentials, private SDK/toolchain cache, local IDE settings, internal project notes/status documents, and the large original `assets/icon.png` master artwork. The Android launcher resources and adaptive foreground asset used by the app are included. The original artwork and branding remain excluded from the license grant.

## License

Original source code is provided under the custom [Source-Available Audit & Fork License 1.0](LICENSE.md). This is **source-available**, not OSI-approved open-source software. It permits personal inspection, private non-commercial study, and GitHub-native review forks only. It prohibits redistribution outside that narrow fork permission, commercial exploitation, rebranding, and publication of derivative app builds.

Frogdadday names, logos, product names, frog mascot artwork, app icons, screenshots, and other branding/artwork are excluded. Third-party components remain under their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Hosting

This snapshot is hosted inside the public [Frogdadday website repository](https://github.com/frogdadday/frogdadday.github.io), under `source/cosmic-spinner/tsp-ed-1.0.3-build-4/`. It is not a standalone app-only repository. A GitHub-native fork of the parent repository includes the website as well as this source snapshot.
