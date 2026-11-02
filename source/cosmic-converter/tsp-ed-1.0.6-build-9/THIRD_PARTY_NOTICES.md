# Third-party components and notices

This project uses the Flutter/Dart SDK and packages resolved in `pubspec.lock`. The lockfile is the authoritative version inventory for this snapshot. Each third-party component remains under its own upstream license; the Frogdadday source-available license does not replace or narrow those third-party terms.

## Direct package dependencies

| Package | Locked version | Purpose |
|---|---:|---|
| Flutter SDK | SDK | Application framework |
| `cupertino_icons` | 2.0.0 | Icon font package |
| `flutter_launcher_icons` | 0.14.4 | Launcher icon generation |
| `url_launcher` | 6.3.3 | Opens the privacy policy and optional external support page |
| `flutter_test` | SDK | Test framework |
| `flutter_lints` | 6.0.0 | Static analysis rules |

Package pages and upstream license files are available from [pub.dev](https://pub.dev/). The transitive dependency inventory and exact versions are in `pubspec.lock`.

## Full license inventory

For a local, complete inventory of the resolved package licenses, run:

```sh
flutter pub get
flutter pub licenses
```

The Flutter SDK and Android Gradle tooling also include third-party components with their own notices. Preserve those notices in any permitted local build or audit environment. No third-party package is represented as being owned by Frogdadday.
