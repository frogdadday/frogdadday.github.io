# Frog Secure PW Keeper: source setup

This directory is a public inspection snapshot of TSP edition 0.1.1 (Android build 2).

1. Install Android Studio and Android SDK 36.
2. Install JDK 17 or 21.
3. Open this directory—the one containing `settings.gradle.kts`—in Android Studio.
4. Allow Android Studio to create `local.properties` with your local SDK path.
5. Run the commands in `BUILD.md`.

Use dummy credentials only. The instrumentation suite deliberately creates test vault data; never run it against a vault containing real credentials.

Private release signing material, passwords, local SDK paths, IDE run configurations, and internal developer instructions are excluded. The production manifest requests no permissions, including no Internet permission.

See `LICENSE.md`, `SECURITY.md`, and `VALIDATION.md` for usage rights, security design, and recorded test evidence.
