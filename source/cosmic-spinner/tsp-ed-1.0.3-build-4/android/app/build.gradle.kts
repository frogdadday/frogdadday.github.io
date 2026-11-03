import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile =
    System.getenv("COSMIC_SPINNER_SIGNING_PROPERTIES")
        ?.takeIf(String::isNotBlank)
        ?.let(::file)
        ?: System.getenv("LOCALAPPDATA")
            ?.let(::file)
            ?.resolve("CosmicSpinner/signing/key.properties")
        ?: rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

val signingStoreFile = signingProperties.getProperty("storeFile")?.let(::file)
val hasReleaseSigning =
    signingPropertiesFile.exists() &&
        !signingProperties.getProperty("keyAlias").isNullOrBlank() &&
        !signingProperties.getProperty("keyPassword").isNullOrBlank() &&
        !signingProperties.getProperty("storePassword").isNullOrBlank() &&
        signingStoreFile?.exists() == true

android {
    namespace = "com.frogdadday.cosmicspinner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.frogdadday.cosmicspinner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
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
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val packagesRelease = allTasks.any { task ->
        task.name.contains("release", ignoreCase = true) &&
            (task.name.startsWith("assemble", ignoreCase = true) ||
                task.name.startsWith("bundle", ignoreCase = true) ||
                task.name.startsWith("package", ignoreCase = true))
    }
    if (packagesRelease && !hasReleaseSigning) {
        throw GradleException(
            "Cosmic Spinner release signing configuration is missing or incomplete: " +
                signingPropertiesFile,
        )
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
