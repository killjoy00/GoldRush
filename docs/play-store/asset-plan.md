# Google Play asset plan

## Live Play graphics state

Verified through the Google Play Developer API:

- Store icon: **uploaded and verified** (`icon=1`). It is generated from the existing production 1024×1024 Gold Rush app icon and resized to Play's 512×512 requirement.
- Feature graphic: **uploaded and verified** (`featureGraphic=1`). It is generated reproducibly at 1024×500 as a 24-bit RGB PNG from the shipping dark/gold palette and the game's split-pile visual language.
- Phone screenshots: **uploaded and verified** (`phoneScreenshots=4`). All four are 1080×1920 captures of the real Jetpack Compose app, driven deterministically on an Android emulator and visually reviewed before the Play upload.
- 7-inch tablet screenshots: none uploaded.
- 10-inch tablet screenshots: none uploaded.

The reusable read-only graphics check is `.github/workflows/play-assets-audit.yml`. The existing production icon can be re-synced with `.github/workflows/play-sync-store-icon.yml`; the feature graphic can be regenerated and re-synced with `.github/workflows/play-feature-graphic.yml` and `Tools/make_play_feature_graphic.py`; the phone screenshot set can be regenerated, validated, and re-synced manually with `.github/workflows/android-play-screenshots.yml`.

## Phone screenshots

The live set is generated from real app states at 1080×1920:

1. `01-play-your-way.png` - menu with scoring mode, splitting mode, Prospector selection, and play actions.
2. `02-draft-scoring-plan.png` - live scoring-card draft decision.
3. `03-split-the-claim.png` - live split with a face-down mining card.
4. `04-choose-a-pile.png` - live pile choice with both claims visible.

The capture workflow builds and installs the debug app/test APKs on a Pixel 2/API 35 emulator, drives the shipping Compose UI with `StoreScreenshotTest`, pulls the PNGs before teardown, validates Play-compatible dimensions/aspect ratio, and only then uploads them through a validated Google Play edit.

## Feature graphic

Live asset: 1024×500 RGB PNG.

The graphic intentionally extends the existing Gold Rush visual identity instead of duplicating the app icon: dark Gold Rush background, gold/parchment typography, and two claim piles around the core line `SPLIT THE CLAIM. THEY CHOOSE.`
