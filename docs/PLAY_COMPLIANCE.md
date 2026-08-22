# Google Play compliance — Rivler

Three Play requirements with hard dates, and exactly where each one is
enforced in this repo. Every date below is from Google's own docs; re-check
them at the linked pages before trusting this file, because Google moves them.

| Requirement | Deadline | Where it lives | Status |
|---|---|---|---|
| Play Billing Library 8+ | 31 Aug 2026 (ext. 1 Nov 2026) | `pubspec.yaml` → `purchases_flutter` | **Met** (8.3.0) |
| 16 KB memory page sizes | 1 Feb 2027 | `pubspec.yaml` → `livekit_client`, `android/app/build.gradle.kts` | **Met** — verify per build |
| Target API level 36 | 31 Aug 2026 (ext. 1 Nov 2026) | `android/app/build.gradle.kts` → `targetSdk`, `AndroidManifest.xml` | **Met** |

---

## 1. Play Billing Library

We never depend on `com.android.billingclient` directly. RevenueCat's SDK owns
it, so our Billing Library version is whatever `purchases_flutter` bundles:

```
purchases_flutter 10.9.1
  └── purchases-hybrid-common 18.31.0
        └── purchases-android 10.17.0
              └── com.android.billingclient:billing 8.3.0
```

**Billing Library 9 is not reachable today.** PBL 9.0.0 shipped on
19 May 2026, but RevenueCat has not adopted it — `purchases-android` still
pins `billingClient = "8.3.0"` on `main`, and its Gradle flavour dimension is
still `bc8`, with no `bc9` variant. Forcing `billing:9.0.0` with a Gradle
`resolutionStrategy` would compile and then fail at runtime the moment
RevenueCat called an API that PBL 9 changed, so we don't.

That is fine, because PBL 8 is not the deprecated tier — it is the *required*
one. Google's support timeline:

| PBL version | New app / update deadline | Extension deadline |
|---|---|---|
| 6 | 31 Aug 2025 | 1 Nov 2025 |
| 7 | 31 Aug 2026 | 1 Nov 2026 |
| **8** | **31 Aug 2027** | 1 Nov 2027 |
| 9 | 31 Aug 2028 | 1 Nov 2028 |

The live rule is "by 31 Aug 2026, new apps and updates must use version 8 or
later". We are on 8.3.0, so we ship. Moving to 9 would buy a further year of
runway and nothing else — do it when RevenueCat ships it, by bumping
`purchases_flutter`, never by pinning the billing artifact by hand.

Source: <https://developer.android.com/google/play/billing/deprecation-faq>

## 2. 16 KB memory page sizes

Applies to every app targeting API 35+. From 1 Feb 2027, an update that fails
it cannot be released.

There are two independent halves, and it is worth being clear about which one
is actually ours:

**Half one — ELF alignment inside each `.so`.** Baked in at compile time by
whoever built the library. We ship no native code of our own, so this is
purely a function of our plugin versions. The one that mattered:

- `flutter_webrtc` began emitting 16 KB-aligned `libwebrtc.so` in **1.2.0**
- `livekit_client` picks that up from **2.5.1** onward
- we were pinned at `livekit_client 2.3.1+hotfix.1` → `flutter_webrtc 0.12.2`
  → **not aligned**, and no Gradle setting could have fixed it

Now pinned to `livekit_client 2.6.4` (`flutter_webrtc 1.3.0`). That pin has a
ceiling as well as a floor: `livekit_client >= 2.6.5` requires `meta ^1.17.0`,
while `flutter_test` from the Flutter 3.35.6 SDK pins `meta 1.16.0`, so pub
cannot solve above 2.6.4. **Raising the LiveKit pin means raising the Flutter
version in `.github/workflows/*.yml` in the same commit.** CI caught this, not
a local build — which is most of the argument for having CI.

Because `flutter_webrtc 1.3.0`'s Android library is compiled against API 36,
`compileSdk` had to go to 36 as well, which in turn required AGP 8.10.1 (the
first line supporting API 36). Gradle stayed on 8.12 — above AGP 8.10's 8.11.1
minimum.

**Half two — zip alignment in the APK.** Ours. Shared libraries must be stored
uncompressed so AGP can align them on a 16384-byte boundary; AGP 8.5.1+ does
this automatically. `android/app/build.gradle.kts` sets
`jniLibs.useLegacyPackaging = false` explicitly, because the failure mode is
silent — the wrong value still builds, still installs, and simply stops
loading on 16 KB devices.

