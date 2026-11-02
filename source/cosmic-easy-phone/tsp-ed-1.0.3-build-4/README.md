# Cosmic Easy Phone — TSP ed. source snapshot

**Release identity:** Cosmic Easy Phone 1.0.3 · Android version code 4  
**Package ID:** `com.frogdadday.android_toolkit`  
**Source commit:** `adf6ffc1e81fcdb8f75b5de02aa9364aa232baf1`

This is the source snapshot for independent inspection of the Cosmic Easy Phone TSP edition. It contains the Flutter/Dart application code, native Android implementation, manifest and build configuration, launcher artwork, tests, dependency lockfile, and Gradle wrapper.

It deliberately excludes APK/AAB release binaries, private signing keys, `android/key.properties`, local SDK/IDE paths, and internal project-planning notes. The published privacy policy remains available separately at [frogdadday.com](https://frogdadday.com/cosmic-easy-phone-privacy/).

> **Source Code Notice — Inspection & Transparency**
>
> This source is published publicly so anyone can inspect, review, and audit how the software works.
>
> **Privacy & transparency:** Review the production Android manifest, permissions, application code, and resolved dependencies. Check for analytics, advertising, tracking, and network functionality. Development and profiling variants may contain permissions that are not present in the production release; the manifest notes in this README explain the distinction.
>
> **Copyright & usage rights:** All rights reserved. Public access does not grant permission to commercially exploit, rebrand, redistribute, or publish compiled versions of this software. The only reuse permissions are the limited personal inspection, private non-commercial study, and GitHub-native review-fork permissions expressly stated in the accompanying license. A review fork is not permission to publish an app or distribute a modified binary.
>
> The purpose of publication is transparency and independent inspection—not transfer of ownership or permission to reuse the work.
>
> *You shouldn't have to take my word for it. You can look.*

## Matching public APK

- [Cosmic Easy Phone v1.0.3 APK](https://github.com/frogdadday/frogdadday.github.io/releases/download/cosmic-easy-phone-v1.0.3/Cosmic-Easy-Phone-v1.0.3.apk)
- Package ID: `com.frogdadday.android_toolkit`
- Version name: `1.0.3`
- Android version code: `4`
- APK size: `53,536,958` bytes
- APK SHA-256: `3cc39d296ad3725c1bd14f7c3203fafbfd22ce4a703118b0a953f7abd5cca4e8`
- APK signer certificate SHA-256: `fa78e32cf14fb91f7fc3245d0a14f461f8f17d8ef7f687795b024a70f806a5cf`

The [public APK audit workflow](https://github.com/frogdadday/frogdadday.github.io/actions/runs/40976447001) recorded a valid Android APK signature, a matching GitHub asset digest, and the package ID, version name, and version code shown above. The audit also recorded that Google Play App Signing compatibility and real-device testing were not checked.

## Source-to-APK correspondence

This snapshot was prepared from the private development repository `frogdadday/cosmic-easy-phone`, branch `main`, at commit:

```
adf6ffc1e81fcdb8f75b5de02aa9364aa232baf1
```

That commit was recorded on October 29, 2026 at 23:48:45 UTC. The APK asset was uploaded at 23:54:37 UTC and the release was published at 23:56:21 UTC. The source `pubspec.yaml` declares `1.0.3+4`; the APK audit reports version name `1.0.3`, version code `4`, and package ID `com.frogdadday.android_toolkit`.

These details establish a close chronological and version/identity match. They are **not a reproducible-build attestation**: the available evidence does not prove that the exact APK bytes were generated from this exact source commit.

## Privacy and permissions visible in the source

The production manifest does not request `android.permission.INTERNET`. It explicitly removes `RECORD_AUDIO` and `ACCESS_NETWORK_STATE`. The debug and profile manifests include INTERNET for Flutter development and profiling; they are not the production release manifest.

The production manifest declares permissions for alarms, modifying selected system settings, the camera, and wallpaper. Legacy `WRITE_EXTERNAL_STORAGE` is limited to Android 9/API 28 and older, for saving camera photos. The app's camera flow explains access before requesting it. The app opens the external browser for its privacy-policy and optional Buy Me a Coffee links; the optional support link does not unlock features.

No advertising, analytics, attribution, crash-reporting, or tracking package is declared in this snapshot's `pubspec.yaml` or `pubspec.lock`. The lockfile is included so reviewers can inspect the full resolved dependency inventory.

## Build and tests

See [SOURCE_SETUP.md](SOURCE_SETUP.md) and [BUILD.md](BUILD.md). The automated widget tests and launcher-artwork test are included. They are supplied as source; this publication does not claim that those tests were rerun during snapshot publication.

## License and artwork

Original source code is provided under the custom [Source-Available Audit & Fork License](LICENSE.md). This is **source-available**, not OSI-approved open-source software. The license permits personal inspection, private non-commercial study, and GitHub-native review forks only; it prohibits redistribution outside that narrow fork permission, commercial exploitation, rebranding, and publication of derivative app builds.

Frogdadday names, product names, logos, frog mascot artwork, app icons, screenshots, and other branding/artwork are excluded unless separately licensed. Third-party dependencies and tools remain under their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Hosting location

This snapshot is hosted inside the public [Frogdadday website repository](https://github.com/frogdadday/frogdadday.github.io), under `source/cosmic-easy-phone/tsp-ed-1.0.3-build-4/`. It is not a standalone app-only repository. A GitHub-native fork of the parent repository includes the website as well as this source snapshot.
