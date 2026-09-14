# Android Google Play launch package

This directory is the source of truth for the Android Google Play listing and release declarations.

Files:
- `title.txt` - Play app title
- `short-description.txt` - Play short description
- `full-description.txt` - Android-specific full description
- `release-notes.txt` - Android release notes
- `app-content.md` - Play App content declaration guidance
- `data-safety.md` - Data Safety disclosure map for the AdMob/Billing release
- `asset-plan.md` - screenshots, icon, and feature-graphic plan
- `signing.md` and `signing-commands.md` - upload-key reference material

Current live Play state:
- Version 1.5 / version code 2 is on the Internal testing track with status `completed`.
- Remove Ads product `com.killjoy00.goldrush.removeads` is active with purchase option `buy` at US $2.99 plus Google-generated regional pricing.
- Android AdMob and UMP are integrated in the release build.
- The English Play Store title, short description, and full description are synced from this directory through `.github/workflows/play-sync-store-listing.yml`.

Release automation:
- `.github/workflows/android-play-release.yml` verifies the exact Gold Rush upload certificate, builds/signs/verifies the AAB, archives release artifacts, and uploads future releases to Internal testing.
- `.github/workflows/play-configure-remove-ads.yml` verifies/configures the Play one-time product through the Play Developer API.
- `.github/workflows/play-sync-store-listing.yml` validates and publishes the English listing text through the Play Developer API.

Before production rollout, complete real-device Internal-test QA and the remaining Play production declarations/assets described in `docs/ANDROID_RELEASE_READINESS.md`.
