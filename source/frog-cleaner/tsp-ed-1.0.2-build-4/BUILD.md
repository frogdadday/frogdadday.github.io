# Building Frog Cleaner

## Requirements

- Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml` (`^3.11.0`)
- Android SDK and Android Studio
- JDK 21 for the Gradle build
- Gradle wrapper 9.3.1

## Debug build

From the project root:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Release signing

The private upload key and `android/key.properties` are intentionally not included. Do not request, commit, or publish signing passwords or keystore files. A release build requires the owner's separately managed signing configuration. The source snapshot is sufficient for inspection and local debug builds; it does not provide the private release key.

## Permission and behavior notes

The main manifest includes `MANAGE_EXTERNAL_STORAGE` and the optional Accessibility service. The main manifest does not include `INTERNET`; the debug and profile manifests include it for Flutter development tooling. Review the Android manifest and `AutoCacheCleanerService.kt` before enabling either special access.

Run destructive-action tests only with disposable files and devices. Permanent deletion has no undo.