# Build and test — Cosmic Converter TSP ed. 1.0.6+9

## Toolchain

This is an Android/Flutter project. The dependency lockfile requires Dart 3.13 or newer and Flutter 3.44 or newer. Use a compatible Flutter stable release with Android SDK and Java configured for the Gradle version in `android/gradle/wrapper/gradle-wrapper.properties`.

## Inspect and test

From this directory:

```sh
flutter --version
flutter pub get
flutter analyze
flutter test
```

The Android debug build can be generated with:

```sh
flutter build apk --debug
```

## Release signing

The release Gradle configuration reads `android/key.properties` for the owner's Android signing configuration. That file and the keystore are intentionally excluded from this source snapshot. Do not ask the project owner for the private keystore merely to inspect or run tests.

A release build requires a valid signing configuration controlled by the owner. Do not publish a build created from this source under Frogdadday branding or distribute any derivative binary; the source license restricts that use.

## Permission note

The production manifest at `android/app/src/main/AndroidManifest.xml` does not declare INTERNET permission. The debug and profile manifests do declare INTERNET for development/profiling use. Do not treat those development manifests as the production release manifest. Inspect the merged release manifest for any locally built release variant before making permission claims.

## Release identity

The reference APK is version 1.0.6, version code 9, package `com.frogdadday.cosmicconverter`. Its public file checksum and audit details are recorded in [README.md](README.md) and [RELEASE-METADATA.json](RELEASE-METADATA.json).
