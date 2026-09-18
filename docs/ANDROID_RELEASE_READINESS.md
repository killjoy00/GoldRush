# Android release readiness

Current checkpoint: the Android client implements the shipped Gold Rush rules, Prospector AI, career stats, Claim Journal, My Claim/Tableau, persisted setup choices, active-game restoration, Play Billing Remove Ads, Google Mobile Ads, UMP consent handling, Play In-App Review, adaptive/themed launcher icons, and CI release bundle builds. Android 1.5.1 / versionCode 4 is completed on Google Play Internal testing and `production-access` closed testing; the Remove Ads product, listing metadata, required Play store graphics, and in-app privacy-policy link are live. No production release has been created yet.

## Ready in-repo

- Native Kotlin / Jetpack Compose app under `Android/`.
- `applicationId` / namespace: `com.killjoy00.goldrush`.
- `compileSdk` / `targetSdk`: 36.
- Deterministic rule/AI regression coverage used by CI, plus a shared iOS/Android snapshot that locks all 48 scoring-card names, rules text, effect types, thresholds, and values against silent catalog drift.
- Active local/Prospector games restore from a deterministic seed + action transcript after rotation or process recreation.
- Release R8 minification and resource shrinking are enabled and exercised by CI.
- Android public version name is `1.5.1` for the startup-crash hotfix.
- Version code 4 is the current Internal/closed-testing build. Any later Play binary must use version code 5 or higher.
- Explicit backup policy: career/setup preferences may restore, while the active-game transcript is excluded from cloud backup and device transfer.
- Play In-App Review follows the iOS prompt policy: only after a win, after at least three completed games, and at most once per app version.
- Debug APK artifact and release AAB artifact.
- Play Billing permanent product contract: `com.killjoy00.goldrush.removeads`.
- Android AdMob app/banner configuration and UMP consent gating.
- Adaptive launcher icon with monochrome themed-icon layer.
- Career and setup persistence through Preferences DataStore.
- Android Lint runs against the release variant in CI and archives its report.
- Android menu/footer includes a direct Privacy Policy action linking to `https://killjoy00.github.io/GoldRush/privacy.html`.
- `Android Play release` verifies the upload certificate, signs the release AAB, archives release artifacts, and uploads releases to Google Play Internal testing using the stored service-account credential.
- `Android Play screenshots` can manually regenerate, validate, archive, and sync the four real Compose phone screenshots to Play.
- `Google Play release audit` performs a broad read-only audit of the live bundle, tracks, listing/contact metadata, required graphics, Remove Ads state/pricing/regions, tester-Google-Group visibility, and country-availability API responses.

## Google Play configuration completed

- Play app/package configured as `com.killjoy00.goldrush`.
- Upload certificate established. Expected SHA-1: `8A:D5:7A:08:05:70:96:CD:6F:D4:70:39:EA:86:1C:E1:63:E3:AC:26`.
- Android 1.5.1 / version code 4 uploaded through the guarded GitHub release workflow.
- Post-upload Play Developer API readback confirms version code 4 is completed on both `internal` and `production-access`.
- Production track exists but currently has **zero releases**; Gold Rush has not been rolled out to production.
- Play Developer API service account connected via GitHub Actions.
- Remove Ads product `com.killjoy00.goldrush.removeads` created and active.
- Remove Ads purchase option `buy` active at US `$2.99`; the latest API audit reports the purchase option available in **173 regions**.
- English title, short description, and full description match the checked-in Play listing files.
- Default language, contact website, and contact email match the checked-in release configuration.
- Play Store icon uploaded from the existing production artwork and verified live (`icon=1`).
- 1024×500 RGB Play feature graphic generated from the shipping Gold Rush visual language, visually reviewed, uploaded, and verified live (`featureGraphic=1`).
- Four 1080×1920 Android phone screenshots generated from the real Compose UI, visually reviewed, uploaded, and verified live (`phoneScreenshots=4`).
- Tablet screenshots are not currently supplied (`sevenInchScreenshots=0`, `tenInchScreenshots=0`) and are not required for the initial phone-focused release.
- The public website repository contains the exact required AdMob `app-ads.txt` publisher record at its root.
- GitHub reports Pages enabled for the Gold Rush repository, and the intended privacy-policy source file exists at `docs/privacy.html`.

## What still requires manual verification

The Android Publisher API does not expose every Play Console declaration. The remaining work should not be guessed or marked complete from repository state alone.

### Google Play Console

1. Confirm the intended Google account is present in the Internal testing email list and that the tester opt-in/install link works. The Android Publisher Testers API exposes Google Groups but does **not** expose Play Console email-list testers.
2. Under **Policy and programs → App content**, complete or verify: Privacy policy, Ads declaration, App access, Target audience and content, Content rating, and Data Safety.
3. Open `https://killjoy00.github.io/GoldRush/privacy.html` once in a normal browser and confirm it loads the current Gold Rush policy, then save that URL in the Play Privacy policy declaration.
4. Review production country/device availability and distribution settings in Play Console. The country-availability API did not return usable production targeting data before a production release exists.
5. Resolve every production-review error or warning shown by Play Console before starting production rollout.
6. Keep Production empty until the physical-device/internal-test QA below passes.
7. Any later binary must increment `versionCode` to at least 5 before running `Android Play release`.

### Physical-device / Play-delivered QA

- Install/update to versionCode 4 from the Google Play `production-access` closed-test opt-in/install flow on a physical Android device and confirm startup stability.
- Confirm the new Privacy Policy action opens the public Gold Rush policy.
- Confirm the menu shows the localized Remove Ads price returned by Play.
- Confirm banner ads appear only on intended non-gameplay surfaces before purchase and never during an active game.
- Complete a test Remove Ads purchase; verify immediate removal, force-close/reopen persistence, reinstall ownership restore, and explicit Restore Purchase behavior.
- Verify pending-purchase behavior does not grant entitlement early, then refund/revoke a test purchase and confirm ownership refresh removes the entitlement.
- Verify UMP consent flow where applicable and Privacy Choices when required.
- Exercise Dealt/Drafted × Together/Take Turns in both pass-and-play and Prospector modes.
- Rotate the device and background/restore during split and hidden-information handoff states.
- Verify Play In-App Review integration after the configured eligibility threshold; Google may suppress the actual review card.

## Not required for the first Android release

Cross-platform online friend play is separate from the local/Prospector release. Apple Game Center cannot provide Android/iOS transport; a shared backend is only needed when that mode is intentionally added.
