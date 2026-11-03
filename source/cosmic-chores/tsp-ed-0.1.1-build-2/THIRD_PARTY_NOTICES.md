# Third-party notices — Cosmic Chores

This source snapshot does not attempt to reproduce a complete legal inventory of every SDK, tool, transitive dependency, or platform component.

The declared Flutter package dependencies are:
- Flutter SDK (runtime framework)
- Flutter Test (development/test dependency, supplied by Flutter SDK)
- flutter_lints (development-only lint configuration)

The lockfile records the resolved Dart/Flutter package graph, including transitive packages. Their respective authors and licenses retain all rights under their own license terms. Android Gradle Plugin, Kotlin, Gradle, Android SDK, Java, and Flutter SDK components are also governed by their respective upstream licenses.

To inspect the package license inventory in a compatible Flutter environment, run:

```sh
flutter pub get
flutter pub licenses
```

This generated inventory should be reviewed alongside the Android/Gradle toolchain and platform notices before redistribution or other use. No claim is made that this file is a complete third-party license inventory.