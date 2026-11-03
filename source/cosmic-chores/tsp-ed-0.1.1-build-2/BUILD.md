## Android build caveats
The source commit contains `android/gradle/wrapper/gradle-wrapper.properties`, but does not contain the Gradle wrapper scripts or wrapper JAR. Regenerate a compatible wrapper or use an equivalent local Gradle setup before attempting an Android build.

The original Flutter asset `assets/cosmic_chores_launcher_master.png` and Android raster mipmap launcher images are intentionally omitted as branding/artwork. The existing pubspec and launcher XML still refer to these resources, so this snapshot is not build-complete until an authorized replacement/restoration is made and references are resolved.

The private development project uses local toolchain/environment scripts that are intentionally not included. Android SDK and Java paths must be configured for the local machine.

Release signing requires a separately held `android/key.properties` and keystore. Neither is included. Do not create a replacement key if this app already has an established upload key.

## Verification
No tests, analysis, APK build, installation, or device test was rerun for this publication. This is a source inspection snapshot, not a reproducible-build claim or a source-to-APK verification.