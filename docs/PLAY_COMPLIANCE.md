# Google Play compliance — Rivler

Three Play requirements with hard dates, and exactly where each one is
enforced in this repo. Every date below is from Google's own docs; re-check
them at the linked pages before trusting this file, because Google moves them.

| Requirement | Deadline | Where it lives | Status |
|---|---|---|---|
| Play Billing Library 8+ | 31 Aug 2026 (ext. 1 Nov 2026) | `pubspec.yaml` → `purchases_flutter` | **Met** (8.3.0) |
| 16 KB memory page sizes | 1 Feb 2027 | `pubspec.yaml` → `livekit_client`, `android/app/build.gradle.kts` | **Met** — verify per build |
| Target API level 36 | 31 Aug 2026 (ext. 1 Nov 2026) | `android/app/build.gradle.kts` → `targetSdk` | **Not met — decision needed** |

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

Now pinned to `livekit_client 2.11.0` (`flutter_webrtc 1.6.0`). Because that
SDK is compiled against API 36, `compileSdk` had to go to 36 as well, which in
turn required AGP 8.10.1 (the first line supporting API 36). Gradle stayed on
8.12 — above AGP 8.10's 8.11.1 minimum.

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

## 3. Target API level 36 — open decision

From **31 Aug 2026**, new apps and updates must target API 36 to be submitted
at all. We are on `targetSdk = 35`.

This was deliberately left alone rather than changed alongside the other two,
because it is the only one of the three with runtime consequences. Targeting
36 opts into Android 16's behaviour changes, and the one that bites a
full-bleed video app is **mandatory edge-to-edge**: an app targeting 36 can no
longer opt out, so system bars draw over the layout and every screen's padding
has to be re-checked on a real device. `compileSdk = 36` — already done — has
no runtime effect on its own; only `targetSdk` does.

So it is a one-line change plus a full visual pass on a device:

```kotlin
targetSdk = 36
```

Do it before the next Play submission, and budget a session for checking
insets on Home, the video call screen, Explore, and the paywall.

Source: <https://developer.android.com/google/play/requirements/target-sdk>
