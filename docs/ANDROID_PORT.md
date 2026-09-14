# Android port

Gold Rush is ported in-place. iOS remains Swift/SwiftUI under `App/` and `Sources/`; Android lives under `Android/` as a native Kotlin/Jetpack Compose app. The Swift engine and agents remain the behavioral source of truth, with deterministic parity tests preventing silent drift.

## Current parity

Android now includes the current shipping game and local feature set:

- full 72-card mining deck and all 48 scoring cards
- Dealt and Drafted setup, Together and Take Turns formats, Motherlode, exact scoring, Pack Mule optimization, and tiebreaks
- persistent hidden-information boundaries through `PlayerView`, round history, split log, Claim Journal, and My Claim/Tableau
- Steady, Cunning, and Ruthless Prospector AI ported from the Swift agent behavior
- career stats and setup persistence through Preferences DataStore
- active-game restoration across rotation and process recreation
- Play In-App Review, adaptive/themed launcher icons, release R8 minification, and resource shrinking

## Android monetization

Android monetization is implemented and no longer future work:

- Google Play Billing for the permanent Remove Ads product `com.killjoy00.goldrush.removeads`
- Google Mobile Ads Android with a dedicated Android AdMob app entry and banner unit
- Google UMP consent gating and Privacy Choices support
- purchased-user ad suppression with fail-closed entitlement resolution
- debug builds use Google's official test banner; release builds use the production banner

See `docs/ANDROID_MONETIZATION.md` for the current configuration and behavior.

## Remaining Android launch work

The remaining work is release/account configuration and physical-device QA, not game reconstruction:

1. Create/configure Gold Rush in Play Console for `com.killjoy00.goldrush`.
2. Finish Play App Signing/upload-key setup and produce the first signed Internal Testing build.
3. Upload the reserved versionCode 1 seed build, then create and activate the Remove Ads one-time product.
4. Upload current `main` as versionCode 2 and validate monetization through Play Internal Testing.
5. Complete Play listing metadata, Data Safety/content declarations, screenshots, feature graphic, and production-track setup.
6. Validate Billing, ads, UMP consent, review prompts, restoration, and hidden-information behavior using a Play-delivered build on physical Android hardware.
7. Decide online architecture later if cross-platform friend play is desired. Game Center cannot provide Android/iOS cross-play.

## Vercel

There is no Gold Rush Vercel project today. Pass-and-play, solo, career stats, Claim Journal, and My Claim/Tableau are on-device and should stay that way. Vercel becomes relevant only if Gold Rush adds a shared backend for cross-platform online matches or a web companion/admin surface.

## Build

CI is authoritative. The Android workflow runs unit tests, release lint, debug APK assembly, and release AAB generation. The separate manual Play-release workflow signs the Play-uploadable bundle once the account-bound signing configuration is available.
