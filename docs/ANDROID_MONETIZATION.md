# Android monetization

## Remove-ads entitlement

The Android client contains the Google Play Billing implementation for the same permanent remove-ads entitlement used by iOS:

`com.killjoy00.goldrush.removeads`

The implementation uses Google Play Billing Library 9.1.0 and treats the product as a non-consumable one-time product.

Behavior:

- Connect once to Google Play Billing and enable automatic service reconnection.
- Support pending one-time purchases without granting the entitlement early.
- Query currently owned one-time products whenever billing connects so reinstalls and account restores recover ownership.
- Grant remove-ads only for a `PURCHASED` result containing the Gold Rush product ID.
- Acknowledge a completed purchase that Play reports as unacknowledged.
- Re-query ownership for Restore Purchase rather than trusting a local preference bit.
- Surface the localized Play price when product details are available.
- Treat cancellation as a normal dismissal rather than an error.
- Fail closed for advertising until the entitlement query succeeds, so an existing purchaser never sees an ad flash while ownership is unknown.

The Remove Ads entry point appears automatically when Google Play returns product details and a localized price. This lets the first Play build be uploaded before the product can be created in Play Console; once the product is configured and activated, the same distributed build can discover it dynamically.

## AdMob configuration

Android has its own AdMob app entry and banner unit. These identifiers are public application configuration, not credentials:

- Android AdMob app ID: `ca-app-pub-1217971050094766~3907429685`
- Android banner ad-unit ID: `ca-app-pub-1217971050094766/4428717591`
- Publisher: `pub-1217971050094766`

The root `app-ads.txt` publisher record remains:

`google.com, pub-1217971050094766, DIRECT, f08c47fec0942fa0`

Shipping implementation:

1. Google Mobile Ads SDK 25.4.0.
2. Google UMP SDK 4.0.0.
3. Real Android AdMob app ID supplied to the manifest.
4. Release builds use the real Android banner ad-unit ID.
5. Debug builds use Google's official test banner ID instead of generating production traffic.
6. UMP consent information is refreshed at app launch and ads are requested only when `canRequestAds()` is true.
7. A visible Privacy Choices entry point appears when UMP reports that one is required.
8. The monetization footer is suppressed while a game is active.
9. Purchased users never receive the banner.

## Play Console setup still required

The first signed AAB must be uploaded to a Play testing track before the current Play Console will allow the Remove Ads one-time product to be fully configured for this new app. After Play accepts that build, create and activate the one-time product with ID `com.killjoy00.goldrush.removeads`. The distributed build will then obtain the product and localized price from Play without a code change.

Billing purchase/restore behavior must be validated using a Play-delivered internal-test build rather than a sideloaded APK.
