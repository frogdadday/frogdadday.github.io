# Frogdadday Android APK distribution

The website has **ten prepared APK pages**, including **Frog File Viewer**. Nine apps currently have public APK files; Frog File Viewer has no public APK. Self Destruct and Ghost Box are deliberately excluded. Source repositories and all keystores remain private. Website downloads are separate from Google Play distribution.

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

The shared `apps/apk-downloads.js` checks up to 100 **current** public GitHub Releases and selects the highest version it finds per app. It ignores drafts, prereleases, missing or incorrectly named files, and zero-byte assets. It has **no hardcoded fallback**: if GitHub cannot confirm a release, the page does not display a download button. The homepage badge updates dynamically with the version. Each app page also contains a dated record of the publicly inspected APK's file SHA-256 and extracted signing-certificate SHA-256, along with a plain link to the GitHub Releases listing when JavaScript cannot load. The record may become historical when a new APK ships; it is not a static direct download link. If GitHub provides an asset SHA-256 digest for a newer APK, the page displays that current integrity checksum. Neither availability nor a matching checksum independently verifies the APK's Android signing certificate, permissions, security, or installation behavior.

## Safe release procedure

1. Confirm the app is release-ready: complete relevant automated tests, real-device tests, privacy and permission checks, dependency license review, and app-specific release gates. In particular, PDF conversions, construction calculations, and the password vault require additional validation.
2. Build a **release APK** on your development PC, using the app's permanent signing key. The usual Flutter command is `flutter build apk --release`. This assumes a working local keystore configuration; **do not assume the build is signed correctly just because it compiled**.
3. Verify the APK with the Android SDK's `apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk`. Record and compare the signing-certificate SHA-256 fingerprint against the intended permanent key and prior public releases. Confirm the package ID with `apkanalyzer manifest application-id <apk>` or `aapt dump badging <apk>`, check version code, and keep `versionCode` increasing. Use `Get-FileHash -Algorithm SHA256 <apk>` on a downloaded release and compare against GitHub's public asset digest or the page's checksum (if present). That confirms file integrity relative to GitHub's digest, not developer identity.
4. Test **that exact signed APK** on an Android device before distributing it; test permissions, functionality, install, and upgrade. For apps using Play App Signing, confirm certificate compatibility separately: an independently signed website APK may not upgrade a Play-installed copy.
5. Copy or rename the verified APK to the matching asset filename. Never publish signing keys, `.jks` files, `key.properties`, passwords, private code, or debug builds.
6. Open the website repository's [Releases](https://github.com/frogdadday/frogdadday.github.io/releases) and create a public release with the precise tag and asset filename. Provide notes, publish as a **normal release**, and not a draft or prerelease.
7. Visit the relevant [app page](https://frogdadday.github.io/#apps) and confirm the direct APK button appears with the correct version and file size. Download it as a website visitor and verify installation on your Moto. If the link doesn't show, confirm naming, publication status, GitHub API access, and browser/network restrictions.
8. Review any prose, privacy policy, testing status, and Play Store links for accuracy when a release becomes public. The homepage badges can update dynamically, but other editorial text may need a manual release update.

## Special notes

- **Frog File Viewer** is now also the app's Android launcher label and in-app name. Its permanent Android package ID is `com.frogdadday.frog_file_viewer`, its Flutter package is `frog_file_viewer`, and its release signing configuration expects the `frog-file-viewer-upload` alias. The private GitHub source repository is still called `Frog-PDF-Editor`. The private permanent key must be created and backed up locally before the first signed release; no keystore or password is hosted here. Its privacy policy is a draft and on-device conversion fidelity testing is outstanding. The existence of its website page is not a release sign-off.
- No page downloads or stores APKs automatically; GitHub stores public release assets. No separate app auto-updater, telemetry, or paid service is added.
- Android may ask users to enable app installation from their browser/file manager. Users should heed platform security warnings and turn the permission back off afterward if they enabled it.
- Download availability indicates the release asset exists, **not** that GitHub or the site has performed a malware scan or certificate verification.
- The browser contacts GitHub's public releases API to check availability. Public rate limits or temporary API failure can prevent the link from appearing even if an APK exists.

## Maintaining a published release

- **Withdrawn/replaced files:** delete or unpublish an incorrect GitHub Release and verify the live app page no longer lists it. The live API is the only availability source. If GitHub's API is unreachable, the site hides download buttons rather than advertising stale files. Browser caches and already downloaded files cannot be remotely recalled.
- **Permanent keys and Play updates:** keep a secure inventory of each app's Android package ID, certificate SHA-256 fingerprint, Play App Signing relationship, version code, human release test status, and release file SHA-256. Those cannot be inferred merely from GitHub release metadata.
- **No signed-APK claim from the website:** a GitHub Release is not an independent Android signature audit. Run release checks on the exact public APK and document any incompatibility.
- **Optimized artwork:** WebP derivatives only affect website transfer size, not APK signing or launcher resources. Original image assets remain intact.
