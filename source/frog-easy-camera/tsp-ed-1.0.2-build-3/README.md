# Frog Easy Camera — source snapshot

**Release identity:** Frog Easy Camera 1.0.2 · Android version code 3  
**Package ID:** `com.frogdadday.easy_camera`  
**Source commit:** `e3a36551bad8c6c1379e68fe9eccd70913e14d27`

This snapshot is published for independent inspection of Frog Easy Camera. It includes the Flutter/Dart application code, native Android implementation, production/debug/profile manifests, build configuration, launcher resources, tests, dependency lockfile, and Gradle wrapper.

It excludes APK/AAB release binaries, private signing keys, `android/key.properties`, local SDK/IDE paths, internal planning files, and the private key-generation helper script. The large original `assets/icon.png` binary is not included in this source snapshot; it is not declared as a Flutter runtime asset in `pubspec.yaml`. The Android launcher resources needed by the project are included. Frogdadday branding and artwork remain excluded from the license grant.

> **Source Code Notice — Inspection & Transparency**
>
> This source is published publicly so anyone can inspect, review, and audit how the software works.
>
> **Privacy & transparency:** Review the production Android manifest, permissions, application code, native storage implementation, and resolved dependencies. Check for analytics, advertising, tracking, and network functionality. Development and profiling variants may contain permissions that are not present in the production release.
>
> **Copyright & usage rights:** All rights reserved. Public access does not grant permission to commercially exploit, rebrand, redistribute, or publish compiled versions of this software. The only reuse permissions are the limited personal inspection, private non-commercial study, and GitHub-native review-fork permissions expressly stated in the accompanying license.
>
> The purpose of publication is transparency and independent inspection—not transfer of ownership or permission to reuse the work.
>
> *You shouldn't have to take my word for it. You can look.*

## Matching public APK status

This source snapshot is version `1.0.2+3`. The currently published Frog Easy Camera APK record on the website is **v1.0.1** (October 22, 2026). A matching v1.0.2 APK has not been published or verified as part of this snapshot. The older public APK record remains unchanged and must not be treated as a binary built from this source commit.

- Existing v1.0.1 APK SHA-256: `9f00847ec1e96787a4e5db4fb31d942128d35ee11b07715b48fa6449e2415b08`
- Existing signer certificate SHA-256: `25:EB:2C:3F:76:1B:95:CF:FB:D2:81:59:72:8D:75:68:30:F8:BD:18:FB:38:E1:98:CF:84:24:95:4F:D1:95:05`
- Existing APK record: [Frog Easy Camera website page](https://frogdadday.com/apps/frog-easy-camera.html)

## Source-to-release correspondence

This snapshot was prepared from the private development repository `frogdadday/Frog-Easy-Camera`, branch `main`, at commit:

```
e3a36551bad8c6c1379e68fe9eccd70913e14d27
```

That commit was recorded on October 28, 2026 at 21:08:39 UTC. Its `pubspec.yaml` declares `1.0.2+3`, package ID `com.frogdadday.easy_camera`. The public APK page currently records v1.0.1. These are separate version records; no source-to-binary match or reproducible-build attestation is claimed.

## Privacy and permissions visible in the source

The production manifest at `android/app/src/main/AndroidManifest.xml` declares CAMERA, SET_WALLPAPER, and legacy READ/WRITE_EXTERNAL_STORAGE permissions limited to Android 9/API 28 and older. It explicitly removes RECORD_AUDIO. The debug and profile manifests include INTERNET for Flutter development and profiling; inspect the merged release manifest before making claims about any locally built variant.

The camera is initialized with audio disabled. The reviewed application flow saves captured photos locally to the device's public Pictures/Frog Easy Camera album. This snapshot does not establish a third-party security review or a complete runtime audit across every Android device.

## Build and tests

See [SOURCE_SETUP.md](SOURCE_SETUP.md) and [BUILD.md](BUILD.md). Flutter widget tests and native Android storage-permission tests are included as source. Their inclusion does not claim they were rerun during snapshot publication.

## License and third-party materials

Original source code is provided under the custom [Source-Available Audit & Fork License](LICENSE.md). This is **source-available**, not OSI-approved open-source software. It permits personal inspection, private non-commercial study, and GitHub-native review forks only; it prohibits redistribution outside that narrow fork permission, commercial exploitation, rebranding, and publication of derivative app builds.

Frogdadday names, product names, logos, frog mascot artwork, app icons, screenshots, and other branding/artwork are excluded. Third-party dependencies and tools remain under their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Hosting location

This snapshot is hosted inside the public [Frogdadday website repository](https://github.com/frogdadday/frogdadday.github.io), under `source/frog-easy-camera/tsp-ed-1.0.2-build-3/`. It is not a standalone app-only repository. A GitHub-native fork of the parent repository includes the website as well as this source snapshot.
