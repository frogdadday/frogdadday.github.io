# Build notes — Cosmic Chores 0.1.1+2

## Toolchain
- Flutter: 3.47.8 (project-local toolchain requirement documented by the private project helper)
- Android compile SDK: 36
- Android target SDK: 36
- Java/Kotlin target: 17
- Android application ID: `com.frogdadday.cosmicchores`
- Minimum Android SDK: 24

## Commands
```sh
flutter pub get
flutter analyze
flutter test
```

## Android build caveats
The source commit contains `android/gradle/wrapper/gradle-wrapper.properties`, but does not contain the Gradle wrapper scripts or wrapper JAR. Regenerate a compatible wrapper or use an equivalent local Gradle setup before attempting an Android build.

The private development project uses local toolchain/environment scripts that are intentionally not included. Android SDK and Java paths must be configured for the local machine.

Release signing requires a separately held `android/key.properties` and keystore. Neither is included. Do not create a replacement key if this app already has an established upload key.

## Verification
No tests, analysis, APK build, installation, or device test was rerun for this publication. This is a source inspection snapshot, not a reproducible-build claim or a source-to-APK verification.