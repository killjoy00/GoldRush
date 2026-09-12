# Android Google Play launch package

This directory is the source of truth for the first Android store submission.

Files:
- `title.txt` - Play app title
- `short-description.txt` - Play short description
- `full-description.txt` - Android-specific full description
- `release-notes.txt` - first Android release notes
- `app-content.md` - starting answers for Play App content declarations
- `data-safety.md` - Data Safety disclosure map for the intended AdMob/Billing release
- `asset-plan.md` - screenshots, icon, and feature-graphic plan
- `signing.md` and `signing-commands.md` - upload-key setup

The repository also contains `.github/workflows/android-play-release.yml`, a manual workflow that builds, signs, verifies, and archives a Play-uploadable AAB after the upload-key Actions secrets are configured.

Before production submission, the Android AdMob app ID/banner unit must be created and integrated, and the public privacy policy must be checked against that final ad configuration.
