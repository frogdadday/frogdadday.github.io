# Validation — 10 October 2026 release-readiness fixes

- Replaced the user-facing test-build message and removed the planned outside-review dependency from current release guidance. The app now gives durable backup and no-password-reset guidance without claiming certification.
- Aligned the in-app privacy effective date and contact options with the public privacy page.
- Replaced the fixed-height Cosmic Mode label with content-driven sizing. An Android 16 tablet at 200% font scale reports a complete 44 px label region inside a 116 px control, with the bottom controls still reachable.
- Added adaptive normal, round and Android 13+ themed launcher resources while preserving the existing frog art. The previous launcher-shape lint warning is resolved.
- Clipboard ownership reads and clearing now contain unexpected runtime service failures and retain the ownership token for a later retry. Three new Android checks cover read failure, clear failure and successful retry.
- Search is debounced for 150 ms and vault entries render in batches of 100 with an explicit Show more control. A new JVM regression covers filtering and sorting all 2,000 supported entries.
- All 23 JVM tests passed. Release lint reports zero errors and nine non-release-blocking existing warnings (two unused assets, a programmatic custom-view constructor warning and English-only string warnings).
- Disposable Android 9/API 28 and Android 16/API 36 emulators each passed 59 main checks and six fresh-install restore checks. Generic-emulator clipboard metadata, OS expiry observation and manual-clear observation remain explicitly excluded; those three platform observations previously passed on the physical Moto G.
- Signed release APK/AAB build `0.1.1` (`versionCode` 2) completed with the owner-controlled 4,096-bit RSA key. APK v2 verification passed. AAB SHA-256: `1589A1A4E387FA9379BF2A66FA7432DD128DCB9AB19A607FDB61D4E73492B241`.

# Validation — 28 September 2026 controllers, diagnostics and usability

## Signed Google Play closed-test package

- Built `Frog Secure PW Keeper-0.1.0-closed-test.aab` with `versionCode` 1, `versionName` 0.1.0, package ID `app.grounded.password`, and an owner-controlled RSA 4,096-bit release key. Gradle received its signing values through temporary environment variables; no signing password or keystore was added to the repository.
- `bundleRelease` completed with release lint. Java signature verification completed successfully. The signer is self-signed, which is expected for a new Android upload/release key before Play distribution signing; verification warnings about a public CA chain and timestamp do not indicate an unsigned bundle.
- Bundle SHA-256: `fab9f83a19fd06acc47d9878e2f6961571525fafb20b56dcf7e8a9ca58f72dec`.

## OWASP review record

`OWASP_MOBILE_CHECKLIST.md` maps this app’s storage, cryptography, session, platform, resilience, and accessibility checks to OWASP MASVS/MASTG. It keeps verified evidence separate from source-reviewed assumptions and physical-device work that remains pending.

- Extracted `VaultController` for unlocked-session/local-vault orchestration and `BackupController` for encrypted backup state/provider I/O. No network or runtime dependency was added.
- Added safe backup failure categories for oversized files, unsupported versions, unreadable/damaged files, inaccessible storage, authentication failure, and authenticated restore storage failure. Wrong password and authenticated-data damage intentionally remain one category.
- Added local 16/20/24/32-character password generation with optional symbols. The generator continues to require uppercase, lowercase and digits and uses the platform `SecureRandom`.
- Cosmic Mode now restores focus to its control after the required acknowledgement dialog.
- Offline debug/test APK builds, 22 JVM tests, and debug lint passed. Lint reports zero errors and ten warnings (existing resource/icon/design-constructor/localization cleanup; none is a security failure).
- A fresh disposable API 36.1 emulator passed 58 main device checks, including the new focus and generator-option checks, plus six fresh-install recovery checks after removing the original vault and device key.
- Current debug APK SHA-256: `bf92eef090584a1f728342f978e5d5925c104cede7f35c02510c8f0302f0c032`.
- The updated build was then installed on a Moto G Power 5G (2023), Android 14/API 34. All 58 main device checks passed, including the new Cosmic Mode focus and password-generator option checks, encrypted import/export, clipboard expiry, background lock, and Activity recreation.
- Owner-confirmed physical Moto G screenshot/recording attempt while the vault was open produced no captured vault content. Together with the secure-window instrumentation check, this verifies `FLAG_SECURE` behavior on the physical Android 14 device.
- A disposable Android Studio Pixel Tablet API 36.1 emulator confirmed a 2560×1600 tablet layout: the readable content column is centered at 1,440 px wide and all setup, help, Cosmic Mode, and optional-support controls are reachable through the Android accessibility hierarchy. An `adb screencap` of the active vault window was fully black, confirming `FLAG_SECURE` is honored by that virtual device. The emulator’s full crypto instrumentation runner did not complete reliably during this cold boot, so its partial run is not counted as a passed security suite.
- Downloaded the free Android 9/API 28 image and tested the app on a disposable Pixel 2 profile, matching the app’s minimum supported Android version. Encryption, tamper rejection, local Keystore wrapping, setup, auto-lock setting, Cosmic Mode focus, and password-generator checks passed through the clipboard stage. Generic Android Studio emulators on both API 28 and API 36.1 did not return clipboard sensitivity metadata to the instrumentation process; the physical Moto G did return it and passed that check. This platform-reporting difference is recorded rather than counted as a virtual pass.
- The Android 9 virtual large-text (130%) landscape pass revealed that fixed bottom controls overlapped scrolling Unlock/Import controls. `MainActivity` now measures the bottom controls and reserves their actual height from the scroll viewport. The repeated check shows the scroll viewport ending at y=886 and the lowest fixed control beginning at y=891, with no overlap.
- Android 9’s actual DocumentsUI import picker was opened through the app’s confirmation flow and then cancelled. The app returned to its locked import screen. The app was also force-stopped while DocumentsUI was open; after the picker closed and the app relaunched, it remained locked with no pending picker state. Export write/flush/close and import replacement behavior remain covered by provider-backed automated checks; this additional pass exercises the real Android picker UI and cancellation path.

