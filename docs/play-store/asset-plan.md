# Google Play asset plan

## Live Play graphics state

Verified through the Google Play Developer API:

- Store icon: **uploaded and verified** (`icon=1`). It is generated from the existing production 1024×1024 Gold Rush app icon and resized to Play's 512×512 requirement.
- Feature graphic: **missing** (`featureGraphic=0`).
- Phone screenshots: **missing** (`phoneScreenshots=0`).
- 7-inch tablet screenshots: none uploaded.
- 10-inch tablet screenshots: none uploaded.

The reusable read-only check is `.github/workflows/play-assets-audit.yml`. The existing production icon can be re-synced with `.github/workflows/play-sync-store-icon.yml`.

## Phone screenshot plan

Use at least four portrait phone screenshots at 1080×1920 or higher.

Recommended order:
1. Split the claim - live split with one face-down card.
2. Choose a pile - both piles visible with an unknown card.
3. Draft your scoring plan - a real scoring-card draft decision.
4. Play your way - menu with game format and Prospector options.
5. Optional: My Claim tableau.
6. Optional: Career Stats after a real completed test game.

## Feature graphic

Required size: 1024×500.

Use the existing Gold Rush visual identity rather than introducing new branding: dark Gold Rush background, production nugget identity, and two claim piles. Suggested short line: `SPLIT THE CLAIM. THEY CHOOSE.`
