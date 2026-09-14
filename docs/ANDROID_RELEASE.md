# Android release pipeline

Gold Rush Android builds both a sideloadable debug APK and release Android App Bundles in GitHub Actions. The app is now in Play-launch configuration rather than core-port development.

## CI and signing

The regular `Android` workflow runs the Kotlin unit suite, release lint, and release packaging, and produces:

- `gold-rush-android-debug` — a debug APK for direct testing/sideloading.
- `gold-rush-android-release-aab` — the release AAB produced by `:app:bundleRelease` for packaging validation.

That normal CI AAB is intentionally unsigned so signing material stays out of source control.

The separate manual `Android Play release` workflow is the Play-upload path. It materializes the upload keystore only on the runner, verifies that the keystore certificate matches the exact upload certificate Google Play expects, runs tests/lint/bundle generation, signs and verifies the AAB, archives the signed bundle plus mapping/hash artifacts, and uploads the release to the Google Play Internal testing track through the Play Developer API.

The expected Gold Rush upload certificate SHA-1 is:

`8A:D5:7A:08:05:70:96:CD:6F:D4:70:39:EA:86:1C:E1:63:E3:AC:26`

The workflow fails before signing or uploading if the configured keystore does not match that certificate.

## Current release identity

- Application ID: `com.killjoy00.goldrush`
- App label: `Gold Rush`
- `minSdk`: 26
- `targetSdk`: 36
- `compileSdk`: 36
- current `versionCode`: 2
- current `versionName`: `1.5`

Version code 2 is the first Gold Rush Android bundle accepted by Google Play. The Play Developer API confirms that version code 2 is on the `internal` track with release status `completed` under the release name `Gold Rush Internal Test`.

Every subsequent Play upload must use a strictly higher `versionCode`; the next upload must therefore be 3 or greater.

## Monetization status

Android monetization is implemented in code and the Play one-time product is active:

- Google Mobile Ads SDK with the production Android AdMob app ID and banner ad-unit ID.
- Google UMP consent gating and Privacy Choices support.
- Google Play Billing permanent Remove Ads entitlement.
- Product ID: `com.killjoy00.goldrush.removeads`.
- Purchase option ID: `buy`.
- US price: `$2.99` with Google-generated regional pricing.
- Debug builds use Google's test banner ID; release builds use the production banner ID.
- Ads fail closed while purchase ownership is unresolved so an existing purchaser does not see an ad flash.

See `docs/ANDROID_MONETIZATION.md` for the current identifiers and behavior.

## Current Play release sequence

Completed:

1. Gold Rush exists in Play Console as `com.killjoy00.goldrush`.
2. Play App Signing / upload-key configuration is established.
3. Version code 2 / version 1.5 was accepted by Play.
4. Version code 2 is rolled out on the Internal testing track with status `completed`.
5. The one-time product `com.killjoy00.goldrush.removeads` was created and activated through the Play Developer API.
6. GitHub release automation verifies the exact upload certificate and can send future signed AABs directly to Internal testing.

Remaining release QA / launch work:

1. Add/verify tester access and install version code 2 through the Play internal-test link.
2. Test purchase, restore, reinstall, pending purchase, refund/revocation, consent, ads, and entitlement behavior from the Play-delivered build.
3. Complete/verify the Play listing, content rating, target audience, ads declaration, Data Safety form, privacy policy, screenshots, feature graphic, and production rollout requirements.
4. For any new binary, increment `versionCode` to at least 3 before running `Android Play release`.

## AdMob

Gold Rush already has its Android AdMob app entry and Android-specific banner configuration wired in code. The existing publisher account and root `app-ads.txt` publisher record can remain shared across iOS and Android. Final release QA should confirm that Play listing/domain configuration and AdMob app association are correct.
