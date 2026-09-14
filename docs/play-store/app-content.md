# Play Console App content answers

Use these as the starting answers for the current Android release, then confirm them against the exact bundle being promoted beyond Internal testing.

## Ads

**Contains ads: Yes.** The Android release build includes a Google AdMob banner on menu/non-gameplay surfaces. The banner is consent-gated where required and is removed for users who own the permanent Remove Ads product.

## App access

**No restricted access.** No login, membership, invitation, or special reviewer account is needed. All game modes are accessible from the first screen.

Reviewer note: `No account is required. The optional Remove Ads purchase is not required to review gameplay.`

## Target audience

Recommended first-release selection: **13-15, 16-17, 18 and over**. Position the game as **not designed primarily for children** unless the product strategy changes and the Families requirements are reviewed.

## Content rating

The Android release has no user chat, user-generated content, real-money wagering, or combat gameplay. It does have an optional digital purchase and advertising. Complete the IARC questionnaire from the uploaded build and accept the regional ratings it produces.

## Permissions declaration

The app itself does not request a high-risk Android permission. Google Mobile Ads / UMP and Play Billing may contribute standard SDK permissions through manifest merging; use the merged release manifest and Play Console's declarations as the final check before production promotion.

Official references:
- https://support.google.com/googleplay/android-developer/answer/9859455
- https://support.google.com/googleplay/android-developer/answer/9867159
- https://support.google.com/googleplay/android-developer/answer/9898843
