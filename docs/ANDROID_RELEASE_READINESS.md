# Android release readiness

Current checkpoint: the Android client implements the shipped Gold Rush rules, Prospector AI, career stats, Claim Journal, My Claim/Tableau, persisted setup choices, active-game restoration, Play Billing Remove Ads, Google Mobile Ads, UMP consent handling, Play In-App Review, adaptive/themed launcher icons, and CI release bundle builds.

## Ready in-repo

- Native Kotlin / Jetpack Compose app under `Android/`.
- `applicationId` / namespace: `com.killjoy00.goldrush`.
- `compileSdk` / `targetSdk`: 36.
- Deterministic rule/AI regression coverage used by CI, plus a shared iOS/Android snapshot that locks all 48 scoring-card names, rules text, effect types, thresholds, and values against silent catalog drift.
- Active local/Prospector games restore from a deterministic seed + action transcript after rotation or process recreation.
- Release R8 minification and resource shrinking are enabled and exercised by CI.
- Android public version name is aligned with iOS at `1.5`.
- Current `main` uses `versionCode = 2`; `versionCode = 1` is reserved for the initial pre-monetization Play seed upload.
- Explicit backup policy: career/setup preferences may restore, while the active-game transcript is excluded from cloud backup and device transfer.
- Play In-App Review follows the iOS prompt policy: only after a win, after at least three completed games, and at most once per app version.
- Debug APK artifact and release AAB artifact.
- Play Billing non-consumable product contract: `com.killjoy00.goldrush.removeads`.
- Android AdMob app/banner configuration and UMP consent gating.
- Adaptive launcher icon with monochrome themed-icon layer.
- Career and setup persistence through Preferences DataStore.
- Android Lint runs against the release variant in CI and archives its report.
- A manual Play-release workflow can build, sign, verify, hash, and archive a Play-uploadable AAB once account-bound signing is configured.

## External release configuration still required

### Google Play Console

1. Create/configure the Android app for `com.killjoy00.goldrush`.
2. Enroll in Play App Signing and configure the dedicated Android upload key for the release workflow.
3. Upload the signed versionCode 1 seed build to Internal Testing.
4. After Play accepts the first build, create and activate the one-time product `com.killjoy00.goldrush.removeads`.
5. Upload current `main` as versionCode 2 for monetization testing.
6. Complete store listing, content rating, target audience, ads declaration, Data Safety, privacy-policy, and production-track fields.

### AdMob

The Android AdMob app entry and banner identifiers are already wired in code. Before production, confirm the app association and that the Play listing's developer website points at a domain whose root `app-ads.txt` contains the publisher record.

### Store assets / QA

- Capture Android phone screenshots from the release-equivalent build.
- Provide Play feature graphic / icon assets as required by the listing.
- Exercise Dealt/Drafted x Together/Take Turns in both pass-and-play and Prospector modes on physical Android hardware.
- Rotate the device and background/restore during both a split and handoff to verify active-game restoration and hidden-information boundaries.
- Test Billing through a Play internal-testing account, including purchase, reinstall/restore, pending purchase, and refund/revocation behavior.
- Verify banner ads, UMP consent/privacy choices, and Remove Ads entitlement together on a Play-delivered release build.
- Verify the Play in-app review integration from a Play-delivered internal-test build; Google controls whether the review card is actually displayed.

## Not required for the first Android release

Cross-platform online friend play is separate from the local/Prospector release. Apple Game Center cannot provide Android/iOS transport; a shared backend is only needed when that mode is intentionally added.
