# Frog Cleaner: source setup

This directory is a public inspection snapshot of Frog Cleaner TSP edition 1.0.2 (Android build 4).

## Open in Android Studio

1. Install Flutter and the Android Studio Flutter plugin.
2. Download or fork this public repository for inspection.
3. Open this directory—the one containing `pubspec.yaml`—in Android Studio.
4. Install JDK 21 and the Android SDK requested by Flutter/Gradle.
5. Run `flutter pub get`, select an Android device, and run the app.

## Verify locally

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`.

## Excluded materials

Build output, local SDK paths, IDE preferences, `android/key.properties`, signing keys, signing passwords, APKs, and AABs are not part of this source snapshot. The private release signing material is not required to inspect or build a debug APK.

The production build has no Internet permission. Debug/profile manifests include the development Internet permission required by Flutter tooling.

See `LICENSE.md` for permitted use and `BUILD.md` for build details.