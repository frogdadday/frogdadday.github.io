# Build and test — Cosmic Spinner 1.0.3+4

## Toolchain

The upstream CI workflow uses Flutter 3.47.8. The project requires Dart SDK `^3.13.2`. Install a compatible JDK and Android SDK for Android work.

## Source checks

From this directory:

```sh
flutter --version
flutter pub get
flutter analyze
flutter test
```

## Android build note

The upstream commit does not track `android/gradlew` or `android/gradle/wrapper/gradle-wrapper.jar`. The Android project includes its Gradle settings and wrapper properties, but a local build environment may need to regenerate the wrapper or configure Gradle before `flutter build apk --debug` can run.

The Android release build reads signing configuration from a local key-properties file or the environment variable `COSMIC_SPINNER_SIGNING_PROPERTIES`. Those credentials and the production keystore are deliberately excluded. Do not request or publish the owner's signing materials.

The public APK record is v1.0.2. This source snapshot is v1.0.3+4; no matching v1.0.3 APK or reproducible-build attestation is claimed.
