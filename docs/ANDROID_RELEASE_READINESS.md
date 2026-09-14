# Android release readiness

Current checkpoint: the Android client implements the shipped Gold Rush rules, Prospector AI, career stats, Claim Journal, My Claim/Tableau, persisted setup choices, active-game restoration, Play Billing Remove Ads, Google Mobile Ads, UMP consent handling, Play In-App Review, adaptive/themed launcher icons, and CI release bundle builds. The first Android bundle has been accepted by Google Play, is rolled out on Internal testing, and the Remove Ads product is active.

## Ready in-repo

- Native Kotlin / Jetpack Compose app under `Android/`.
- `applicationId` / namespace: `com.killjoy00.goldrush`.
- `compileSdk` / `targetSdk`: 36.
- Deterministic rule/AI regression coverage used by CI, plus a shared iOS/Android snapshot that locks all 48 scoring-card names, rules text, effect types, thresholds, and values against silent catalog drift.
- Active local/Prospector games restore from a deterministic seed + action transcript after rotation or process recreation.
- Release R8 minification and resource shrinking are enabled and exercised by CI.
- Android public version name is aligned with iOS at `1.5`.
- Version code 2 is the first bundle accepted by Google Play; every later Play build must use a higher version code.
- Explicit backup policy: career/setup preferences may restore, while the active-game transcript is excluded from cloud backup and device transfer.
- Play In-App Review follows the iOS prompt policy: only after a win, after at least three completed games, and at most once per app version.
- Debug APK artifact and release AAB artifact.
- Play Billing permanent product contract: `com.killjoy00.goldrush.removeads`.
- Android AdMob app/banner configuration and UMP consent gating.
- Adaptive launcher icon with monochrome themed-icon layer.
- Career and setup persistence through Preferences DataStore.
- Android Lint runs against the release variant in CI and archives its report.
- `Android Play release` verifies the upload certificate, signs the release AAB, archives release artifacts, and uploads future releases to Google Play Internal testing using the stored service-account credential.

## Google Play configuration completed

- Play app/package configured as `com.killjoy00.goldrush`.
- Upload certificate established. Expected SHA-1: `8A:D5:7A:08:05:70:96:CD:6F:D4:70:39:EA:86:1C:E1:63:E3:AC:26`.
- Version code 2 / version 1.5 accepted by Google Play.
- Play Developer API confirms version code 2 is on the `internal` track with release status `completed`.
- Play Developer API service account connected via GitHub Actions.
- Remove Ads product `com.killjoy00.goldrush.removeads` created and active.
- Remove Ads purchase option `buy` active at US `$2.99` with Google-generated regional prices.
- English title, short description, and full description synced through the Play Developer API.
- Default language, contact website, and contact email configured through the Play Developer API.
- Play Store icon uploaded from the existing production artwork and verified live (`icon=1`).
- 1024×500 RGB Play feature graphic generated from the shipping Gold Rush visual language, visually reviewed, uploaded, and verified live (`featureGraphic=1`).

## External release work still required

### Google Play Console / release track

1. Add/verify tester access and install the app from the Play internal-test link.
2. Complete or verify content rating, target audience, ads declaration, Data Safety, privacy-policy, and production-track requirements.
3. Any later binary must increment `versionCode` to at least 3 before running `Android Play release`.

### AdMob

The Android AdMob app entry and banner identifiers are already wired in code. Before production, confirm the app association and that the Play listing's developer website points at a domain whose root `app-ads.txt` contains the publisher record.

### Store assets / QA

- Generate and upload Android phone screenshots from the release-equivalent build. The Play API currently reports `phoneScreenshots=0`.
- Exercise Dealt/Drafted x Together/Take Turns in both pass-and-play and Prospector modes on physical Android hardware.
- Rotate the device and background/restore during both a split and handoff to verify active-game restoration and hidden-information boundaries.
- Test Billing through a Play internal-testing account, including purchase, reinstall/restore, pending purchase, and refund/revocation behavior.
- Verify banner ads, UMP consent/privacy choices, and Remove Ads entitlement together on a Play-delivered release build.
- Verify the Play in-app review integration from a Play-delivered internal-test build; Google controls whether the review card is actually displayed.

## Not required for the first Android release

Cross-platform online friend play is separate from the local/Prospector release. Apple Game Center cannot provide Android/iOS transport; a shared backend is only needed when that mode is intentionally added.
