# Cosmic Spinner — public source setup

This snapshot is stored in a subdirectory of the public Frogdadday website repository, not in the private development repository.

## Get the source

```sh
git clone https://github.com/frogdadday/frogdadday.github.io.git
cd frogdadday.github.io/source/cosmic-spinner/tsp-ed-1.0.3-build-4
```

Install Flutter 3.47.8 (or a compatible version satisfying the Dart SDK constraint), Android Studio, Android SDK, and a compatible JDK.

## Inspect and test

```sh
flutter pub get
flutter analyze
flutter test
```

The Android project does not include Gradle wrapper scripts/JAR in the source commit. Configure or regenerate a local wrapper before attempting an Android APK build. Production signing credentials are intentionally not included.

## Source identity

Private source repository: `frogdadday/Cosmic-Spinner`  
Branch: `main`  
Commit: `a40aba27a1c9192e40eff2599731162560335ff7`  
Project version: `1.0.3+4`  
Android application ID: `com.frogdadday.cosmicspinner`

The public website's current APK record is v1.0.2, not this source version.
