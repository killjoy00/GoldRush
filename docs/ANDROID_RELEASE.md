# Android release pipeline

Gold Rush Android now builds both a sideloadable debug APK and a release Android App Bundle in GitHub Actions.

## What CI produces

The `Android` workflow runs the Kotlin unit suite and then builds:

- `gold-rush-android-debug` — a debug APK for direct testing/sideloading.
- `gold-rush-android-release-aab` — the release AAB produced by `:app:bundleRelease`.

The release AAB is intentionally **unsigned** today. Android Gradle does not sign a release variant unless a release signing configuration is supplied. Keeping the bundle unsigned in the repository-level pipeline lets us continuously verify that the real release variant packages successfully without putting a private upload key in source control.

## Current release identity

- Application ID: `com.killjoy00.goldrush`
- App label: `Gold Rush`
- `minSdk`: 26
- `targetSdk`: 36
- `compileSdk`: 36
- `versionCode`: 1
- `versionName`: `0.1.0`

The app currently targets Android 16 / API 36, which satisfies the Google Play target requirement in effect for new apps in September 2026.

## Signing still required before Play upload

Before the first Play Console upload, create a dedicated Android upload key and enable Play App Signing. The upload key must remain outside Git. Do not reuse an iOS certificate, an AdMob identifier, or a debug keystore.

The eventual CI signing layer should provide the keystore and passwords through GitHub Actions secrets, materialize the keystore only for the release job, configure the Gradle `release` signing config from environment variables, and remove the temporary keystore at job completion.

Recommended secret names when the upload key is created:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

No values for those secrets belong in this repository.

## AdMob is separate

The existing publisher account and `app-ads.txt` publisher line can stay shared across iOS and Android, but Android needs its own AdMob **Android app entry** and Android banner/ad-unit IDs. Do not reuse the iOS app ID or iOS ad-unit IDs in the Android manifest or Kotlin code.

## Remaining first-release checklist

1. Create the Gold Rush Android app in Play Console using `com.killjoy00.goldrush`.
2. Enable Play App Signing and create the Android upload key.
3. Add the four signing secrets above to GitHub Actions.
4. Wire the secure signing config and verify the generated AAB is signed by the upload certificate.
5. Create the Android app entry in AdMob and add the Android-specific app/ad-unit IDs.
6. Add Google Mobile Ads Android plus Google Play Billing for the remove-ads entitlement.
7. Prepare Play listing metadata, privacy/data-safety answers, screenshots, icon/feature graphic, content rating, and testing-track configuration.
8. Increment `versionCode` for every Play upload.

Until those account-bound steps are completed, CI's release AAB is a packaging validation artifact rather than a Play-uploadable production binary.
