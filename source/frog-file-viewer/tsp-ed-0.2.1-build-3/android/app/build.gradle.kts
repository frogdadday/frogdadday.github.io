import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Frog File Viewer has a permanent, standalone Android identity.
// Signing credentials belong only in the locally ignored android/key.properties file.
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.isFile) {
    FileInputStream(keyPropertiesFile).use { input -> keyProperties.load(input) }
}

val requiredSigningFields = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
val signingFieldsPresent = requiredSigningFields.all {
    keyProperties.getProperty(it)?.isNotBlank() == true &&
        keyProperties.getProperty(it) != "replace-me"
}
val configuredKeyStore = keyProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }
val signingReady = signingFieldsPresent && configuredKeyStore?.isFile == true
val releaseRequested = gradle.startParameter.taskNames.any { task ->
    task.contains("release", ignoreCase = true)
}

// Keep ordinary debug builds and IDE sync key-free, but fail closed on release builds.
if (releaseRequested) {
    check(signingReady) {
        "Frog File Viewer release signing is not configured. Create android/key.properties " +
            "from android/key.properties.example and provide the existing, backed-up keystore. " +
            "Unsigned release builds are not permitted."
    }
    check(keyProperties.getProperty("keyAlias") == "frog-file-viewer-upload") {
        "Use the dedicated frog-file-viewer-upload alias in Frog File Viewer's release keystore."
    }
}

android {
    namespace = "com.frogdadday.frog_file_viewer"
    compileSdk = maxOf(36, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.frogdadday.frog_file_viewer"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingReady) {
            create("frogFileViewerRelease") {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storeFile = configuredKeyStore
                storePassword = keyProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // No debug-key fallback; release tasks require the dedicated signing setup.
            signingConfig = signingConfigs.findByName("frogFileViewerRelease")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
