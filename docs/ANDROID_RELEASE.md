# Android release pipeline

Gold Rush Android builds a sideloadable debug APK plus an optimized release Android App Bundle in GitHub Actions. A separate manual workflow signs the release AAB when Play upload-key secrets are configured.

## What normal CI produces

The `Android` workflow runs Kotlin unit tests and `lintRelease`, then builds:

- `gold-rush-android-debug` — a debug APK for direct testing/sideloading.
- `gold-rush-android-release-aab` — the release AAB produced by `:app:bundleRelease`.
- `gold-rush-android-lint` — the release lint reports.

Normal PR/main CI deliberately remains independent of signing credentials. The release variant is nevertheless the real optimized variant: AGP 9.4 `optimization { enable = true }` runs R8 code shrinking/obfuscation/optimization and resource shrinking during `bundleRelease`.

## Current release identity

- Application ID: `com.killjoy00.goldrush`
- App label: `Gold Rush`
- `minSdk`: 26
- `targetSdk`: 36
- `compileSdk`: 36
- `versionCode`: 1
- `versionName`: `1.5`

`versionCode` starts at 1 because this is the first Google Play upload. `versionName` matches the current iOS/TestFlight marketing version so the two stores present the same product version.

The app targets Android 16 / API 36, which satisfies the Google Play target requirement in effect for new apps in September 2026.

## Play signing

`.github/workflows/android-play-release.yml` is the credentialed release path. After Play App Signing is enabled and a dedicated upload key exists, configure these GitHub Actions secrets:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`

The workflow decodes the upload keystore only on the runner, runs tests/lint/release bundling, signs the AAB, verifies the signature, writes a SHA-256 digest, uploads the signed AAB artifact, and removes the temporary keystore. No signing value belongs in the repository.

## Local-data backup policy

`android:allowBackup` is deliberately `false`. Gold Rush now keeps hidden active-game resume data, career history, and setup preferences locally. Cloud-restoring those files would make the app's "local device state" behavior surprising and can restore a stale hidden-information session onto another install. Android/OEM device-to-device behavior can still vary on newer platform versions, so this is a product policy plus the strongest standard manifest opt-out, not a claim that every OEM migration tool is impossible.

## AdMob is separate

The existing publisher account and `app-ads.txt` publisher line can stay shared across iOS and Android, but Android needs its own AdMob **Android app entry** and Android banner/ad-unit IDs. Do not reuse the iOS app ID or iOS ad-unit IDs in the Android manifest or Kotlin code.

## Remaining first-release checklist

1. Create the Gold Rush Android app in Play Console using `com.killjoy00.goldrush`.
2. Enable Play App Signing and create/register the Android upload key.
3. Add the four upload-key secrets above to GitHub Actions.
4. Run `Android Play release` and upload its verified AAB to Internal testing.
5. Create the Android app entry in AdMob and add the Android-specific app/ad-unit IDs.
6. Wire Google Mobile Ads Android to the existing Play Billing remove-ads entitlement.
7. Complete the Play listing/Data Safety/App Content fields from `docs/play-store/` and add Android screenshots/feature graphic.
8. QA lifecycle restore, Play Billing, AdMob/remove-ads, and In-App Review on Play-installed physical devices.
9. Increment `versionCode` for every subsequent Play upload.