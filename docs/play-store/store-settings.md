# Play Store settings

- App name: **Gold Rush Prospecting**
- Package/application ID: `com.killjoy00.goldrush`
- Default language: English (United States)
- Type: **Game**
- Category: **Board**
- Website: `https://killjoy00.github.io/`
- Privacy policy: `https://killjoy00.github.io/GoldRush/privacy.html`
- Support contact: use the support contact configured for the Play developer account.

Recommended discovery tags should stay tightly related to the actual game, such as board game, strategy, turn-based, single-player, and local multiplayer/offline when those tags are offered by Play Console.

Current Google Play text limits:
- App title: 30 characters
- Short description: 80 characters
- Full description: 4,000 characters

## Verified release/distribution checkpoint

The September 14, 2026 Android Publisher API audit confirms:

- version code 3 / version 1.5 is completed on **Internal testing**;
- the **Production** track exists but currently has **zero releases**;
- the live English listing and developer contact fields match the checked-in release configuration;
- required phone graphics are live (`icon=1`, `featureGraphic=1`, `phoneScreenshots=4`);
- Remove Ads is ACTIVE at US `$2.99`, with the `buy` option available in 173 regions;
- tablet screenshots are currently omitted.

The public website repository contains the exact required AdMob `app-ads.txt` record at its root:

`google.com, pub-1217971050094766, DIRECT, f08c47fec0942fa0`

GitHub reports Pages enabled for the Gold Rush repository and `docs/privacy.html` contains the current policy. Android v3 also links directly to the same privacy-policy URL inside the app. Before production rollout, open the public URL once in a normal browser, confirm the current policy loads, and save that URL in Play Console App content → Privacy policy.

Play Console email-list tester membership and production country/device availability remain manual Console checks because those states are not fully exposed by the Android Publisher API in the current pre-production configuration.

Version code 3 is consumed by Play. Any subsequent Android binary must use **versionCode 4 or higher**.
