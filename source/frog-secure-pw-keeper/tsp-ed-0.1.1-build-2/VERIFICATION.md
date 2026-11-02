# Frog Secure PW Keeper: verification record

This summarizes the verification scope associated with the source snapshot and published APK. It is not a security certification.

## Published APK identity audit

The public APK signature workflow completed successfully on October 22, 2026.

- Release: `frog-secure-pw-keeper-v0.1.1`
- APK: `Frog-Secure-PW-Keeper-v0.1.1.apk`
- APK SHA-256: `36effae4b256a6ae712627b1f66e9131bc21d02386f5f6ea31dbd11306a21c1d`
- Signing certificate SHA-256: `2eebae504d8d6ba2cf22a751eb6309389ebc3936e37e1a0a324e5fb3c6edc2e5`
- Package ID: `app.grounded.password`
- Version name: `0.1.1`
- Version code: `2`

[Audit workflow](https://github.com/frogdadday/frogdadday.github.io/actions/runs/39824425941)

The workflow log reports nine public APKs valid and zero flagged. It does not establish Google Play App Signing compatibility, reproducible source-build provenance, or independent security review.

## Project test record

The owner-maintained validation record reports 23 JVM tests passing, release lint with zero errors, and disposable Android 9/API 28 and Android 16/API 36 emulator runs with 59 main checks and six fresh-install restore checks each. It also records physical Moto G Power 5G (2023) testing of vault setup/unlock, cryptography, tamper rejection, clipboard behavior, import/export, and lifecycle behavior.

The project checklist leaves additional physical-device/OEM transfer behavior, separate-device restore, broader accessibility testing, and some picker/device-transfer cases pending. See `VALIDATION.md` and `OWASP_MOBILE_CHECKLIST.md` for the full dated record. These are owner-maintained development tests, not independent verification of every property or certification of the app.
