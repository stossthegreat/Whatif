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
    namespace = "com.rivler.app"
    // Pinned, not inherited. Inheriting flutter.compileSdkVersion /
    // flutter.targetSdkVersion made Play compliance depend on whatever Flutter
    // version the CI box happened to have, which is not a thing to leave to
    // chance when the deadlines are hard.
    //
    // compileSdk 36 is not optional: livekit_client and flutter_webrtc are
    // compiled against API 36, and AGP hard-fails resolution when an app
    // compiles against a lower level than a library it depends on. It is
    // separate from targetSdk — compiling against 36 changes nothing at
    // runtime; only targetSdk opts into Android 16 behaviour changes.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.rivler.app"
        minSdk = flutter.minSdkVersion
        // Play requires targeting API 36 for new apps and updates from
        // 31 Aug 2026. Targeting 36 opts into Android 16's behaviour changes;
        // the three that touch this app are handled in AndroidManifest.xml
        // (predictive back, large-screen resizability) and lib/main.dart
        // (edge-to-edge, already on). See docs/PLAY_COMPLIANCE.md.
        targetSdk = 36
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

    // 16 KB PAGE SIZE (Google Play: required for anything targeting API 35+;
    // blocks app updates from 1 Feb 2027).
    //
    // Two halves, and only one of them lives here. This half is the packaging:
    // shared libraries must be stored UNCOMPRESSED in the APK/AAB so AGP can
    // zip-align them on a 16384-byte boundary. AGP 8.5.1+ does that alignment
    // automatically for uncompressed libs, and false is already the AGP 8
    // default — it is written out explicitly because the failure mode is
    // silent: flip it to true and the app still builds, still installs, and
    // simply stops loading on 16 KB devices.
    //
    // The other half is ELF segment alignment INSIDE each .so, which is baked
    // in by whoever compiled it. We ship no native code of our own, so that
    // half is entirely a function of our plugin versions — see the
    // livekit_client note in pubspec.yaml. Verify a real build with
    // tool/check_16kb.sh; nothing in this file can prove it.
    packaging {
        jniLibs {
            useLegacyPackaging = false
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
