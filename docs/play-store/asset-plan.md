# Google Play asset plan

## Live Play graphics state

Verified through the Google Play Developer API:

- Store icon: **uploaded and verified** (`icon=1`). It is generated from the existing production 1024×1024 Gold Rush app icon and resized to Play's 512×512 requirement.
- Feature graphic: **uploaded and verified** (`featureGraphic=1`). It is generated reproducibly at 1024×500 as a 24-bit RGB PNG from the shipping dark/gold palette and the game's split-pile visual language.
- Phone screenshots: **missing** (`phoneScreenshots=0`).
- 7-inch tablet screenshots: none uploaded.
- 10-inch tablet screenshots: none uploaded.

The reusable read-only graphics check is `.github/workflows/play-assets-audit.yml`. The existing production icon can be re-synced with `.github/workflows/play-sync-store-icon.yml`; the feature graphic can be regenerated and re-synced with `.github/workflows/play-feature-graphic.yml` and `Tools/make_play_feature_graphic.py`.

## Phone screenshot plan

Use at least four portrait phone screenshots that satisfy Play's current screenshot dimensions and aspect-ratio limits.

Recommended order:
1. Split the claim - live split with one face-down card.
2. Choose a pile - both piles visible with an unknown card.
3. Draft your scoring plan - a real scoring-card draft decision.
4. Play your way - menu with game format and Prospector options.
5. Optional: My Claim tableau.
6. Optional: Career Stats after a real completed test game.

## Feature graphic

Live asset: 1024×500 RGB PNG.

The graphic intentionally extends the existing Gold Rush visual identity instead of duplicating the app icon: dark Gold Rush background, gold/parchment typography, and two claim piles around the core line `SPLIT THE CLAIM. THEY CHOOSE.`
