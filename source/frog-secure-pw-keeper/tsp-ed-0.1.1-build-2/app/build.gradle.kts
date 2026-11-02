plugins { id("com.android.application") }

val releaseStorePath = System.getenv("FROG_RELEASE_STORE_FILE")
val releaseStorePassword = System.getenv("FROG_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("FROG_RELEASE_KEY_ALIAS")
val releaseKeyPassword = System.getenv("FROG_RELEASE_KEY_PASSWORD")
val hasReleaseSigning = listOf(releaseStorePath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword).all { !it.isNullOrBlank() }

android {
    namespace = "app.grounded.password"
    compileSdk = 36
    defaultConfig {
        applicationId = "app.grounded.password"
        minSdk = 28
        targetSdk = 36
        versionCode = 2
        versionName = "0.1.1"
        testInstrumentationRunner = "app.grounded.password.SecurityChecks"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    signingConfigs {
        create("frogRelease") {
            if (hasReleaseSigning) {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            if (hasReleaseSigning) signingConfig = signingConfigs.getByName("frogRelease")
        }
    }
    lint { abortOnError = true }
}
dependencies { testImplementation("junit:junit:4.13.2") }
