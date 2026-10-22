# Frogdadday Android APK distribution

The website has **ten prepared APK pages**, including **Frog File Viewer**. Self Destruct and Ghost Box are deliberately excluded. Source repositories and all keystores remain private. Website downloads are separate from Google Play distribution.

## Release tag and APK filename rules

Each app's APK must be published to the **public website repository's GitHub Releases**: https://github.com/frogdadday/frogdadday.github.io/releases

| Public app name | Release tag | APK asset filename |
| --- | --- | --- |
| Cosmic Converter | `cosmic-converter-vX.Y.Z` | `Cosmic-Converter-vX.Y.Z.apk` |
| Cosmic Spinner | `cosmic-spinner-vX.Y.Z` | `Cosmic-Spinner-vX.Y.Z.apk` |
| Cosmic Chores | `cosmic-chores-vX.Y.Z` | `Cosmic-Chores-vX.Y.Z.apk` |
| Cosmic Dice | `cosmic-dice-vX.Y.Z` | `Cosmic-Dice-vX.Y.Z.apk` |
| Cosmic Easy Phone | `cosmic-easy-phone-vX.Y.Z` | `Cosmic-Easy-Phone-vX.Y.Z.apk` |
| Frog Easy Camera | `frog-easy-camera-vX.Y.Z` | `Frog-Easy-Camera-vX.Y.Z.apk` |
| Frog Cleaner | `frog-cleaner-vX.Y.Z` | `Frog-Cleaner-vX.Y.Z.apk` |
| Frog Secure PW Keeper | `frog-secure-pw-keeper-vX.Y.Z` | `Frog-Secure-PW-Keeper-vX.Y.Z.apk` |
| Frog Construction Toolkit | `frog-construction-toolkit-vX.Y.Z` | `Frog-Construction-Toolkit-vX.Y.Z.apk` |
| Frog File Viewer | `frog-file-viewer-vX.Y.Z` | `Frog-File-Viewer-vX.Y.Z.apk` |

Use the **actual build's** semantic version in both the release tag and asset name. Example for Frog Easy Camera v1.0.1:

- Tag: `frog-easy-camera-v1.0.1`
- File: `Frog-Easy-Camera-v1.0.1.apk`

The shared `apps/apk-downloads.js` checks up to 100 public GitHub Releases and selects the highest version it finds per app. It ignores drafts, prereleases, missing files, incorrectly named files, and zero-byte assets. The homepage badge updates dynamically. It does **not** cryptographically verify APK signatures, file security, or compatibility.

## Safe release procedure

1. Confirm the app is release-ready: complete relevant automated tests, real-device tests, privacy and permission checks, dependency license review, and app-specific release gates. In particular, PDF conversions, construction calculations, and the password vault require additional validation.
2. Build a **release APK** on your development PC, using the app's permanent signing key. The usual Flutter command is `flutter build apk --release`. This assumes a working local keystore configuration; **do not assume the build is signed correctly just because it compiled**.
3. Verify the APK with the Android SDK's `apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk`. Confirm the expected signing certificate and final Android package ID. Keep `versionCode` increasing for updates.
4. Test **that exact signed APK** on an Android device before distributing it; test permissions, functionality, install, and upgrade. For apps using Play App Signing, confirm certificate compatibility separately: an independently signed website APK may not upgrade a Play-installed copy.
5. Copy or rename the verified APK to the matching asset filename. Never publish signing keys, `.jks` files, `key.properties`, passwords, private code, or debug builds.
6. Open the website repository's [Releases](https://github.com/frogdadday/frogdadday.github.io/releases) and create a public release with the precise tag and asset filename. Provide notes, publish as a **normal release**, and not a draft or prerelease.
7. Visit the relevant [app page](https://frogdadday.github.io/#apps) and confirm the direct APK button appears with the correct version and file size. Download it as a website visitor and verify installation on your Moto. If the link doesn't show, confirm naming, publication status, GitHub API access, and browser/network restrictions.
8. Review any prose, privacy policy, testing status, and Play Store links for accuracy when a release becomes public. The homepage badges can update dynamically, but other editorial text may need a manual release update.

## Special notes

- **Frog File Viewer** is the public website name for the source repository `Frog-PDF-Editor`. The installed app label currently remains **Frog PDF Editor** and the package ID stays `com.frogdadday.frog_file_toolkit`. Renaming the Android display label safely can be done separately without changing the package ID or signing identity. Its privacy policy is a draft and on-device conversion fidelity testing is outstanding. The existence of its website page is not a release sign-off.
- No page downloads or stores APKs automatically; GitHub stores public release assets. No separate app auto-updater, telemetry, or paid service is added.
- Android may ask users to enable app installation from their browser/file manager. Users should heed platform security warnings and turn the permission back off afterward if they enabled it.
- Download availability indicates the release asset exists, **not** that GitHub or the site has performed a malware scan or certificate verification.
- The browser contacts GitHub's public releases API to check availability. Public rate limits or temporary API failure can prevent the link from appearing even if an APK exists.
