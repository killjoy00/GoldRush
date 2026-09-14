# Android production checklist

This is the short manual-only checklist after the September 14, 2026 Play Developer API audit and App content declaration pass. Everything that can be verified or submitted reliably through the Android Publisher API is intentionally omitted from the remaining manual work.

## Play Console — declarations/status

- [ ] **Internal testing:** confirm the intended Google account is in the tester email list and the opt-in/install link works.
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
- [ ] **Country/device availability:** review production countries, device availability, and distribution settings.
- [ ] **Production readiness:** resolve every Play Console error/warning before rollout.

## Physical Android / Play-delivered QA

- [ ] Install/update to **versionCode 3** from Google Play Internal testing on a physical Android device.
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

- Production currently has **zero releases**. Keep it that way until the checklist above passes.
- **Version code 3 is already consumed by Play. Any new binary must use versionCode 4 or higher.**
