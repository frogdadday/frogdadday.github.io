# Frog Cleaner: release scope and validation

The public release must be complete within an agreed scope: no placeholders,
unfinished paths, misleading claims, paywalls, ads, or tracking.

## Implemented release-candidate scope

- Separate Flutter Android application; original shared frog painter reused.
- Local Android Storage Access Framework folders with persistent grants.
- Background metadata traversal, cancellation, 20,000-entry scan bound, partial
  result reporting, canonical document-ID deduplication, unknown metadata handling.
- Largest-first review, size/age/category filters, search, file metadata and opening.
- Storage Map that ranks scanned folders by contained file sizes and supports
  drill-down to the files in a folder.
- On-demand exact duplicate comparison using complete-file SHA-256 fingerprints,
  grouped review, no automatic selection, and a keep-one-copy selection guard.
- Focused Downloads Review for installers, archives, large files, and older
  downloads, with largest-first ordering and no automatic selection.
- Persistent file/folder exclusions and access removal.
- Explicit permanent-deletion confirmation listing every selected file.
- Android-system-confirmed Trash for selected media files during full device
  analysis; permanent deletion remains a separate action.
- Interrupted permanent-deletion and Android Trash requests are recorded on
  device and reconciled on the next launch before further file actions.
- Native metadata revalidation, per-file failure reporting, no automatic selection.
- Duplicate removal rechecks that a retained copy still exists immediately before
  a selected group can be removed.
- Optional Android 11+ full-device analysis: Android's own special-access screen
  controls `MANAGE_EXTERNAL_STORAGE`; no automatic prompt or hidden scan. It
  enumerates shared storage with an 80,000-entry safety bound, while excluding
  `Android/data` and `Android/obb`. The limited SAF folder flow remains available.
- No broad package visibility, Usage Access, media, notification, or network permission
  in the main manifest. Debug builds have Flutter's development network permission.
  No cloud providers; only the platform local-storage provider.
- No filenames or scan results uploaded. Preference backup disabled.

## Public-release gates

1. Verify the optional full-device-analysis path on Android 11+ devices. Complete
   Downloads scanning is not promised through SAF because its root is restricted.
   Before Play submission, confirm Frog Cleaner's core file-management use case,
   complete Google's all-files-access declaration, and pass its review. The
   limited-access flow must remain useful when optional access is denied.
2. Test actual file enumeration, previews, exclusions, overlapping roots,
   permission revocation, SD card removal, Unicode paths, large trees, interruption,
   changed files and partial deletion on real devices and supported Android versions.
3. Verify interruption recovery and Android Trash behavior on real devices. Never
   report trashed bytes as freed space.
4. Finish UI/accessibility/device QA, launcher branding, signed release packaging,
   privacy documentation, Play listing and policy declarations.
5. Validate the final selection and native deletion boundary. Metadata checks cannot
   eliminate concurrent replacement or same-size/same-timestamp edits. This build
   does not claim an atomic content identity guarantee.
6. Exercise large media previews and cache cleanup on lower-memory devices.

## Later expansion of a finished product

Exact duplicates first; optional app statistics second. History, scheduled scans,
similar photos and compression remain separate scope decisions. Do not add dead
navigation for any future feature.

## Android and Play references

- https://developer.android.com/training/data-storage/shared/documents-files
  Folder restrictions, persisted grants, provider flags, document deletion.
- https://support.google.com/googleplay/android-developer/answer/10467955
  All-files access is restricted and must be justified and approved for Play.
- https://developer.android.com/training/data-storage/shared/media
  MediaStore confirmation/trash path if added later.

Optional Accessibility-service automation is a narrow, user-started cache-only
flow. It has a separate in-app disclosure, a persistent Stop control, and refuses
to act when the selected app’s Settings panel cannot be verified. Root access and
private-data cleaning are not part of the architecture.
