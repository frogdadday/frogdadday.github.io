# Cosmic Converter — TSP ed. source snapshot

**Release identity:** Cosmic Converter 1.0.6 · Android version code 9  
**Package:** `com.frogdadday.cosmicconverter`  
**Edition note:** This release includes the US teaspoon and tablespoon conversion additions.

This is the source snapshot published for independent inspection of the TSP edition. It includes the Flutter/Dart application code, Android project files, tests, dependency lockfile, and the privacy policy supplied with the app. It deliberately excludes private signing materials, release checklists, development notes, AAB/APK binaries, and unrelated platform templates.

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

## Match to the public APK

The matching direct-download APK is:

- [Cosmic Converter v1.0.6 APK](https://github.com/frogdadday/frogdadday.github.io/releases/download/cosmic-converter-v1.0.6/Cosmic-Converter-v1.0.6.apk)
- Package ID: `com.frogdadday.cosmicconverter`
- Version name: `1.0.6`
- Android version code: `9`
- APK size: `50,718,891` bytes
- APK SHA-256: `f91a16e83ea806ac5862202da885c69cb202c5cc8d8f5a328abc2d9114bf3b24`
- APK signer certificate SHA-256: `75629ea4bf37607a7e05b97d4ccf631e58476ebc567481b5981acf84e363f59a`

The public APK audit report recorded a valid APK signature, matching GitHub asset digest, expected package ID, version name, and version code. [View the audit workflow run](https://github.com/frogdadday/frogdadday.github.io/actions/runs/40860335989).

## Source identity and limits

This snapshot was prepared from the private development repository's `main` branch at source commit:

```
633a25451ca02d8083dd56cadf321cb025301246
```

The snapshot's `pubspec.yaml` version `1.0.6+9` agrees with the audited APK's version name `1.0.6` and version code `9`. The source commit predates the public APK release. This is a version-and-identity match, **not a reproducible-build attestation**: the available evidence does not prove that the exact APK bytes were generated from this exact commit. The audit workflow verifies the published APK's signature structure and metadata, not source-to-binary equivalence or Google Play App Signing compatibility.

## Privacy and network behavior

The release Android manifest (`android/app/src/main/AndroidManifest.xml`) does not request `android.permission.INTERNET`. The debug and profile manifests do include INTERNET for development/profiling; those variants are not the Play release manifest. The app code uses the external browser for its privacy-policy and optional Buy Me a Coffee links. The optional support link does not unlock features.

The app privacy policy is included as `privacy_policy.html`. The published policy is also available at [frogdadday.com](https://frogdadday.com/-Cosmic-Converter-Privacy-Policy/).

## Build and tests

See [BUILD.md](BUILD.md). The permanent Android signing key and `android/key.properties` are deliberately not included. A developer can inspect the source and run tests without receiving the private signing key. A release-signed build requires the owner's private signing setup.

## License and artwork

The source code is provided under the custom [Source-Available Audit & Fork License](LICENSE.md). This is **source-available**, not OSI-certified open-source software. The license permits personal inspection, private non-commercial study, and GitHub-native review forks only; it prohibits redistribution outside that narrow fork permission, commercial exploitation, rebranding, and publication of derivative app builds.

Frogdadday names, logos, frog mascot artwork, app icons, screenshots, and other branding/artwork remain reserved unless separately licensed. Third-party dependencies remain under their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and `pubspec.lock`.

## Where this snapshot is hosted

For immediate public inspection, this version is kept under the existing public Frogdadday website repository at `source/cosmic-converter/tsp-ed-1.0.6-build-9/`. The parent repository is public and can be forked on GitHub. This is not a standalone app-only repository; a future dedicated source repository may supersede this location without changing the source snapshot or APK release identity.
