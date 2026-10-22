# Frog Easy Camera — publish a website APK

**Private source remains private.** Only upload the finished, signed Android APK to the *public website repository* as a GitHub Release asset. Do not push your source, .jks keystore, key.properties, or signing passwords.

The Easy Camera app page checks published releases from `frogdadday/frogdadday.github.io`. Until a release with a correctly named APK exists, it shows **Public APK not available yet** and no download button.

## Release checklist

1. On your Windows development computer, open the **Frog-Easy-Camera** Flutter project. Confirm `android/key.properties` and your permanent signing keystore exist. If not, follow the project's local key-generation instructions and **back up the original key and passwords**, not a newly generated key for an existing installed version. Do not upload keys to GitHub.
2. Run `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release`. A generated release APK is **not proof that it was signed**: verify it with Android SDK's `apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk`, confirm the certificate fingerprint is the expected permanent one, and check the result on a real phone.
3. Confirm the app version in `pubspec.yaml`. For the currently inspected code it is `1.0.1+2` (website name version `1.0.1`). Future releases should increment the Android version code and retain the signing certificate.
4. Rename or copy the signed, tested APK for the public download. For version **1.0.1**, the file must be **`Frog-Easy-Camera-v1.0.1.apk`**.
5. Open [website repository releases](https://github.com/frogdadday/frogdadday.github.io/releases) → **Draft a new release**. Create tag **`frog-easy-camera-v1.0.1`**, upload **`Frog-Easy-Camera-v1.0.1.apk`**, add release notes, and publish as a normal public release (not draft or prerelease). Never attach your signing keys.
6. Open [the public Easy Camera page](https://frogdadday.github.io/apps/frog-easy-camera.html). After GitHub's release API updates, the Download button should appear automatically. Test the download and installation on your Moto.
7. When it's publicly downloadable, update the main homepage and release wording/status accordingly. Do not claim public availability before the release asset exists.

For later releases, use `frog-easy-camera-vX.Y.Z` as the tag and `Frog-Easy-Camera-vX.Y.Z.apk` as the matching asset. The page automatically selects the highest version among up to 100 published website releases.

**Security:** A website APK install may require the Android "install unknown apps" permission. Never advise users to bypass malware warnings. For an app that is also installed from Google Play, compare the installed certificate with the public APK's certificate before promising seamless updates; Play App Signing may use a different certificate.
