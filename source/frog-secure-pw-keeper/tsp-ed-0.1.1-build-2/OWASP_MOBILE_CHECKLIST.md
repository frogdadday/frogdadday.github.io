# OWASP mobile security checklist

This is the practical security checklist for Frog Secure PW Keeper. It adapts the [OWASP Mobile Application Security Verification Standard (MASVS)](https://mas.owasp.org/MASVS/) and [Mobile Application Security Testing Guide (MASTG)](https://mas.owasp.org/MASTG/0x04b-Mobile-App-Security-Testing/) to an offline Android password vault.

It is an owner-maintained development record, not a security certification. **Verified** means automated checks or a named physical-device check passed. **Design-reviewed** means inspected in the code but still worth broader device testing. **Pending** is work to finish before a broad public release.

## Storage and privacy

| Status | Check | Evidence / next action |
| --- | --- | --- |
| Verified | Vault is encrypted before local storage. | AES-GCM ciphertext is wrapped again with Android Keystore; Moto G check found no plaintext secret on disk. |
| Verified | Tampered vault data fails closed. | JVM and Moto G checks modify ciphertext and confirm failure. |
| Verified | System backups do not include vault data. | `allowBackup=false`, backup-rule exclusions, no-backup storage, Moto G manifest check. |
| Verified | App requests no permissions, including Internet. | Moto G package check passed with zero requested permissions. |
| Design-reviewed | No analytics, ads, WebViews, cloud SDKs, or network code. | Source/dependency review; repeat after every dependency change. |
| Pending | Confirm device-transfer behavior on Samsung, Pixel, and another manufacturer. | Use a dummy vault only. |
| Verified | Import size is bounded before parsing. | 2 MiB limit and automated oversized-file tests. |
| Verified | Failed import cannot replace the vault. | Wrong-password and replacement-flow tests pass. |

## Cryptography

| Status | Check | Evidence / next action |
| --- | --- | --- |
| Verified | Master password is never stored. | No verifier or password preference; a derived key lives only during unlocked use. |
| Verified | Portable backups use established primitives. | PBKDF2-HMAC-SHA256, random salt, 600,000 iterations; AES-256-GCM with fresh nonce. |
| Verified | Header and data are authenticated. | Header is GCM additional authenticated data; tampering fails. |
| Verified | Local vault encryption uses Android Keystore. | Moto G round-trip and fresh-install recovery checks passed. |
| Verified | Losing a device key fails closed locally; encrypted export remains restorable by password. | Fresh-install recovery creates a new device key after restore. |
| Verified | Parser inputs have bounds and known-format checks. | Version/iteration allow-list; payload and field limits; structured errors. |
| Design-reviewed | Format can evolve safely. | v2 separates format version from KDF field; a KDF increase still needs migration tests. |
| Verified | `VaultCrypto`, `VaultStore`, and import/export paths are checked against this table. | Repeat the source review and automated regression suite after every security-sensitive change. |

## Authentication and sensitive data

| Status | Check | Evidence / next action |
| --- | --- | --- |
| Verified | Setup enforces 12 characters and recommends 16+ unique passphrases. | UI and tests. |
| Verified | Unlock failure avoids revealing whether password or vault data was wrong. | GCM authentication failures intentionally use one user message. |
| Verified | Vault locks on backgrounding and after selected inactivity. | Moto G checks passed for background and 1–5 minute timeout. |
| Verified | Secrets are excluded from intents, saved state, preferences, and logs. | Lifecycle/source review; retained export data is already password-encrypted. |
| Verified | Reveal is masked by default, lasts ten seconds, and can hide immediately. | Moto G checks passed. |
| Verified | Generated passwords use `SecureRandom`; length and no-symbol choices work locally. | Moto G checks passed. |
| Verified | Process termination while the import picker is open does not restore an unlocked vault or pending picker state. | Android 9 DocumentsUI virtual pass force-stopped the app while the real picker was open; relaunch returned to the locked screen. |

## Android protections

| Status | Check | Evidence / next action |
| --- | --- | --- |
| Verified | Screenshots and recording are blocked where Android honors `FLAG_SECURE`. | Moto G secure-window check passed and owner-confirmed screenshot/recording attempt captured no vault content; Pixel Tablet virtual capture was also black. Recheck on each release device. |
| Verified | Autofill, content capture, and personalized keyboard learning are excluded where supported. | View-tree configuration/source review. |
| Verified | Copied secrets are marked sensitive and expire after 20 seconds while foregrounded. | Moto G clipboard flag, expiry, manual lock, and denied-copy checks passed. Generic Android Studio API 28/API 36.1 emulators do not return the sensitivity metadata back to instrumentation, so they are not used to judge that platform behavior. |
| Design-reviewed | Clipboard cleanup behaves honestly when Android denies background access. | Foreground retry/ownership token; keyboard history can still retain data outside app control. |
| Verified | Export/import uses the system picker and asks for local storage. | SAF with `EXTRA_LOCAL_ONLY`; provider may still offer cloud storage. |
| Design-reviewed | Picker cancellation works through the real Android system picker. | Android 9 DocumentsUI virtual import was opened and cancelled, returning safely to the locked app. USB storage and OEM/cloud provider testing remain. |

## Resilience, accessibility, and release

| Status | Check | Evidence / next action |
| --- | --- | --- |
| Verified | Interrupted writes preserve the prior vault. | AtomicFile rollback tests passed. |
| Verified | Export reports write, flush, and close failures. | JVM failure-injection tests passed. |
| Verified | Cosmic Mode returns focus to its control. | Moto G check passed. |
| Verified | Tablet width keeps content readable and reachable. | Pixel Tablet API 36.1 virtual-device hierarchy shows a centered 1,440 px content column with all setup and bottom-row controls reachable. |
| Verified | Large text and landscape do not let fixed bottom controls overlap scrolling content. | Android 9 at 130% text and Android 16 tablet at 200% text keep scrolling content reachable. The Cosmic Mode label uses content-driven height. TalkBack, split screen, and foldable testing remain. |
| Design-reviewed | Minimum supported Android version works for vault encryption and core UI. | Android 9/API 28 virtual test passed its crypto, setup, auto-lock, Cosmic Mode, and generator stages; generic-emulator clipboard metadata reporting prevents counting its full suite as a pass. Physical non-StrongBox and another manufacturer remain. |
| Verified | Make and verify a signed, non-debuggable release build. | Version 0.1.1/build 2 was signed with the owner-controlled key; APK v2 verification passed and the key/password remain outside the repository. |

## How we use this

For every feature or release, use the relevant row, run its named check, and only mark it verified when evidence exists. Any new permission, dependency, external link, cloud behavior, or crypto-format change requires revisiting the affected rows.
