# Build and test — Cosmic Easy Phone TSP ed. 1.0.3+4

## Toolchain

This is a Flutter/Android project. The resolved dependency lockfile requires Dart 3.13 or newer and Flutter 3.44 or newer. Use JDK 21 for the Android Gradle build, plus a compatible Android SDK and Android Studio installation.

## Inspect and test

From this directory:

```sh
flutter --version
flutter pub get
flutter analyze
flutter test
```

Build a development APK with:

```sh
flutter build apk --debug
```

The project uses the Gradle wrapper in `android/gradlew` and `android/gradle/wrapper/`.

## Release signing

The Android release Gradle configuration reads `android/key.properties` for the owner's signing configuration. That file and the production keystore are deliberately excluded from this snapshot. A local debug build and source inspection do not require the owner's private signing key.

Do not ask the project owner for the private keystore merely to inspect or test the source. Do not publish a build created from this source under Frogdadday branding or distribute a derivative binary; the source license restricts those uses.

## Permission note

The production manifest at `android/app/src/main/AndroidManifest.xml` does not declare INTERNET permission and removes RECORD_AUDIO and ACCESS_NETWORK_STATE. The debug and profile manifests do declare INTERNET for development/profiling. Inspect the merged release manifest of any locally built variant before making permission claims.

## Reference release

The reference APK is version 1.0.3, Android version code 4, package `com.frogdadday.android_toolkit`. Its public checksum and audit details are recorded in [README.md](README.md) and [RELEASE-METADATA.json](RELEASE-METADATA.json).
