# Source setup — Cosmic Chores

This directory is an inspection-focused snapshot, not a complete clone of the private development environment.

1. Install Flutter 3.47.8 and the Android SDK.
2. Open this directory as the Flutter project root.
3. Run `flutter pub get`, then `flutter analyze` and `flutter test`.
4. For Android builds, restore the Gradle wrapper using a compatible Gradle distribution and configure the Android SDK / Java 17 paths locally.
5. Supply the missing raster launcher resources from artwork you are independently authorized to use before building the Android app.
6. For a release build, configure the original, separately held upload keystore and `android/key.properties`. Do not commit signing material.

The project uses Android contacts, notifications, and boot-completed permissions for explicitly described features. The app does not request INTERNET in its production manifest.

No build success, reproducibility, or source-to-binary match is promised by this snapshot.