## Historical validation — 27 September 2026 reliability fixes

- Offline debug app/test APK builds, 20 JVM tests, and debug lint passed. Lint has zero errors and nine warnings. Signing configuration was not changed.
- All 55 main instrumentation checks passed on a physical Moto G Power 5G (2023), Android 14 / API 34, using the owner's explicitly authorized disposable test vault.
- Four new JVM tests cover provider-stream close failure, storage-full write failure, flush failure, and successful exact output/close (including a null provider stream).
- Phone regressions verify that a denied replacement copy preserves the previous clipboard cleanup deadline, the real foreground clipboard expires, recreation retains the encrypted pending export while leaving the vault locked, and a missing export snapshot produces an explicit interruption message. Actual Android activity recreation was exercised; missing-snapshot handling was simulated at the activity-result boundary rather than killing the process mid-picker.
- Export requests truncation and only reports success after write, flush, and close complete. The test provider is queried through ContentResolver, respecting its separate process/UID; tests no longer try to read its private cache from the target app.
- A separate six-check recovery run passed after clearing the disposable target app's data. It first verified the original vault AND Keystore alias were absent, then restored the exported dummy backup through the real import path and verified exact credentials under a newly created device key. This is fresh-install recovery on the same physical phone, not a claim of separate-device testing.
- Debug APK SHA-256: `2a439f9d6fb85445931fce713b50a541fe019f618a4d0b71daa5ad5ed8fbb9b8`.
- Remaining release validation: physical tablets/other manufacturers, real OEM picker navigation and cancellation, actual process kill during the picker, physical storage/power failures, TalkBack and display-cutout layouts, and OEM transfer behavior. Provider write failures are fault-injected, not a physical disk-full experiment. This test record is not a security certification.

## Historical validation — 24 September 2026 usability update

- Repaired the build execution context: stopped the stale Gradle 8.14 daemon and started a replacement with approved SDK/cache access. A normal daemon build succeeded, followed by a full `--rerun-tasks` build (71 tasks executed). The replacement remained healthy and idle. No SDK ACL changes, SDK reinstallation, or permanent daemon disabling were needed.
- Normal offline `assembleDebug`, `assembleDebugAndroidTest`, `testDebugUnitTest`, and `lintDebug` passed. All 16 JVM tests passed; lint reports zero errors and nine warnings.
- All 45 instrumentation checks passed on a fresh disposable API 36.1 emulator image, including the renamed timeout and lock controls, clipboard expiry, search/editing, exported backup restoration, import rejection/replacement, and background lock.
- Local field hints, the short help explanation, and the temporary backup checklist compile into the app. Physical-device visual/large-text/TalkBack validation remains pending; the instrumentation suite is not a visual audit.
- Debug APK SHA-256: `336558a461fe72201cf43dfaded9431f78ce7cb2b24f5c411e71e61c4c9edd72`.

## Historical validation — 23 September 2026 review build

