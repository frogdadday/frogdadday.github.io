# Third-party components and notices

The project uses the Flutter/Dart SDK and the dependencies resolved in `pubspec.lock`. That lockfile is the authoritative resolved package inventory for this snapshot. Each third-party component remains under its own upstream license; the Frogdadday source-available license does not replace or narrow those terms.

## Direct dependencies

| Package | Version/source | Role |
|---|---|---|
| Flutter | SDK | Application framework |
| flutter_test | SDK (development) | Automated tests |
| flutter_lints | ^6.0.0 (development) | Static analysis rules |

The project currently has no third-party runtime package listed under `dependencies`; the resolved development packages and transitive dependencies are recorded in `pubspec.lock`.

## Generate the full license inventory

With the matching Flutter SDK installed, run:

```sh
flutter pub get
flutter pub licenses
```

Flutter/Dart SDK components, Android Gradle tooling, AndroidX, and other platform components may carry separate third-party notices. Preserve their notices in any permitted local audit or build environment. No third-party package is represented as being owned by Frogdadday.
