# Build and test — Frog Easy Camera 1.0.2+3

## Toolchain

This is a Flutter/Android project. The resolved dependency lockfile requires Dart 3.13 or newer and Flutter 3.44 or newer. The Android project targets Java/Kotlin 17 bytecode and uses the Gradle wrapper and Android Gradle Plugin versions recorded in the included Android configuration. Install a compatible JDK, Android SDK, and Android Studio.

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

The production manifest is `android/app/src/main/AndroidManifest.xml`. Debug and profile manifests include INTERNET for development/profiling. Inspect the merged release manifest of any locally built variant before making permission claims.

## Reference release

This source snapshot is version 1.0.2, Android version code 3, package `com.frogdadday.easy_camera`. The public website currently records a separate v1.0.1 APK. No matching v1.0.2 APK audit is claimed.