- Offline `assembleDebug`, `assembleDebugAndroidTest`, `testDebugUnitTest` and `lintDebug` succeeded.
- 15 JVM tests passed, zero failures/skips (14 vault tests and one generator policy test).
- Lint: zero errors, nine warnings (unused assets, launcher shape, design-time constructor, English UI literals). Drawing-allocation warnings were resolved.
- Android 16/API 36.1: 45 instrumentation checks passed on a separate disposable emulator data image. No physical phone or existing emulator vault was used.
- Coverage includes local generation/masking, selectable timeout, immediate hide and timed remask, secure dialog flags, 20-second foreground clipboard expiry, manual-lock cleanup, crypto/storage, editing/search, export/import and background lock.
- The first fresh-emulator run timed out waiting for vault creation during heavy first-boot load. After allowing 120 seconds instead of 30 in the test-only UI wait helper, the complete rerun passed. Production cryptography and timeout settings were not weakened.
- Failed-save draft restoration and activity-recreation races were source-reviewed and compiled; this run did not fault-inject those UI cases. Physical-device visual/TalkBack/large-text checks remain pending.

Current debug APK SHA-256: `cfcbd7d1aaacd5be81518e8f1c598926d39c84e5e6fd2e5c0e86790c338d26ba`.

## Historical validation — 22 September 2026

The results and hash below apply to the earlier build, not the current APK.

## Completed

- Offline Gradle build: `assembleDebug`, `assembleDebugAndroidTest`, `testDebugUnitTest`, `lintDebug` succeeded.
- 12 JVM tests passed, 0 failed, 0 skipped.
- Android lint: no issues found.
- Android 16/API 36.1 emulator: 38 checks passed through the custom instrumentation runner.
- APK signature verification succeeded (v2 signature, debug signer).
- Actual APK permission inspection (`aapt dump permissions`): no requested permissions.
- Merged application manifest inspected: no test provider/service, no INTERNET permission, `allowBackup=false`, both backup-rule resources present, secure activity configuration. Debuggable is true intentionally for this development artifact.

Build environment: JBR 21.0.11, Gradle 8.14, Android Gradle Plugin 8.11.1, SDK 36. The initially selected Java 25 runtime was incompatible with this Gradle version; no app defect was involved. All successful builds used Java 21 and cached build dependencies, without adding app runtime dependencies.

## Emulator coverage

- No requested permissions; backup disabled.
- Real Android Keystore generation and encryption/decryption across repository instances.
- Local disk wrapping distinct from portable ciphertext; no dummy secret present in raw local file.
- Password-only portable restore, wrong-password rejection, failed-authentication preservation.
- Atomic-file interrupted-write rollback and local ciphertext tamper rejection.
- Master-password creation, unlock, credential creation/save, hidden password, temporary reveal.
- Foreground sensitive clipboard marking, actual 20-second expiry, explicit-lock clearing.
- Search, editing, deletion, background lock and removal of entry views.
- Production ContentResolver export/import I/O using a **test-only** document provider, valid backup restore, wrong import password preserving the current vault, and confirmed replacement.

The file-provider checks inject a selected document at the activity-result boundary. They test the app's production read/write and restore behavior, not interactions with each manufacturer's file-picker UI. The exported test provider exists only in the instrumentation APK, never in the application APK.

The first emulator boot stalled. A cold boot with two virtual cores and Vulkan disabled succeeded. The first instrumentation attempt encountered a System UI ANR/focus loss; its clipboard assertion incorrectly dereferenced a denied/null clipboard description. The test was corrected to check focus and handle null safely, the system dialog was dismissed, and subsequent full runs passed. No tests are reported as passed based on that failed attempt.

## Still required before production use

- Physical Android devices, minimum API 28, hardware-backed/StrongBox behavior and Keystore loss.
- Actual provider-picker navigation and cancel/retry flows across local/USB/OEM providers.
- Separate-device restoration, process termination/power-loss cases and full/failed storage.
- Timed inactivity lock under real input, rotation, screen-off, multi-window and accessibility use.
- Clipboard background/process-death limitations and keyboard clipboard-history behavior.
- OEM backup/device-transfer behavior and screenshot/recording attempts on physical devices.
- Visual/accessibility review with TalkBack, large text, landscape and different displays.
- Repeat the internal security checklist and production signing/release process.

The APK is debug-signed and debuggable. Use dummy credentials. Passing these checks is not a security certification.

## Artifact

`app-debug.apk`

SHA-256: `22e9a5931055d5b3dd8aef61c49da19047a1d2609b6a3827578e77336e33d83a`
