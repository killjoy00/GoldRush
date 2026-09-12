# Android release readiness

Current checkpoint: the Android client implements the shipped Gold Rush rules, Prospector AI, career stats, Claim Journal, My Claim/Tableau, persisted setup choices, active-game restoration, Play Billing remove-ads infrastructure, adaptive/themed launcher icons, and CI production bundle builds.

## Ready in-repo

- Native Kotlin / Jetpack Compose app under `Android/`.
- `applicationId` / namespace: `com.killjoy00.goldrush`.
- `compileSdk` / `targetSdk`: 36.
- Deterministic rule/AI regression coverage used by CI, plus a shared iOS/Android snapshot that locks all 48 scoring-card names, rules text, effect types, thresholds, and values against silent catalog drift.
- Active local/Prospector games restore from a deterministic seed + action transcript after rotation or process recreation.
- Release R8 minification and resource shrinking are enabled and exercised by CI.
- Android public version name is aligned with the current iOS release at `1.5`; `versionCode = 1` remains correct for the first Play upload.
- Explicit backup policy: career/setup preferences may restore, while the active-game transcript is excluded from cloud backup and device transfer.
- Play In-App Review follows the iOS prompt policy: only after a win, after at least three completed games, and at most once per app version.
- Debug APK artifact.
- Release AAB artifact.
- Play Billing non-consumable product contract: `com.killjoy00.goldrush.removeads`.
- Adaptive launcher icon with monochrome themed-icon layer.
- Career and setup persistence through Preferences DataStore.
- Android Lint runs against the release variant in CI and archives its report.

## External release configuration still required

### Google Play Console

1. Create/configure the Android app for `com.killjoy00.goldrush`.
2. Enroll in Play App Signing and create a dedicated Android upload key.
3. Store the upload keystore and passwords as repository/action secrets; do not commit them.
4. Create the one-time in-app product `com.killjoy00.goldrush.removeads`.
5. Complete store listing, content rating, target audience, ads declaration, data safety, and privacy-policy fields.
6. Upload a signed AAB to an internal testing track before production.

### AdMob

1. Create the Android Gold Rush app entry in the existing AdMob publisher account.
2. Create an Android banner ad unit.
3. Add the Android AdMob app ID to the manifest and the banner unit ID to Android configuration.
4. Wire banner visibility to `RemoveAdsStore.isPurchased` and expose the Remove Ads purchase screen only when ads are configured.
5. Confirm the Play listing's developer website points at a domain whose root `app-ads.txt` contains the existing publisher record.

### Store assets / QA

- Capture Android phone screenshots from the release-equivalent build.
- Provide Play feature graphic / icon assets as required by the listing.
- Exercise Dealt/Drafted x Together/Take Turns in both pass-and-play and Prospector modes on physical Android hardware.
- Rotate the device and background/restore during both a split and handoff to verify active-game restoration and hidden-information boundaries.
- Test Billing through a Play internal-testing account, including purchase, reinstall/restore, pending purchase, and refund/revocation behavior.
- Verify banner ads and remove-ads entitlement together on a release build.
- Verify the Play in-app review integration from a Play-delivered internal-test build; Google controls whether the review card is actually displayed.

## Not required for the first Android release

Cross-platform online friend play is separate from the local/Prospector release. Apple Game Center cannot provide Android/iOS transport; a shared backend is only needed when that mode is intentionally added.
