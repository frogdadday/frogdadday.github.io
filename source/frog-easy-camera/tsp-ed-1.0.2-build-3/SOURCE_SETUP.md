# Frog Easy Camera — public source setup

This snapshot lives in a subdirectory of the public Frogdadday website repository rather than in a standalone app repository.

## Get the source

1. Open the [public source snapshot folder](https://github.com/frogdadday/frogdadday.github.io/tree/main/source/frog-easy-camera/tsp-ed-1.0.2-build-3/).
2. Clone the parent repository:

   ```sh
   git clone https://github.com/frogdadday/frogdadday.github.io.git
   ```

3. Open this snapshot's folder in Android Studio:

   `source/frog-easy-camera/tsp-ed-1.0.2-build-3/`

4. Install Flutter, the Android Studio Flutter plugin, Android SDK, and a compatible JDK.
5. From this folder, run `flutter pub get`.

## Check and build

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`.

The private signing key, `android/key.properties`, local SDK paths, IDE preferences, internal planning notes, and generated build output are intentionally excluded. A production-signed release requires the owner's private signing setup.

## Version identity

This source snapshot corresponds to the private source repository's `main` branch at commit `e3a36551bad8c6c1379e68fe9eccd70913e14d27`, with project version `1.0.2+3`. The website's currently published APK record is v1.0.1 and is not represented as built from this source commit.

## Development commitment

Free. Simple. Respectful. No advertisements, subscriptions, paywalls, or intentionally locked features.
