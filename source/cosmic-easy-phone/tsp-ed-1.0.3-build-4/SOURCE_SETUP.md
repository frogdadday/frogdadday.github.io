# Cosmic Easy Phone — public source setup

This snapshot lives in a subdirectory of the public Frogdadday website repository rather than in a standalone app repository.

## Get the source

1. Open the [public source snapshot folder](https://github.com/frogdadday/frogdadday.github.io/tree/main/source/cosmic-easy-phone/tsp-ed-1.0.3-build-4/).
2. Clone the parent repository:

   ```sh
   git clone https://github.com/frogdadday/frogdadday.github.io.git
   ```

3. Open this snapshot's folder in Android Studio:

   `source/cosmic-easy-phone/tsp-ed-1.0.3-build-4/`

4. Install Flutter, the Android Studio Flutter plugin, Android SDK, and JDK 21.
5. From this folder, run `flutter pub get`.

## Check and build

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`.

The private signing key, `android/key.properties`, local SDK paths, IDE preferences, and generated build output are intentionally excluded. A production-signed release requires the owner's private signing setup.

## Note on version identity

This source snapshot corresponds to the source repository's `main` branch at commit `adf6ffc1e81fcdb8f75b5de02aa9364aa232baf1`, with project version `1.0.3+4`. See [RELEASE-METADATA.json](RELEASE-METADATA.json) for the reference APK and audit evidence. The version identity is matched; a reproducible source-to-binary build has not been established.

## Development commitment

Free. Simple. Respectful. No advertisements, subscriptions, paywalls, or intentionally locked features.
