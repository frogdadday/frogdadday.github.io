import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}
val signingPropertyNames = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
val releaseSigningRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val signingStoreFile = signingProperties.getProperty("storeFile")
    ?.takeIf(String::isNotBlank)
    ?.let(::file)
val releaseSigningReady = signingPropertiesFile.exists() &&
    signingPropertyNames.all { !signingProperties.getProperty(it).isNullOrBlank() } &&
    signingStoreFile?.isFile == true
if (releaseSigningRequested) {
    check(releaseSigningReady) {
        "Release signing is not configured correctly. Add android/key.properties with " +
            "keyAlias, keyPassword, storeFile, and storePassword values that point to the " +
            "private Frog Cleaner upload key. Debug builds do not require this file."
    }
}

android {
    namespace = "com.frogdadday.frog_cleaner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.frogdadday.frog_cleaner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
                storeFile = signingStoreFile
                storePassword = signingProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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

dependencies {
    testImplementation("junit:junit:4.13.2")
}
