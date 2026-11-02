# Third-party components and notices

This project uses the Flutter/Dart SDK and the packages resolved in `pubspec.lock`. That lockfile is the authoritative version inventory for this snapshot. Each third-party component remains under its own upstream license; the Frogdadday source-available license does not replace or narrow those terms.

## Direct dependencies

| Package | Declared version | Role |
|---|---:|---|
| Flutter SDK | SDK | Application framework |
| `camera` | 0.12.1 | Camera preview and image capture |
| `flutter_test` | SDK | Widget and automated tests |
| `flutter_lints` | ^6.0.0 | Static analysis rules |

The lockfile also records transitive components, including the Android CameraX implementation. The full resolved inventory is in `pubspec.lock`.

## Full license inventory

For a complete local inventory of the resolved package licenses, run:

```sh
flutter pub get
flutter pub licenses
```

The Flutter SDK, Android Gradle tooling, AndroidX, and camera plugin also include third-party components with their own notices. Preserve those notices in any permitted local build or audit environment. No third-party package is represented as being owned by Frogdadday.
