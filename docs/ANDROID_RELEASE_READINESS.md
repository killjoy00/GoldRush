# Android release readiness

Current checkpoint: the Android client implements the shipped Gold Rush rules, Prospector AI, career stats, Claim Journal, My Claim/Tableau, persisted setup choices and active-game resume, Play Billing remove-ads infrastructure, adaptive/themed launcher icons, optimized release builds, and CI production bundle builds.

## Ready in-repo

- Native Kotlin / Jetpack Compose app under `Android/`.
- `applicationId` / namespace: `com.killjoy00.goldrush`.
- `compileSdk` / `targetSdk`: 36.
- Deterministic reducer, scoring, AI, lifecycle-replay, and full-game regression coverage used by CI.
- Cross-platform scoring-catalog digest pins every current card definition on Swift and Kotlin; a retune must update both sides deliberately.
- Active local/Prospector games resume from a persisted deterministic transcript after Activity recreation or process death.
- Release variant uses AGP 9.4's R8 code/resource optimization path.
- Debug APK artifact.
- Release AAB artifact.
- Manual signed-AAB workflow for Play after upload-key secrets are configured.
- Play Billing non-consumable product contract: `com.killjoy00.goldrush.removeads`.
- Play In-App Review integration follows the iOS policy: after a win, from game 3 onward, at most once per app version.
- Adaptive launcher icon with monochrome themed-icon layer.
- Career and setup persistence through Preferences DataStore.
- Android backups are deliberately disabled so hidden active-game state and career history remain local to the device/install rather than restoring through cloud backup.
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
- Explicitly rotate/recreate the Activity at handoff, split, choose, and scoring screens and verify the same hidden-information boundary is restored.
- Exercise a process-death restore from an active pass-and-play and Prospector game.
- Test Billing through a Play internal-testing account, including purchase, reinstall/restore, pending purchase, and refund/revocation behavior.
- Verify the Play In-App Review request path from a Play-installed internal-test build; Play may suppress the sheet according to quota.
- Verify banner ads and remove-ads entitlement together on a release build.

## Not required for the first Android release

Cross-platform online friend play is separate from the local/Prospector release. Apple Game Center cannot provide Android/iOS transport; a shared backend is only needed when that mode is intentionally added.