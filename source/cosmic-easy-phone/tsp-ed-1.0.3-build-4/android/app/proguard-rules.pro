# Flutter's Gradle plugin supplies the engine keep rules. Keep the Android
# entry point explicitly because it is also the MethodChannel bridge.
-keep class com.frogdadday.android_toolkit.MainActivity { *; }
