# Third-party components and notices

Frog File Viewer uses the Flutter/Dart SDK and packages resolved in `pubspec.lock`. The lockfile is the authoritative resolved package inventory for this snapshot. Each third-party component remains under its own upstream license; the Frogdadday source-available license does not replace or narrow those terms.

## Direct dependencies

The project declares these direct dependencies:

- `dart_pdf_editor` and `dart_pdf_editor_assets` — PDF editing engine and offline editor assets
- `file_picker` — Android document-picker access
- `image`, `pdf`, and `archive` — image, PDF, and archive processing
- `camera` and `crop_your_image` — local document capture and crop workflow
- `path_provider` — app-local temporary storage
- `just_audio` and `video_player` — local media preview
- `pdfx` — PDF rendering
- `quds_office_engine` — local Office document conversion
- Flutter localization and Material support

The full resolved package graph, including transitive dependencies, is recorded in `pubspec.lock`. The generated `assets/THIRD_PARTY_NOTICES.txt` is bundled into the app and exposed through its in-app license screen. It includes the separately maintained native Android component inventory and font notices.

## Regenerate and review

After dependency changes, regenerate the notice bundle:

```sh
dart run tool/generate_third_party_notices.dart
```

Review `tool/android_third_party_components.json` against the actual resolved native Android dependency graph before distribution. This source snapshot includes the existing generated notices and inventory; their presence is not a legal certification of every license obligation.

Preserve third-party license and copyright notices in any permitted local audit environment. Do not represent third-party code, fonts, or dependencies as Frogdadday-owned material.
