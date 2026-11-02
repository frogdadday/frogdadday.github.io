# Frog File Viewer — public source setup

This snapshot is hosted in a subdirectory of the public Frogdadday website repository, not in a standalone app repository.

## Get the source

1. Open the [public source snapshot folder](https://github.com/frogdadday/frogdadday.github.io/tree/main/source/frog-file-viewer/tsp-ed-0.2.1-build-3/).
2. Clone the parent repository:

   ```sh
   git clone https://github.com/frogdadday/frogdadday.github.io.git
   ```

3. Open `source/frog-file-viewer/tsp-ed-0.2.1-build-3/` in Android Studio or your Flutter editor.
4. Install Flutter 3.47+, Dart 3.13+, Android SDK API 36, Android Studio, and the required JDK.
5. From the snapshot directory, run `flutter pub get`.

## Check and build

```sh
dart run tool/generate_tie_dye_icons.dart
flutter analyze
flutter test
flutter build apk --debug
```

The generated launcher artwork and dependency notices are included in the source snapshot. If your local Android toolchain needs Gradle wrapper scripts, generate them locally with a compatible Gradle installation. The original repository did not track local wrapper scripts/JAR.

## Version identity

The source snapshot is copied from `frogdadday/Frog-PDF-Editor`, branch `main`, commit `e3fb51e1e70cb982798023f674fa32a6ab302665`, with project version `0.2.1+3`. The public APK audit reports the same package ID, version name, and Android version code. This is not a reproducible-build attestation.

## Development commitment

Free. Simple. Respectful. No ads, subscriptions, accounts, or paid unlocks. File processing is designed to remain local to the device.
