# Google Play Data Safety answers

Last checked: 2026-09-12.

These answers describe the intended first Android production release: local gameplay/persistence, Google Play Billing, and one Google AdMob banner on the menu. Re-check this file if another SDK, backend, analytics product, crash reporter, login system, or ad-personalization configuration is added.

## Top-level form

- App collects or shares required user data types: **Yes**, because the Google Mobile Ads SDK transmits data off-device.
- Data encrypted in transit: **Yes** for the AdMob data described by Google.
- Developer-operated deletion request mechanism: **No**. Gold Rush has no account or first-party server-side profile. Local game/settings/career data can be removed by clearing app data or uninstalling.

## Data types to declare for AdMob

### Approximate location
- Collected: **Yes**
- Shared: **Yes**
- Required when ads are enabled
- Purposes: **Advertising or marketing; Analytics; Fraud prevention, security and compliance**
- Basis: the SDK receives the device IP address and may use it to estimate general location.

### App activity > App interactions
- Collected: **Yes**
- Shared: **Yes**
- Required when ads are enabled
- Purposes: **Advertising or marketing; Analytics; Fraud prevention, security and compliance**
- Basis: the SDK records product interactions such as app launches, taps, and ad/video views.

### App info and performance > Diagnostics
- Collected: **Yes**
- Shared: **Yes**
- Required when ads are enabled
- Purposes: **Analytics; Fraud prevention, security and compliance**

### Device or other IDs
- Collected: **Yes**
- Shared: **Yes**
- Required when ads are enabled
- Purposes: **Advertising or marketing; Analytics; Fraud prevention, security and compliance**
- Basis: the SDK may receive advertising ID, app set ID, and related identifiers.

## Data not collected by Gold Rush itself

Gameplay state, scoring-card choices, Claim Journal, career statistics, setup preferences, Prospector decisions, and locally generated game IDs remain on-device. Do not declare these as collected unless a future feature transmits them off-device.

## Google Play Billing

Gold Rush uses Google Play Billing for the one-time product `com.killjoy00.goldrush.removeads`. The app does not receive payment-method details and does not send purchase history or purchase tokens to a Gold Rush server. If server-side receipt validation is added later, revisit the Financial info / Purchase history answers.

## Play Console Ads declaration

Answer **Yes, contains ads** once the Android AdMob banner is enabled.

Official references:
- https://support.google.com/googleplay/android-developer/answer/10787469
- https://developers.google.com/admob/android/privacy/play-data-disclosure
