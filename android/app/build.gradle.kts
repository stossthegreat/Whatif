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
// SET UP ALREADY — nothing to do. The keystore is committed at
// android/app/upload-keystore.jks and its credentials are the three values
// below. android/.gitignore carries the `!app/upload-keystore.jks` line that
// lets the file exist here at all: Flutter's default ignore blocks **/*.jks,
// and a rule in the root .gitignore cannot override one in a nested file,
// which is why a keystore dropped in without that line silently never commits.
//
// REGISTERING THIS KEY is the part that lives outside the repo, and it is two
// different places doing two different jobs — see android/app/SIGNING.md for
// the fingerprints and the full procedure:
//
//   Play Console  the SHA-256, so uploads are accepted. If an upload key is
//                 already registered and it is not this one, Play answers with
//                 "signed with the wrong key" — App integrity > App signing >
//                 Request upload key reset swaps it, a couple of days, and
//                 nothing about the app or its users is affected because
//                 Google holds the app signing key.
//   Firebase      the SHA-1, so Google Sign-In works. It matches package name
//                 AND the installed APK's certificate; miss it and sign-in
//                 fails with ApiException 10, silently.
//
// The AAB workflow prints this keystore's fingerprints under the ones recorded
// for Rivler, so a mismatch shows up on screen before an upload, not after.
//
// Replacing the keystore means updating the three values below AND the three
// at the top of both workflow files.
// Env first (that is how the workflows pass them, via $GITHUB_ENV), falling
// back to the same literals so a local `flutter build appbundle --release`
// signs correctly too, with no setup. Same arrangement as the other Rivler
// app repos. Change these together with the three lines at the top of both
// workflow files if the keystore is ever replaced.
val keyAliasValue: String = System.getenv("KEY_ALIAS") ?: "rivler"
val keyPasswordValue: String = System.getenv("KEY_PASSWORD") ?: "rivler123"
val storePasswordValue: String = System.getenv("STORE_PASSWORD") ?: "rivler123"

// Resolved relative to android/app, which is where this script lives.
val repoKeystore = file("upload-keystore.jks")
val cmKeystorePath: String? = System.getenv("CM_KEYSTORE_PATH")

// Both halves required. A keystore with the placeholders still in place fails
// at signing time with a much worse error than falling back to debug does, and
// a filled-in password with no keystore file fails the same way. Either gap ->
// debug signing, which installs on a phone and is refused by Play, and the AAB
// workflow stops early rather than producing that bundle at all.
// The credentials always resolve now, so the keystore file being present is
// the only condition. Absent, it falls back to debug signing rather than
// failing configuration — and the AAB workflow stops at its first step so
// that fallback can never reach Play.
val hasRepoKeys = repoKeystore.exists()
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
