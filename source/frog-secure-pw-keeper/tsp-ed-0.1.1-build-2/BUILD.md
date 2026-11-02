# Building Frog Secure PW Keeper

## Requirements

- Android Studio and Android SDK 36
- JDK 17 or 21
- Android Gradle Plugin 8.11.1
- Gradle 8.14 (included wrapper)

Java 25 is incompatible with this pinned Gradle version.

## Debug build and tests

Open this directory in Android Studio and allow it to create local SDK configuration. Then run:

```sh
./gradlew assembleDebug testDebugUnitTest lintDebug assembleDebugAndroidTest
```

On Windows:

```bat
gradlew.bat assembleDebug testDebugUnitTest lintDebug assembleDebugAndroidTest
```

The debug APK is at `app/build/outputs/apk/debug/app-debug.apk`; the instrumentation APK is under `app/build/outputs/apk/androidTest/debug/`.

The app has no runtime dependencies. Gradle downloads build plugins and JUnit test dependencies from their configured repositories if not cached.

## Release signing

The private release key and passwords are not included. Release signing reads environment variables `FROG_RELEASE_STORE_FILE`, `FROG_RELEASE_STORE_PASSWORD`, `FROG_RELEASE_KEY_ALIAS`, and `FROG_RELEASE_KEY_PASSWORD`. Do not request, commit, or publish these values or a keystore.

This snapshot supports source inspection, local debug builds, unit tests, lint, and instrumentation builds. It does not contain the private release signing key.
