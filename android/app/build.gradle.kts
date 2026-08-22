plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing — the upload key lives IN THE REPO, the same way the other
// Rivler app repos do it. One committed file plus the three values below.
// Nothing to configure in any dashboard, no CI secrets, no environment set-up:
// `flutter build appbundle --release` produces a Play-ready bundle on any
// machine and in any CI.
//
// ── ONE-TIME SETUP, then never again ───────────────────────────────────────
//
//  1. Copy Rivler's upload keystore to  android/app/upload-keystore.jks
//     and commit it. It has to be the SAME key already registered with Play
//     Console — a different one is refused on upload with "Your Android App
//     Bundle is signed with the wrong key", and undoing that means asking
//     Google to reset the upload key, which takes days. If Rivler has never
//     been uploaded to Play, then any new keystore is fine.
//
//  2. Replace the three REPLACE_ME values below with that keystore's real
//     alias and passwords, and commit. To read them off the keystore:
//         keytool -list -v -keystore android/app/upload-keystore.jks
//
// Until both are done the build falls back to DEBUG signing. The APK still
// installs on a phone, and the AAB workflow stops early with an explanation
// rather than spending twenty minutes producing a bundle Play would reject
// with "You uploaded an APK or Android App Bundle that was signed in debug
// mode".
//
// The env vars are only so CI or Codemagic can override without editing this
// file; nothing has to set them.
val keyAliasValue: String = System.getenv("KEY_ALIAS") ?: "REPLACE_ME"
val keyPasswordValue: String = System.getenv("KEY_PASSWORD") ?: "REPLACE_ME"
val storePasswordValue: String = System.getenv("STORE_PASSWORD") ?: "REPLACE_ME"

// Resolved relative to android/app, which is where this script lives.
val repoKeystore = file("upload-keystore.jks")
val cmKeystorePath: String? = System.getenv("CM_KEYSTORE_PATH")

// Both halves required. A filled-in alias with no keystore file, or a keystore
// with the placeholders still in place, fails at signing time with a far worse
// error than quietly falling back to debug does.
val hasRepoKeys = repoKeystore.exists() && keyAliasValue != "REPLACE_ME"
val hasReleaseKeys = hasRepoKeys || cmKeystorePath != null

android {
    namespace = "com.rivler.app"
    // Pinned, not inherited. Inheriting flutter.compileSdkVersion /
    // flutter.targetSdkVersion made Play compliance depend on whatever Flutter
    // version the CI box happened to have, which is not a thing to leave to
    // chance when the deadlines are hard.
    //
    // compileSdk 36 is not optional: flutter_webrtc (via livekit_client) is
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
            if (hasRepoKeys) {
                storeFile = repoKeystore
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                storePassword = storePasswordValue
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
