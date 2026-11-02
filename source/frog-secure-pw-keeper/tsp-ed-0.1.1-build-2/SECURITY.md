# Security design

This password manager uses Android/JCA cryptographic primitives and maintains an app-specific verification checklist. These test records are not a security certification. The small file framing is application serialization, not a new cipher, KDF, or authentication algorithm.

## Password and portable encryption

PBKDF2-HMAC-SHA256 derives a 256-bit key from the master passphrase with a random 128-bit salt and 600,000 iterations. The platform `SecretKeyFactory` implementation is used. PBKDF2 is available on the minimum Android version and avoids bringing native cryptographic dependencies into the first build. Argon2id should be considered in a future reviewed format revision, with performance measurements and a migration plan.

AES-256-GCM uses the derived key, a fresh random 96-bit nonce for every encryption, and a 128-bit authentication tag. The header is authenticated as additional authenticated data. All entry metadata is inside the ciphertext. There is no separate password verifier or plaintext search index. Authentication succeeds only if the GCM tag and payload validation succeed.

The master password is not stored. Mutable password/key/plaintext byte arrays are cleared when practical. A session owns a copy of the derived key only while unlocked; worker operations already authorized may finish after a lock, but stale results cannot unlock the UI. Java/Android strings, editable buffers, crypto provider copies, garbage collection and heap copies prevent a claim of guaranteed memory erasure. Rooted devices, debuggers, malicious keyboards/accessibility services and a compromised OS are outside this protection boundary.

The setup minimum is 12 characters, and the UI recommends a unique 16+ character passphrase. This is guidance rather than a local strength score. No recovery bypass exists. Password rotation and strength estimates are deferred.

## Local device wrapping

The password-encrypted blob receives an additional AES-256-GCM encryption layer using a generated, non-exportable Android Keystore key. StrongBox is requested when advertised; `StrongBoxUnavailableException` falls back to the regular Android Keystore. Hardware backing depends on the device and is not claimed universally. The key is not biometric-bound in Phase 1.

The Keystore key alone cannot decrypt vault contents: the password-derived encryption remains underneath. Conversely, a raw copied local file cannot be unlocked with the password alone without its device key. Loss of that key fails closed. A manually exported `.gpv` backup is portable and needs only its password. Keep such backups securely: they allow offline password guessing without the additional device-key protection.

Storage uses `Context.getNoBackupFilesDir()` and `AtomicFile`. New ciphertext is written before committing replacement. Android's atomic replacement provides crash-recovery behavior, not a guarantee against storage hardware failure or malicious rollback. Flash storage may retain older encrypted blocks; secure physical deletion is not promised. Changes and deletions do not affect older exported backups.

## Portable formats and KDF evolution

All integers are big endian. Maximum file size is 2 MiB. Import accepts only known format versions and the current fixed KDF work factor before attempting any KDF. This bounds file allocation and prevents hostile headers requesting unbounded KDF work. Existing v1 backups remain readable. New and re-saved vaults use v2, which separates the format version from the KDF work-factor field so a reviewed future release can add a strictly allow-listed migration.

| Bytes | v1 meaning |
| --- | --- |
| 0–7 | ASCII `GRNDPW01` (format version) |
| 8–11 | PBKDF2 iterations: 600000 |
| 12–27 | Salt (16 bytes) |
| 28–39 | GCM nonce (12 bytes) |
| 40 onward | Encrypted payload followed by 16-byte GCM tag |

| Bytes | v2 meaning |
| --- | --- |
| 0–7 | ASCII `GRNDPW02` (format family) |
| 8–11 | Explicit format version: 2 |
| 12–15 | PBKDF2 iterations: 600000 |
| 16–31 | Salt (16 bytes) |
| 32–43 | GCM nonce (12 bytes) |
| 44 onward | Encrypted payload followed by 16-byte GCM tag |

The complete header is GCM AAD. Payload: version integer 1, entry count, then five `DataOutputStream.writeUTF` strings per entry (UUID, title, username, password, website). Limits: 2,000 entries; 4,096 UTF-16 code units per field; valid UUIDs; unique IDs; nonblank titles; no trailing bytes. `writeUTF` uses Java's modified UTF-8, not standard UTF-8. The corresponding `DataInputStream` parser is used. The entire plaintext payload is authenticated before parsing. This format is not KeePass-compatible.

The local outer file uses ASCII `GRNDDEV1`, a 12-byte Keystore-generated nonce, and GCM ciphertext/tag. `GRNDDEV1` is its AAD. Local files are deliberately not accepted as portable exports.

## Lifecycle and platform protections

`FLAG_SECURE` applies to the activity, including setup, unlock and entry views. The app is excluded from recents, does not save view state and removes secret views on lock. Autofill is disabled for the view tree; IMEs receive the no-personalized-learning request. Content capture is excluded on supported API levels. These are platform protections, not defenses against a compromised OS or external camera.

The vault locks in `onPause` and after a user-selected 1–5 minute inactivity interval (one minute by default). That non-secret preference is the only app setting stored outside the encrypted vault. Background or rotation discards edits. A generation counter prevents an asynchronous authentication result from reopening a locked/backgrounded session. File-picker flows retain only password-encrypted data. No plaintext or key is placed in an Intent or saved-instance Bundle. No URI grants are retained.

