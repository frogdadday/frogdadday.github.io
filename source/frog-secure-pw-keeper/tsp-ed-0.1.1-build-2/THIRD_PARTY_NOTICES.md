# Third-party components and notices

Frog Secure PW Keeper is a native Java Android application with no runtime library dependencies.

Build tooling:
- Android Gradle Plugin 8.11.1
- Gradle wrapper 8.14
- JUnit 4.13.2 for JVM unit tests
- Android SDK/platform components from the installed SDK

The Gradle wrapper JAR/scripts and all Android/Gradle/JUnit components retain their upstream licenses. Nothing in Frogdadday's source-available license overrides third-party license terms.

Inspect resolved Gradle dependencies with:

```sh
./gradlew :app:dependencies
./gradlew :app:dependencies --configuration debugRuntimeClasspath
./gradlew :app:dependencies --configuration debugUnitTestRuntimeClasspath
```
