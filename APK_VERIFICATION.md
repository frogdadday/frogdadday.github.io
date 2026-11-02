# Published APK verification

The website publishes Android APKs through GitHub Releases. Being published through GitHub Releases **does not by itself mean an app's signing key, source integrity, security or update behavior has been independently verified**.

## Actual binary audit

GitHub Actions workflow: https://github.com/frogdadday/frogdadday.github.io/actions/workflows/verify-release-apks.yml

The read-only audit script (`scripts/audit_published_apks.py`) downloads **each actual public APK**, checks its file size and SHA-256 against the GitHub release digest, validates its APK signature with Android SDK `apksigner`, rejects Android Debug signing, and extracts the Android package ID and version using `aapt dump badging`. The package ID is compared with the expected package mapping in the audit script, and the APK version name with its release tag. This check does not prove that an APK was built from a particular source commit.

Results appear as a downloadable workflow artifact named `frogdadday-public-apk-audit` containing `apk-release-audit.json`. The audit exits with failure if a release is missing or invalid. It does **not** need any private signing keystore.

### What this does **not** verify

- Whether the certificate matches the app-signing certificate used for the Google Play-distributed version.
- Whether the signer is the original intended developer or if a signing key was improperly replaced (compare the recorded fingerprint against a trusted baseline in Play Console or your secure records).
- Whether the release passed security review, physical-device tests, accessibility, data-safety declarations, or domain-specific calculations.

Compare the recorded signer fingerprints to the *trusted* certificate for the corresponding app. Keep the signed APKs available for independent installation testing. Do not publish unreviewed packages just because a workflow is green.

## Cosmic Converter TSP edition source snapshot

The inspectable TSP ed. source snapshot for Cosmic Converter 1.0.6+9 is published at `source/cosmic-converter/tsp-ed-1.0.6-build-9/`. Its Android package ID, version name, and version code agree with the audited public APK. The source snapshot records the source commit and the APK SHA-256 and signer-certificate fingerprint. This is a useful version-and-identity relationship, not a reproducible-build attestation: the current process does not prove byte-for-byte that the APK was built from that exact source commit. Google Play App Signing compatibility is also not checked by this workflow.

The website also exposes the SHA-256 **file** digest from the current GitHub API when provided. That checksum can help visitors compare their download against GitHub's reported bytes; it is **not an Android signing certificate**.

When a release is removed or GitHub's release API is unavailable, the site does not advertise a static/stale download link.


## Frog File Viewer TSP edition source snapshot

The inspectable Frog File Viewer source snapshot for version 0.2.1+3 is published at `source/frog-file-viewer/tsp-ed-0.2.1-build-3/`. Its package ID, version name, and Android version code match the audited public testing APK. The snapshot records the source commit, APK SHA-256, and signer-certificate fingerprint. This is a version-and-identity match, not a reproducible-build attestation. The APK audit does not establish Google Play App Signing compatibility or real-device testing of that exact artifact. The app remains explicitly labeled a testing release; document conversion fidelity and broader device validation are still ongoing.


## Frog Cleaner TSP edition source snapshot

The inspectable Frog Cleaner source snapshot for version 1.0.2+4 is published at `source/frog-cleaner/tsp-ed-1.0.2-build-4/`. Its package ID, version name, and Android version code match the audited public APK. The snapshot records the source commit, APK SHA-256, and signer-certificate fingerprint. This is a version-and-identity match, not a reproducible-build attestation. The APK audit does not establish Google Play App Signing compatibility or real-device testing of that exact artifact.

The production manifest has no Internet permission, but it does declare optional `MANAGE_EXTERNAL_STORAGE` and an Accessibility service for user-started cache-only automation. Those permissions and behaviors require independent review and applicable Google Play policy approval; this source publication is not evidence of such approval.
