import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Two sources, first match wins:
//  1. android/key.properties  (local release builds)
//  2. CM_KEYSTORE_* environment variables (Codemagic's Android code signing)
// Neither present -> falls back to debug signing so `flutter run --release`
// still works on a dev machine, but a Play upload will be refused — which is
// correct: shipping a store build accidentally signed with debug keys is the
// mistake this file used to allow.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val cmKeystorePath: String? = System.getenv("CM_KEYSTORE_PATH")
val hasReleaseKeys = keystorePropertiesFile.exists() || cmKeystorePath != null

android {
    namespace = "com.rivlr.app"
    // Pinned, not inherited: Play requires targeting Android 15 (API 35),
    // and the 16 KB page-size requirement applies to apps targeting 35+.
    // Inheriting flutter.targetSdkVersion made compliance depend on whatever
    // Flutter version the CI box happened to have.
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.rivlr.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            } else if (cmKeystorePath != null) {
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
                storeFile = file(cmKeystorePath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeys) signingConfigs.getByName("release")
                            else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
