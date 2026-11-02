# Third-party components and notices

Frog Cleaner is a Flutter Android application. The runtime Flutter framework is supplied by the Flutter SDK. The app's direct Dart dependencies are declared in `pubspec.yaml`; the exact resolved Dart package graph is recorded in `pubspec.lock`.

Direct development dependencies include:

- `flutter_test` (Flutter SDK)
- `flutter_lints` 6.0.0
- `flutter_launcher_icons` 0.14.4

The Android build uses the Gradle plugins and repositories declared in `android/settings.gradle.kts`, the Gradle wrapper declared in `android/gradle/wrapper/gradle-wrapper.properties`, and AndroidX/platform components pulled by the Android build.

To display the Dart/Flutter package license inventory for your local SDK environment, run:

```sh
flutter pub get
flutter pub licenses
```

To inspect Android/Gradle dependency metadata, use Gradle's dependency-report tasks. Third-party components retain their own license terms; nothing in Frogdadday's source-available license overrides those terms.