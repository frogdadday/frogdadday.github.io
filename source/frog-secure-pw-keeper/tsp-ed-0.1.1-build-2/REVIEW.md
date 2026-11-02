# Security and usability review — September 23, 2026

Scope: local vault framing and encryption, storage, activity lifecycle, clipboard, native UI, Cosmic Mode rendering, backup boundary and test harness. This records source review and regression evidence; it is not a security certification.

## Fixed in this pass

| Finding | Change |
| --- | --- |
| Separate activity instances could perform vault I/O on separate workers | One process-wide serial worker, plus a setup existence check immediately before creation |
| Keyboard and accessibility interaction could miss the inactivity reset | Focused text changes and button actions explicitly refresh the timer |
| Repeated reveals queued multiple timers and retained detached views | One cancellable reveal timer, immediate hide button and navigation/lock cleanup |
| A failed save discarded edits from the form | Return the draft for retry only while the originating session remains unlocked |
| Clipboard cleanup denied during manual lock could wait for the old expiry | Mark cleanup immediately due before trying Android clipboard access |
| Dialogs relied on the activity's secure-window behavior | Explicit secure flag on every app dialog window |
| Sensitive accessibility data relied on defaults | API 34+ sensitive-data marker, with assistive tools retained; proper field labels and heading semantics |
| Encoding an oversized vault allocated its full payload before rejection | Check the size after each encoded entry |
| Frog and heart drawing allocated paths/arrays every frame | Reuse drawing objects and create the heart gradient on size changes |
| Device tests did not reject an existing vault until after storage tests | Reject at the beginning before creating keys or files |

## Usability additions

- A local 20-character generator using platform SecureRandom; generated values stay masked. Replacing a filled field requires confirmation, and saving remains explicit.
- Progress indicators during encryption/unlock, inline missing-title feedback, and a wrapping Privacy & help button for larger font settings.
- Clipboard wording acknowledges Android's background limits instead of promising guaranteed expiry.

## Remaining priorities

1. Validate on physical phones and tablets: TalkBack, large fonts, keyboard behavior, clipboard timing, landscape and real document pickers. The current narrow footer still deserves visual inspection at extreme font sizes.
2. Add master-password change with current-password verification, fresh salt/key, atomic replacement and failed-write recovery tests. Existing exports must remain readable with their original password. This deserves its own focused change.
3. Before changing PBKDF2 parameters, implement an actual per-file derivation and migration path. The v2 metadata introduced previously does not by itself implement KDF migration. Current v1 and v2 files both use 600,000 iterations, and older app versions cannot read v2 exports.
4. Repeat the internal crypto/lifecycle checklist and verify release signing for every production bundle. Debug APKs remain development artifacts and must never be distributed as production releases.

Keep the existing offline architecture and simple interface. Biometrics, cloud sync, advertising, telemetry, and subscriptions are not needed to make this app useful or polished.

## Device compatibility update

The activity is explicitly resizable and uses `adjustResize` for software keyboards. A centered 720dp maximum content column prevents phone-style forms from becoming overly wide on tablets, foldables, ChromeOS, and desktop windows while remaining full-width on narrow displays. Bottom controls and scroll content consume system-bar and IME insets on Android 11+, with the platform's legacy fit behavior on Android 9–10. Export uses the broadly supported `ContentResolver` write mode and import guards against a nonstandard zero-byte read from a document provider.