The pending password-encrypted export survives configuration changes via a retained non-configuration object; it does not retain the Activity, master password, or unlocked session. A saved-state boolean records only whether an export was pending. After process death, the ciphertext is unavailable and the app explicitly asks the user to unlock and export again instead of silently ignoring the returned picker result. Ciphertext is wiped after completion or cancellation. Export success requires successful stream write, flush, and close; a failure may leave an incomplete destination and is reported as such.

Clipboard data is flagged sensitive and given an opaque ownership token. Cleanup only removes the app's own current clip, preserving newer unrelated copies. A 20-second handler attempts expiry and retries on foreground return. Explicit/idle lock attempts immediate clearing. Background lock retains the copy briefly to permit cross-app paste. Android focus rules, process death, keyboards and clipboard managers mean expiry is not guaranteed. No background service, alarm, or extra permission is introduced to imply otherwise.

A replacement copy commits its ownership token and replaces the cleanup timer only after the platform set operation returns successfully. If Android throws while attempting a new copy, the previous token and cleanup deadline remain active. Instrumentation injects this denial and verifies the previous clip still expires.

## Backup and offline boundary

The manifest requests zero permissions, including no `INTERNET` or storage permissions. There are no WebViews, SDKs, analytics, network services or runtime dependencies. `allowBackup=false`, legacy exclusions and Android 12+ cloud/device-transfer exclusion rules complement no-backup storage. OEM backup behavior should still be tested before release.

Export/import is explicit through the Storage Access Framework. `EXTRA_LOCAL_ONLY` is requested. A provider can ignore this and offer cloud storage, so the confirmation screen explains the boundary: the app itself has no network access, but an external provider can upload the encrypted file. Claims that passwords can *never* leave the device would be false given intentional export and clipboard use.

## Release gates

### September 23 review changes

- Password generation uses platform `SecureRandom.nextInt(bound)` with rejection sampling for upper/lower/digit inclusion and, when enabled, symbol inclusion. The user can choose 16, 20, 24, or 32 characters and can disable symbols for incompatible sites. Generation is entirely local, masked in the editor, and never automatically copied or saved.
- `VaultController` owns the unlocked session and local encrypted-vault orchestration. `BackupController` owns only password-encrypted import/export state and provider I/O. UI construction remains in `MainActivity`; this boundary keeps lifecycle decisions visible while making cryptographic state transitions separately reviewable.
- Portable framing errors are classified as oversized, unsupported version, unreadable/damaged, or inaccessible storage before password entry. Authentication deliberately keeps wrong-password and authenticated-data damage together because AES-GCM does not reveal which caused authentication to fail. A successfully authenticated import that cannot be stored is reported separately and does not replace the existing vault.
- Cosmic Mode returns accessibility and keyboard focus to its own control after the acknowledgement dialog closes. Pausing still cancels the animation and locks the vault.
- All app dialog windows explicitly receive `FLAG_SECURE`. On API 34+, the root view marks accessibility data sensitive; assistive tools remain available. This is not protection against a malicious service claiming to be an accessibility tool. See [Android View API](https://developer.android.com/reference/android/view/View#setAccessibilityDataSensitive(int)).
- Keyboard edits and accessibility button clicks refresh inactivity timeout. Reveal timers are cancelled on navigation/lock, with an immediate hide action. Manual clipboard cleanup remains due if Android initially denies access.
- Vault I/O uses one process-wide serial worker across activity recreation. Queued setup refuses to overwrite an already-created vault. Payload encoding enforces its size limit as entries are written, rather than allocating the whole oversized payload first.
- Failed saves restore the draft only in the still-unlocked originating activity; leaving or locking still discards it. The draft is never written to preferences or saved state.

The v2 header currently accepts only 600,000 iterations. A separate header field is format preparation, not a completed work-factor migration: increasing the work factor still requires per-file derivation, old-parameter support, fresh-salt rekeying after successful authentication, atomic replacement, and compatibility tests. Old app versions cannot read v2 exports. Keep existing backups before updating or downgrading.

### Remaining validation

- Repeat the cryptography, format/parser, lifecycle-race and Keystore-failure checklist for every security-sensitive change.
- Physical-device tests on minimum API, current Android, StrongBox and non-StrongBox devices.
- File-provider cancellation, short writes, storage exhaustion, abrupt process death and OEM transfer behavior.
- Restore a manual backup on a separate installation/device with no original Keystore key.
- Real keyboard/clipboard behavior, TalkBack, large text, landscape and focus interruptions.
- Broader physical-device testing and the final public-release packaging checklist. Release bundles are signed with an owner-controlled 4,096-bit RSA key held outside this repository; its password is not embedded in source or Gradle files.

## References

- [Android cryptography](https://developer.android.com/privacy-and-security/cryptography): platform AES-GCM and Keystore guidance.
- [Android Keystore](https://developer.android.com/privacy-and-security/keystore): non-exportable keys and StrongBox behavior.
- [OWASP password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html): PBKDF2-HMAC-SHA256 work factor guidance; not a claim of FIPS certification.
- [Android secure clipboard handling](https://developer.android.com/privacy-and-security/risks/secure-clipboard-handling): sensitive flag and expiry considerations.
- [Android automatic backup](https://developer.android.com/identity/data/autobackup): no-backup storage and cloud/device-transfer rules.
