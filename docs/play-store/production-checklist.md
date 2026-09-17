# Android production checklist

This is the short manual-only checklist after the September 2026 Play Developer API audit and App content declaration pass. Everything that can be verified or submitted reliably through the Android Publisher API is intentionally omitted from the remaining manual work.

## Play Console — declarations/status

- [x] **Closed testing:** `Gold Rush 1.5 closed test` / versionCode 3 is reviewed, approved, and completed on `production-access`.
- [ ] **Closed-test gate:** keep at least 12 testers actually opted in continuously for 14 days, then obtain Production access.
- [x] **Privacy policy:** `https://killjoy00.github.io/GoldRush/privacy.html` verified and saved.
- [x] **Ads:** **Yes, contains ads**.
- [x] **App access / Sign-in details:** all functionality available without special access.
- [x] **Target audience and content:** submitted.
- [x] **Content rating:** IARC questionnaire submitted.
- [x] **Advertising ID:** submitted for the AdMob integration.
- [x] **Financial features:** Gold Rush does not provide financial features.
- [x] **Health apps declaration:** No.
- [x] **Government apps declaration:** No.
- [x] **Data Safety:** submitted through the Android Publisher API; Google returned HTTP 204. Source answers are in `docs/play-store/data-safety.md`.
- [ ] **AdMob Privacy & messaging:** confirm the applicable European regulations message is **Published**, not Draft.
- [ ] **Production countries:** after Production access unlocks, set availability to **Canada + United States only** with no Rest of World. The release audit and Production promotion workflow fail closed if readable Production geography differs.
- [ ] **Device availability:** review the Production device catalog for unexpected exclusions after Production access is granted.
- [ ] **Production readiness:** resolve every Play Console error/warning before rollout.

## Physical Android / Play-delivered QA

- [ ] Install/update to **versionCode 3** from the `production-access` closed test on a physical Android device.
- [ ] Confirm the in-app **Privacy Policy** action opens the current public policy.
- [ ] Confirm the localized Remove Ads price appears.
- [ ] Confirm banner ads appear only on intended non-gameplay surfaces and never during an active game.
- [ ] Buy Remove Ads with a test account and confirm the banner disappears immediately.
- [ ] Force-close/reopen and confirm entitlement persists.
- [ ] Reinstall from Play and confirm ownership restores.
- [ ] Exercise **Restore Purchase** explicitly.
- [ ] Verify a pending purchase does not grant entitlement early.
- [ ] Refund/revoke the test purchase and confirm ownership refresh removes entitlement.
- [ ] Verify UMP consent flow and Privacy Choices where applicable.
- [ ] Exercise Dealt/Drafted × Together/Take Turns in pass-and-play and Prospector modes.
- [ ] Rotate/background/restore during split and hidden-information handoff states.
- [ ] Verify Play In-App Review integration after its eligibility threshold; Google may suppress the review card.

## Release guardrails

- Production currently has **zero releases**. Keep it that way until Production access, account-side checks, and physical-device QA pass.
- `.github/workflows/play-release-audit.yml` permanently verifies that the repo version is present in Play and completed on `production-access`. Once Production country availability is readable, it requires exactly `CA,US` with `restOfWorld=false`.
- `.github/workflows/play-promote-production.yml` is the only intended first-launch Production path. It does **not** build or upload a new AAB. It promotes the already-tested versionCode 3 only after verifying:
  - versionCode 3 already exists in Play;
  - versionCode 3 is completed on `production-access`;
  - Production still has zero releases;
  - Production geography is exactly Canada + United States with no Rest of World;
  - the edit validates successfully; and
  - no unrelated Play change is already in review (`ERROR_IF_IN_REVIEW`).
- The workflow requires the explicit confirmation string `PROMOTE_GOLD_RUSH_V3` and is pinned to versionCode 3 so it cannot silently become a future-release mechanism.
- **Version code 3 is already consumed by Play. Any new Android binary must use versionCode 4 or higher.**
