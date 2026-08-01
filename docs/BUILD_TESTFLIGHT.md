# Building WhatIf for TestFlight

The app is a complete, buildable Flutter project. These are the exact steps to
get it onto TestFlight. (Requires a Mac with Xcode and an Apple Developer Program
membership — the one thing that can't be done from a headless environment.)

## 0. Prerequisites
- macOS + **Xcode 15+**, and `flutter` on your PATH (`flutter doctor` all green).
- An **Apple Developer Program** account.
- In **App Store Connect**, create an app record with a bundle id you own
  (e.g. `com.yourteam.whatif`).

## 1. Install deps
```bash
flutter pub get
```

## 2. Set the bundle id + signing
Open the iOS project in Xcode:
```bash
open ios/Runner.xcworkspace
```
- Select **Runner → Signing & Capabilities**.
- Set **Team** to your developer team; set **Bundle Identifier** to the one you
  registered in App Store Connect.
- Leave **Automatically manage signing** on.

> Camera requires iOS 12+. If the Pods complain, set `platform :ios, '12.0'` at
> the top of `ios/Podfile`, then `cd ios && pod install && cd ..`.

The camera/microphone usage strings are already in `ios/Runner/Info.plist`.

## 3. Bump the build number
In `pubspec.yaml`, the version line is `version: 1.0.0+1`. Increment the number
after `+` for every TestFlight upload (e.g. `1.0.0+2`).

## 4. Build a release IPA
```bash
flutter build ipa --release
```
The signed archive/IPA lands in `build/ios/ipa/`.

## 5. Upload to TestFlight
Easiest path — **Transporter** (free, Mac App Store): open it, sign in with your
Apple ID, drag in `build/ios/ipa/whatif.ipa`, hit **Deliver**.

Or from the command line:
```bash
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```
(Use an App Store Connect API key, or Xcode → Organizer → Distribute App.)

## 6. TestFlight
In App Store Connect → your app → **TestFlight**, the build appears after
processing (a few minutes). Add internal testers and it's live on their phones.

---

### Notes
- **No backend needed to run.** Matching, the other people, and the games are
  simulated locally, so the app is fully interactive on a device today. The
  camera powers your real self-view; if a tester denies the permission, every
  screen falls back to an elegant placeholder.
- **Android**: `flutter build appbundle --release` produces a Play-ready
  `.aab` (camera/mic permissions already declared).