**Verify every release build.** Neither half is provable from the Gradle
config, so check the artifact:

```bash
tool/check_16kb.py build/app/outputs/bundle/release/app-release.aab
```

It parses the ELF program headers of every 64-bit `.so` and, for an APK, the
zip entry offsets too. Exit code 0 = compliant. An `.aab` keeps its libraries
compressed, so for the zip half run it against a `bundletool --mode=universal`
APK instead.

Source: <https://developer.android.com/guide/practices/page-sizes>

## 3. Target API level 36

From **31 Aug 2026**, new apps and updates must target API 36 to be submitted
at all. `targetSdk = 36` is set.

Unlike `compileSdk`, this one changes runtime behaviour, so each Android 16
change was checked against what the app actually does rather than assumed.
Three touch us:

### Edge-to-edge opt-out removed — already fine

Android 15 enforced edge-to-edge for apps targeting API 35 but allowed an
opt-out via `windowOptOutEdgeToEdgeEnforcement`. Targeting 36 disables that
opt-out. **No change needed here, and the risk was smaller than it looks:** we
already targeted 35 and never set the opt-out attribute, so edge-to-edge has
been live in shipping builds all along. `lib/main.dart` asks for it explicitly
(`SystemUiMode.edgeToEdge`, transparent status and navigation bars).

Insets were audited screen by screen rather than trusted:

- `main_shell.dart` reads `MediaQuery.padding.bottom`, adds it to the 64dp nav
  bar height, pads the bar by it, and re-injects the total as bottom padding
  for every tab through a nested `MediaQuery` — so tab content scrolls clear
  of the bar and the bar clears the gesture pill.
- Every other top-level screen wraps its body in `SafeArea`.
- The six onboarding steps that have no `SafeArea` of their own —
  `gender`, `handle`, `interests`, `language`, `photo`, `safety` — all render
  inside `OnboardingShell`, which has one.

### Predictive back — enabled explicitly

For apps targeting 36 on Android 16, predictive back animations are on by
default, `onBackPressed` is no longer called, and `KEYCODE_BACK` is no longer
dispatched. Apps that intercept the back event break.

This app intercepts nothing: there is no `WillPopScope` and no `PopScope`
anywhere in `lib/`, only `Navigator.maybePop()` on in-app back buttons, which
is ordinary route navigation. So `android:enableOnBackInvokedCallback="true"`
is declared in the manifest — matching the API 36 default, but stated outright
so Android 13-15 behave the same way instead of the behaviour flipping with
the OS version.

**If a screen ever needs to intercept back** — a confirm-before-leaving on a
live call, for example — it must use `PopScope`. `WillPopScope` does not work
under predictive back and will silently stop firing.

### Large-screen resizability — opted out, expires at API 37

This is the one with real debt attached.

For apps targeting 36, Android ignores `screenOrientation`,
`resizableActivity`, `minAspectRatio`, `maxAspectRatio` and
`setRequestedOrientation()` on any display of sw600dp or larger.
`lib/main.dart` calls
`SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`, which
goes through `setRequestedOrientation()` — so on a tablet or an unfolded
foldable this app would rotate and resize freely into layouts only ever
designed for a portrait phone.

The manifest therefore declares Google's documented temporary opt-out at the
application level:

```xml
<property
    android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"
    android:value="true" />
```

That keeps compatibility-mode behaviour on large screens. **It stops working
when we target API 37.** The real fix is layouts that adapt to landscape and
to sw600dp+, and it has to land before that bump. Delete the property on the
day that work ships.

### Checked and not applicable

- **Elegant font APIs deprecated** — we never set `elegantTextHeight`; Flutter
  rasterises its own text.
- **Safer Intents** — opt-in, and we declare no cross-app intent filters
  beyond LAUNCHER.
- **Fixed-rate work scheduling** — no `scheduleAtFixedRate` in the app.
- **Health permissions, Bluetooth bond, GPU syscall filtering** — unused.

### Worth watching, not yet enforced

**Local Network Permission.** Google is moving LAN access behind a runtime
permission, currently opt-in, "enforced at a later Android release". Our P2P
path is exactly the kind of traffic it targets: WebRTC gathers host ICE
candidates on local network addresses for same-network calls. Nothing to do
today, but when that permission becomes mandatory, P2P calls between two
people on the same Wi-Fi will need it — and the fallback needs to stay
graceful when a user denies it.

Source: <https://developer.android.com/about/versions/16/behavior-changes-16>
and <https://developer.android.com/google/play/requirements/target-sdk>
