# Published APK verification

The website lists nine public Android APKs. Being published through GitHub Releases **does not by itself mean an app's signing key, source integrity, security or update behavior has been independently verified**.

## Actual binary audit

GitHub Actions workflow: https://github.com/frogdadday/frogdadday.github.io/actions/workflows/verify-release-apks.yml

The read-only audit script (`scripts/audit_published_apks.py`) downloads **each actual public APK**, checks its file size and SHA-256 against the GitHub release digest, validates its APK signature with Android SDK `apksigner`, rejects Android Debug signing, and extracts the Android package ID and version using `aapt dump badging`. The package ID is compared with the app's currently recorded private-source configuration, and the APK version name with its release tag.

Results appear as a downloadable workflow artifact named `frogdadday-public-apk-audit` containing `apk-release-audit.json`. The audit exits with failure if a release is missing or invalid. It does **not** need any private signing keystore.

### What this does **not** verify

- Whether the certificate matches the app-signing certificate used for the Google Play-distributed version.
- Whether the signer is the original intended developer or if a signing key was improperly replaced (compare the recorded fingerprint against a trusted baseline in Play Console or your secure records).
- Whether the release passed security review, physical-device tests, accessibility, data-safety declarations, or domain-specific calculations.

Compare the recorded signer fingerprints to the *trusted* certificate for the corresponding app. Keep the signed APKs available for independent installation testing. Do not publish unreviewed packages just because a workflow is green.

The website also exposes the SHA-256 **file** digest from the current GitHub API when provided. That checksum can help visitors compare their download against GitHub's reported bytes; it is **not an Android signing certificate**.

When a release is removed or GitHub's release API is unavailable, the site does not advertise a static/stale download link.
