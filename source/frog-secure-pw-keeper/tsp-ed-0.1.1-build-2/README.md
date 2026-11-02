# Frog Secure PW Keeper — TSP ed. 0.1.1 (build 2)

Public source snapshot for independent inspection, privacy review, and code transparency.

- App version: 0.1.1 · Android version code: 2
- Application ID: `app.grounded.password`
- Android 9 / API 28 minimum · SDK 36 target
- Source commit: `562225fdfa8ad004dc69a86840e274b4d8f720e6`
- [Published APK](https://github.com/frogdadday/frogdadday.github.io/releases/download/frog-secure-pw-keeper-v0.1.1/Frog-Secure-PW-Keeper-v0.1.1.apk)
- APK SHA-256: `36effae4b256a6ae712627b1f66e9131bc21d02386f5f6ea31dbd11306a21c1d`
- Signing certificate SHA-256: `2eebae504d8d6ba2cf22a751eb6309389ebc3936e37e1a0a324e5fb3c6edc2e5`

## Why this source is public

You should not have to take my word for how a password vault works. Inspect the cryptography, Android Keystore integration, manifest, storage, backup exclusions, clipboard handling, session lifecycle, password generator, and tests.

## Security design at a glance

- Portable vaults use PBKDF2-HMAC-SHA256 (600,000 iterations, random 128-bit salt) to derive a 256-bit key, then AES-256-GCM with a fresh 96-bit nonce and 128-bit authentication tag.
- The local vault receives an additional AES-256-GCM layer using a non-exportable Android Keystore key. StrongBox is requested when advertised, with standard Keystore fallback.
- The master password is not stored. There is no password reset or recovery service.
- The manifest requests **zero permissions**, including no Internet or storage permission. No runtime libraries, analytics SDKs, ads, accounts, WebViews, network services, or cloud sync.
- Vault data is stored under Android no-backup private storage. Automatic backup and device/cloud transfer are excluded.
- Manual import/export uses a password-encrypted `.gpv` file and Android's system picker. A selected cloud provider may upload that encrypted file; the app itself cannot connect to the network.
- Copied credentials are marked sensitive and the app attempts to clear its own clipboard item after 20 seconds. Android, keyboards, clipboard history and other apps may retain copies; this is best-effort, not a guarantee.

Read `SECURITY.md`, `OWASP_MOBILE_CHECKLIST.md`, and `VALIDATION.md` for design detail, recorded evidence, and remaining tests. This is not an independent security certification.

## Build

See `BUILD.md`. The snapshot includes the Android project, Java sources, resources, Gradle wrapper, JVM tests, and Android instrumentation tests. Private release signing material is excluded.

## APK audit and source correspondence

The public APK audit passed signature, package/version identity, and GitHub asset digest checks on October 22, 2026. [Audit workflow](https://github.com/frogdadday/frogdadday.github.io/actions/runs/39824425941).

The current source project's application ID, version name, and version code match the audited APK. The source snapshot commit is later than the APK release because it includes a developer-contact update. **This is a version-and-identity match, not a reproducible-build attestation.** No reproducible build proves that this exact APK was produced from this exact source commit. The audit is an artifact/signature check, not a security audit or Play upgrade-compatibility test.

## Important limitations

- Losing the master password means losing access to the vault and backups protected by it. There is no recovery bypass.
- Manual encrypted backups are portable but do not have the additional device-key wrapping used by the local vault.
- Clipboard expiry is best effort. Keyboards, clipboard managers, external apps, and Android itself may retain copied values.
- Rooted or compromised devices, malicious keyboards/accessibility services, external cameras, and OS compromise are outside the protection boundary.
- The OWASP MASVS/MASTG checklist is owner-maintained self-assessment, not independent certification. Additional OEM, physical-device, accessibility, and transfer checks remain pending.

## Ownership and license

Original application source is covered by `LICENSE.md`, a custom source-available license allowing inspection, audit, private non-commercial study, and narrowly defined GitHub-native review forks. It does not grant permission to publish compiled builds, redistribute source outside GitHub-native forking, rebrand, or commercially exploit the app.

Frogdadday branding, logos, frog mascot artwork, launcher artwork, and screenshots are excluded. Third-party components retain their own licenses; see `THIRD_PARTY_NOTICES.md`.
