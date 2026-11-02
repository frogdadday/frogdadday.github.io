# Frog File Viewer — TSP ed. source snapshot

**Published testing APK:** 0.2.1 · Android version code 3  
**Package ID:** `com.frogdadday.frog_file_viewer`  
**Source project version:** `0.2.1+3`  
**Source commit:** `e3fb51e1e70cb982798023f674fa32a6ab302665`

> **Source Code Notice — Inspection & Transparency**
>
> This source is published publicly so anyone can inspect, review, and audit how the software works.
>
> **Privacy & transparency:** Review the production Android manifest, permissions, application code, and resolved dependencies. Check for analytics, advertising, tracking, and network functionality. The release manifest explicitly removes Internet and network-state permissions. Debug/profile variants may differ; inspect the variant you are evaluating.
>
> **Copyright & usage rights:** All rights reserved. Public access does not grant permission to commercially exploit, rebrand, redistribute, or publish compiled versions of this software. The only reuse permissions are the limited personal inspection, private non-commercial study, and GitHub-native review-fork permissions expressly stated in the accompanying license. A review fork is not permission to publish an app or distribute a modified binary.
>
> The purpose of publication is transparency and independent inspection—not transfer of ownership or permission to reuse the work.
>
> *You shouldn't have to take my word for it. You can look.*

## What is included

This snapshot contains the Flutter/Dart application, native Android integration, production/debug/profile manifests, PDF and document services, offline camera scanner, file preview code, Cosmic Mode visuals and shader, launcher artwork and icon-generation tools, tests, dependency lockfile, and generated third-party notices.

The source was copied from the private development repository's `main` branch at the exact commit shown above. Internal planning and device-audit reports were not copied. No APK/AAB, keystore, signing passwords, `android/key.properties`, or local machine configuration is included.

## Matching public APK

- [Frog File Viewer v0.2.1 testing APK](https://github.com/frogdadday/frogdadday.github.io/releases/download/frog-file-viewer-v0.2.1/Frog-File-Viewer-v0.2.1.apk)
- Release tag: `frog-file-viewer-v0.2.1`
- Package ID: `com.frogdadday.frog_file_viewer`
- Version name: `0.2.1`
- Android version code: `3`
- APK size: `99,718,707` bytes
- APK SHA-256: `b8bbd4f9d53e2f094b55dd5338090525c37f7b09d1f5ed3956ca99e819de4efa`
- Signer certificate SHA-256: `cb109380f39383b5f86ec335936c1e5d782dc3292a6b7a8328d658118dc063e7`

The [public APK audit workflow](https://github.com/frogdadday/frogdadday.github.io/actions/runs/41158518079) verified the APK's Android signature, GitHub asset digest, package ID, version name, and version code. The same signing-certificate fingerprint was recorded for v0.2.0, so the website testing APK updates share the same signer. Google Play App Signing compatibility and real-device testing of this exact artifact were not checked by that audit.

## Source-to-APK correspondence

The source repository's `main` branch at commit `e3fb51e1e70cb982798023f674fa32a6ab302665` declares version `0.2.1+3`. The public APK audit reports version name `0.2.1`, version code `3`, and package ID `com.frogdadday.frog_file_viewer`. The source commit predates the public APK release.

These details establish a strong version, package, and chronology match. They are **not a reproducible-build attestation**: no evidence here proves that the exact APK bytes were generated from this exact source commit.

## Privacy and Android permissions

The production release manifest at `android/app/src/release/AndroidManifest.xml` explicitly removes `INTERNET` and `ACCESS_NETWORK_STATE`. The main manifest requests camera permission for the in-app document scanner and removes microphone and broad legacy external-storage permissions. Files are accessed through Android's user-selected document picker. Privacy/support links hand off to the external browser; the app does not embed those websites.

The source is intended for local/on-device file handling. Review the Dart code, native Android code, resolved package lockfile, native component inventory, and generated third-party notices yourself. No app can be certified private or secure solely by a README claim.

## Product scope and limitations

Frog File Viewer includes local PDF viewing/editing, markup, image placement into PDFs, image-to-PDF tools, selected document conversions, read-only previews for supported document and media formats, and an in-app camera scanner. Office/PDF conversion can be lossy; complex layouts, fonts, charts, formulas, forms, and scanned-image text are not guaranteed to survive. OCR, true redaction, and high-fidelity round-trip document conversion are not claimed.

Cosmic Mode is an opt-in visual treatment. The snapshot includes its motion, painters, frog artwork, and shader. It does not change saved documents. The app's local file tools remain the product; the visual effects are not a substitute for them.

## Build and tests

See [BUILD.md](BUILD.md), [SOURCE_SETUP.md](SOURCE_SETUP.md), and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The source repository's CI run for this commit completed dependency resolution, icon generation, analysis, all unit/widget tests, and Android debug APK build successfully. The final optional workflow artifact upload failed because GitHub Actions artifact storage quota was exhausted; the test and build steps themselves passed.

The public APK audit is a separate binary signature/hash/package/version check. It does not establish reproducible source provenance, Play signing compatibility, accessibility certification, or complete real-device validation.

## License and artwork

Original Frogdadday application source is provided under the custom [Source-Available Audit & Fork License](LICENSE.md). This is **source-available**, not OSI-approved open-source software. The license permits personal inspection, private non-commercial study, and GitHub-native review forks only. It restricts redistribution outside that narrow fork permission, commercial exploitation, rebranding, and publication of derivative app builds.

Frogdadday names, product names, logos, frog mascot artwork, app icons, screenshots, and other branding/artwork are excluded unless separately licensed. Third-party dependencies and their notices remain under their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Hosting location

This snapshot is hosted inside the public [Frogdadday website repository](https://github.com/frogdadday/frogdadday.github.io), under `source/frog-file-viewer/tsp-ed-0.2.1-build-3/`. It is not a standalone app-only repository. A GitHub-native fork of the parent repository includes the website as well as this source snapshot.
