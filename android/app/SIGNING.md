# Android Upload Key — `upload-keystore.jks`

Same flow as the other Rivler app repos. The `android-aab` workflow signs the
Play Store bundle with a Java KeyStore committed to
**`android/app/upload-keystore.jks`**.

The keystore is binary and **must be committed to the repo**. It cannot be
reconstructed from the SHA fingerprints below — those are one-way hashes
derived from the key, which is why pasting a fingerprint somewhere never makes
a build sign.

## Fingerprints of the keystore generated for this repo

```
SHA-1   : A0:21:E8:45:45:01:13:F9:38:E3:AC:00:17:3C:22:E5:B3:B2:09:67
SHA-256 : 4C:BF:6D:E2:1D:CB:E2:87:3A:F6:B7:9C:E9:F5:06:F7:66:C4:9D:7D:FB:C5:25:01:91:BD:EA:65:9F:56:8D:FE
```

These are **not yet registered anywhere.** Two places need them — see
*Registering this key* below.

The fingerprints already written into `.github/workflows/android-aab.yml` are
different:

```
SHA-1   : FA:D0:02:93:84:20:93:CB:12:9D:2D:FD:75:4B:DC:BF:13:FF:07:F9
SHA-256 : 52:43:75:AF:A8:4F:4A:1A:08:05:7A:09:67:8F:54:88:5F:53:DB:F1:AE:D3:50:41:98:DA:63:BF:5B:4E:A1:CC
```

Those came from Play Console. If they are the **app signing key** — the one
Google holds under Play App Signing — then a mismatch against the keystore is
normal and expected, because that key is Google's and never signs anything
locally. If they are the **upload key certificate**, then a previous upload key
exists and either it goes in this repo, or the key here replaces it via the
reset below. The workflow warns on a mismatch rather than failing, precisely
because those two cases cannot be told apart from inside a build.

## Keystore credentials

```
keystore  : android/app/upload-keystore.jks
alias     : rivler
storepass : rivler123
keypass   : rivler123
```

Both workflows set these as `KEY_ALIAS` / `STORE_PASSWORD` / `KEY_PASSWORD`
and hand them to Gradle through `$GITHUB_ENV`.
`android/app/build.gradle.kts` reads those env vars first and falls back to the
same literals, so a local `flutter build appbundle --release` works once the
`.jks` is in place.

## Registering this key

**1. Google Play — so uploads are accepted.**
Play Console → your app → Test and release → **App integrity → App signing**.

- If Rivler has **never had an accepted upload**, nothing to do. The first
  bundle you upload defines the upload key, and this becomes it.
- If an upload key is already registered and it is not this one, uploads fail
  with *"Your Android App Bundle is signed with the wrong key."* Use
  **Upload key certificate → Request upload key reset**, submit the SHA-256
  above, and Google swaps it. Takes a couple of days. You do not lose the app,
  the listing, or your users — Google still holds the app signing key.

**2. Firebase — so Google Sign-In works.**
Firebase Console → Project settings → the Android app for `com.rivler.app` →
**Add fingerprint**. Add the SHA-1 above.

Google Sign-In matches the package name **and the certificate the installed
APK was signed with** against an OAuth client. Add both:

- **this upload key's SHA-1** — for APKs you install directly from CI
- **Play's app signing key SHA-1** — for anything installed from Play, because
  Play re-signs on the way out

Miss the relevant one and sign-in fails with `ApiException: 10`
(DEVELOPER_ERROR), silently, no matter how correct the rest of the config is.

## If this keystore is ever lost

Play App Signing means Google holds the app signing key, so a lost **upload**
key is recoverable. Generate a new one:

```sh
keytool -genkeypair -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias rivler
```

then run the upload key reset above with its new SHA-256, and add its SHA-1 to
Firebase. Commit the new `.jks` and update the three credential lines in both
workflows if the alias or passwords changed.

## Why the keystore is in a public repo

Deliberate, and the same trade-off the other Rivler repos take: no CI secrets,
no dashboard configuration, and any checkout can produce a signed build.

The cost is real — anyone who can read this repo can sign an APK as Rivler and
could upload to the Play listing if they also had the Play account. Play App
Signing limits the blast radius, because the key Google actually ships with is
not this one. Keep the collaborator list tight, and if the repo is ever
compromised, reset the upload key using the procedure above.

## Related

- `android/.gitignore` — the `!app/upload-keystore.jks` line is the only reason
  this file can be committed. Flutter's default `**/*.jks` rule blocks it, and
  a rule in the root `.gitignore` cannot override one in a nested file.
- `.github/workflows/android-aab.yml` — checks for the keystore in its first
  step and stops there if it is missing, rather than spending twenty minutes
  producing a debug-signed bundle Play would reject.
