# Android release pipeline

Gold Rush Android builds both a sideloadable debug APK and release Android App Bundles in GitHub Actions. The app is now in Play-launch configuration rather than core-port development.

## CI and signing

The regular `Android` workflow runs the Kotlin unit suite, release lint, and release packaging, and produces:

- `gold-rush-android-debug` — a debug APK for direct testing/sideloading.
- `gold-rush-android-release-aab` — the release AAB produced by `:app:bundleRelease` for packaging validation.

That normal CI AAB is intentionally unsigned so signing material stays out of source control.

The separate manual `Android Play release` workflow is the Play-uploadable path. It materializes the upload keystore only on the runner, runs tests/lint/bundle generation, signs and verifies the AAB, archives the signed bundle plus its SHA-256 hash, and removes the temporary keystore.

## Current release identity

- Application ID: `com.killjoy00.goldrush`
- App label: `Gold Rush`
- `minSdk`: 26
- `targetSdk`: 36
- `compileSdk`: 36
- current `versionCode`: 2
- current `versionName`: `1.5`

`versionCode = 1` is deliberately reserved for the initial Play seed upload. The pre-monetization Android 1.5 build at commit `1c90e999f08b920385b76bb2b4514974f8d25f82` is the intended v1 seed. Current `main` is v2 and includes Android AdMob, UMP consent handling, and the Play Billing Remove Ads UI.

Every subsequent Play upload must use a strictly higher `versionCode`.

## Monetization status

Android monetization is implemented in code:

- Google Mobile Ads SDK with the production Android AdMob app ID and banner ad-unit ID.
- Google UMP consent gating and Privacy Choices support.
- Google Play Billing non-consumable Remove Ads entitlement.
- Product ID: `com.killjoy00.goldrush.removeads`.
- Debug builds use Google's test banner ID; release builds use the production banner ID.
- Ads fail closed while purchase ownership is unresolved so an existing purchaser does not see an ad flash.

See `docs/ANDROID_MONETIZATION.md` for the current identifiers and behavior.

## First Play release sequence

1. Create/configure Gold Rush in Play Console with package name `com.killjoy00.goldrush`.
2. Enroll in Play App Signing and create a dedicated Gold Rush Android upload key.
3. Configure the manual Play-release workflow for the upload key.
4. Build/sign the v1 seed build and upload it to Internal Testing.
5. After Play accepts the first build, create and activate the one-time product `com.killjoy00.goldrush.removeads`.
6. Upload current `main` as versionCode 2 so the Play-delivered build includes AdMob, UMP, and Remove Ads.
7. Test purchase, restore, reinstall, pending purchase, refund/revocation, consent, ads, and entitlement behavior from the Play-delivered Internal Testing build.
8. Complete the Play listing, content rating, target audience, ads declaration, Data Safety form, privacy policy, screenshots, feature graphic, and production rollout.

## AdMob

Gold Rush already has its Android AdMob app entry and Android-specific banner configuration wired in code. The existing publisher account and root `app-ads.txt` publisher record can remain shared across iOS and Android. Final release QA should confirm that Play listing/domain configuration and AdMob app association are correct.
