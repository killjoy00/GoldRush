# Android monetization

## Remove-ads entitlement

The Android client now contains the Google Play Billing implementation for the same permanent remove-ads entitlement used by iOS:

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

The Compose purchase sheet is implemented separately from the ad banner. It is intentionally not wired into the main menu until the Android AdMob app ID and banner ad-unit ID exist; that avoids exposing a purchase whose corresponding Android ad placement has not been configured yet.

## AdMob boundary

Do not reuse the iOS AdMob app ID or ad-unit ID on Android. The Android package needs its own AdMob Android app entry and Android banner unit.

The publisher relationship remains the existing account and root `app-ads.txt` line:

`google.com, pub-1217971050094766, DIRECT, f08c47fec0942fa0`

Once the Android AdMob IDs are created, the next implementation step is:

1. Add Google Mobile Ads SDK 25.4.0.
2. Put the real Android AdMob app ID in the Android manifest.
3. Add a banner slot on the menu using the Android banner ad-unit ID.
4. Observe `RemoveAdsStore.State.isPurchased` and omit the banner when true.
5. Expose the existing `RemoveAdsScreen` from the menu/banner footer.
6. Test only with Google's test ad unit during development; never ship the sample app ID in the production manifest.

## Play Console setup still required

Create the one-time non-consumable product with ID `com.killjoy00.goldrush.removeads` in the Gold Rush Android Play Console app. Product availability and localized price will remain unavailable until the app and product exist in Play Console and a billing-enabled build is distributed through a Play track.
