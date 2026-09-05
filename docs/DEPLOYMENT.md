# Getting Gold Rush onto your phone

This is the complete path from the code in this repo to an app on your iPhone,
and your opponent's, via TestFlight.

**Your total effort: about 15 minutes, once.** After that, every build is one
button click.

You do not need a Mac. You will never touch a certificate, a provisioning
profile, or Keychain — GitHub's build machines handle all of it using an API key
you generate in step 1.

---

## Step 1 — Create an App Store Connect API key (5 minutes)

1. Go to https://appstoreconnect.apple.com
2. Click **Users and Access** (top nav)
3. Click the **Integrations** tab
4. Select **App Store Connect API** in the sidebar, then the **Team Keys** tab
5. Click the **+** button
6. Name it anything (e.g. `GitHub Actions`)
7. Set **Access** to **Admin**

   > ⚠️ **It must be Admin, not App Manager.** Cloud signing for App Store
   > distribution is gated on the Admin role. With an App Manager key the build
   > archives and signs correctly and then fails at the very last step with
   > "Cloud signing permission error / No profiles were found". Apple's own
   > recovery text for that error reads: *"You haven't been given access to
   > cloud-managed distribution certificates. Please contact your team's Account
   > Holder or an Admin to give you access."* See
   > https://developer.apple.com/forums/thread/698117
8. Click **Generate**

Now, from that page, collect three things:

| What | Where it is | Looks like |
|---|---|---|
| **Key ID** | The row of the key you just made | `A1B2C3D4E5` |
| **Issuer ID** | Above the key list, labelled "Issuer ID" | `12ab34cd-5678-90ef-ghij-klmnopqrstuv` |
| **The key file** | Click **Download API Key** | `AuthKey_A1B2C3D4E5.p8` |

⚠️ **The `.p8` file can only be downloaded once.** If you lose it you must revoke
the key and make a new one. Save it somewhere safe.

## Step 2 — Find your Team ID (1 minute)

1. Go to https://developer.apple.com/account
2. Scroll to **Membership details**
3. Copy the **Team ID** — 10 characters, like `X1Y2Z3W4V5`

## Step 3 — Add four secrets to GitHub (5 minutes)

Go to https://github.com/killjoy00/GoldRush/settings/secrets/actions

Click **New repository secret** four times:

| Secret name | Value |
|---|---|
| `ASC_KEY_ID` | The Key ID from step 1 |
| `ASC_ISSUER_ID` | The Issuer ID from step 1 |
| `ASC_KEY_P8` | The **contents** of the `.p8` file (see below) |
| `APPLE_TEAM_ID` | The Team ID from step 2 |

For `ASC_KEY_P8`, open the `.p8` file in any text editor and paste everything,
including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`
lines. (Base64 also works if you prefer — the workflow accepts either.)

## Step 4 — Create the app record (2 minutes)

Apple does not allow this to be automated, so it is the one manual step.

1. Go to https://appstoreconnect.apple.com/apps
2. Click **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: `Gold Rush` *(must be unique across the App Store — if it is
     taken, use something like `Gold Rush Prospect` and tell me, so I can match
     the display name)*
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: `com.killjoy00.goldrush` — pick it from the dropdown.
     If it is not listed, choose **Register a new bundle ID** and use exactly
     that string.
   - **SKU**: `goldrush` (internal only, any unique string)
   - **User Access**: Full Access
4. Click **Create**

> Using a different bundle ID? Set a repository *variable* (not secret) named
> `GOLDRUSH_BUNDLE_ID` at
> https://github.com/killjoy00/GoldRush/settings/variables/actions
> and the pipeline will use it.

## Step 5 — Build it

1. Go to https://github.com/killjoy00/GoldRush/actions/workflows/testflight.yml
2. Click **Run workflow** → **Run workflow**
3. Wait ~10 minutes

The workflow archives the app, signs it, and uploads it. If a secret is missing
it stops immediately with a message naming which one, rather than failing deep
inside a build log.

Alternatively, pushing a tag starting with `v` (e.g. `v1.0`) triggers the same
thing.

## Step 6 — Install it, and add your opponent

1. Go to https://appstoreconnect.apple.com → your app → **TestFlight**
2. Apple takes 5–15 minutes to finish processing the build. It will show
   "Processing" first.
3. In the sidebar under **Internal Testing**, click **+** to make a group
4. Add yourself and your opponent by Apple ID email
5. Add the build to that group

**Internal testers skip Beta App Review entirely** — you can both install within
minutes. (External testing needs Apple review and takes a day or more, so use
internal testing for the two of you.)

Both of you install the **TestFlight** app from the App Store, then Gold Rush
appears in it.

---

## Playing against each other

The first build is **pass-and-play and single-player**: two people on one
device, or you against the AI.

Remote play over Game Center is in the app. Both
players must be signed into Game Center — Settings → Game Center on the iPhone.

---

## Rebuilding after changes

Just run the workflow again. The build number is taken from the GitHub run
number automatically, so it always increments and TestFlight never rejects it as
a duplicate.

The app is also declared as using no non-exempt encryption, so TestFlight will
not ask you the export-compliance question on every upload.

---

## The listing copy

The store description used to be the one shipped thing that lived nowhere: the
binary, the version and the pipeline are all in git, but the text a user reads
before installing was typed into a web form and reviewed by nobody. It is now
in `docs/app-store/`, one file per field:

| File | App Store Connect field | Limit |
|---|---|---|
| `description.txt` | Description | 4000 |
| `whats-new.txt` | What's New in This Version | 4000 |
| `promotional-text.txt` | Promotional Text | 170 |
| `keywords.txt` | Keywords | 100 |

**A field with no file is left alone.** Only `description.txt` and
`whats-new.txt` exist today, so a run cannot blank the keywords by omission --
adding a field means creating its file, not editing the tool.

Push them with **Actions → App Store metadata → Run workflow**, giving the
marketing version to target. `apply` defaults to false, so running it prints a
line-by-line diff of what would change and writes nothing. Tick `apply` once
the diff reads right.

Two things it refuses to do, both deliberately:

- **Write to a version that is not editable.** A released listing is frozen by
  Apple, and a half-applied edit to one is not something a retry fixes. Edit
  the next version instead.
- **Create the version.** If App Store Connect has no such version the run
  fails and says so. Creating it is the one step that stays manual, because
  choosing a version number is a decision (see the version-numbering comment in
  `testflight.yml` before picking one -- Apple reads `1.03` as `1.3`).

Promotional Text is the only field on that list you can change without shipping
a build, which makes it the cheapest place to say something new.

---

## If something fails

| Symptom | Cause and fix |
|---|---|
| "Missing repository secrets: ..." | Step 3 was skipped or a name is misspelled. Names are case-sensitive. |
| "ASC_KEY_P8 did not decode to a PEM private key" | The secret is truncated. Re-paste the whole file including the BEGIN/END lines. |
| `No profiles for 'com.…' were found` | The bundle ID in step 4 does not match. Check the repository variable `GOLDRUSH_BUNDLE_ID`. |
| `Authentication credentials are missing or invalid` | The Issuer ID belongs to a different team than the key. |
| `Cloud signing permission error` / `No profiles for '...' were found` | The API key is not **Admin**. App Manager and Developer keys cannot cloud sign for distribution. Roles cannot be edited, so revoke the key and generate a new one with Admin access. |
| Upload succeeds, build never appears | Normal — processing takes 5–15 minutes. Check the **Activity** tab. |

Every run keeps the built `.ipa` as a downloadable artifact for 14 days, so a
failed upload does not mean a lost build.

---

## Device compatibility

The app ships **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`). Every screen is
laid out vertically for a phone, and nobody on this project has an iPad to
check what any of it looks like in landscape or at iPad proportions, so
claiming iPad support nobody has ever viewed would be worse than not claiming
it. This is also what avoids error 90474 (an iPad-supporting app must declare
all four orientations to support multitasking; this app is portrait-only).

**This does not mean the app is iPhone-exclusive on the App Store.** An
iPhone-only app is still installable on iPad — iPadOS runs it in a small,
iPhone-shaped "compatibility mode" window rather than a real iPad layout, and
there is no supported way to opt an iPhone-only app out of that. App Review
tests this, on a real iPad, as a matter of course.

That window is considerably shorter than any iPhone the app was actually
designed against. A screen built as a fixed-height `VStack` with `Spacer()`s
assuming iPhone-sized slack has nowhere to put the overflow in that window and
clips it — which is exactly the "top and bottom of the screen is cut off"
rejection this project hit under Guideline 4, reviewed on an iPad Air.

**The fix, applied everywhere a full-screen view uses this pattern**
(`RootView.menu`, `RootView.waitingForOpponent`, `HandoffView`): wrap the
content in `GeometryReader { proxy in ScrollView { ... .frame(minHeight:
proxy.size.height) } }` instead of a bare `VStack`. On a normal iPhone screen
the `Spacer()`s still expand to fill `proxy.size.height`, so the look is
unchanged. On a canvas too short for the content, the frame's `minHeight` is
just a floor — the `VStack` takes its natural (taller) size instead, and the
`ScrollView` scrolls through the difference rather than clipping it. Screens
that already wrap their content in `ScrollView` for an unrelated reason
(`SplitView`, `ChooseView`, `RevealSelectionView`, `ScoringView`,
`RoundRecapView`) do not need this — they already degrade the same way.

### Seeing it, without a Mac or an iPad

The `ipad-compat-screenshot` CI job builds the app for the iOS Simulator,
boots the same device model App Review's rejection named, launches the app,
and uploads a screenshot as a build artifact. It looks up the device type and
runtime by substring match against whatever the runner actually has rather
than a hardcoded identifier, since Apple's simulator identifiers do not
always match the marketing name. **Look at that screenshot after any change
to a full-screen view, before assuming a layout fix actually worked** — this
is the same "verify, don't guess" reasoning behind archiving unsigned on
every push: the alternative is finding out from a rejection two days later.

---

## Advertising

The app shows a single AdMob banner, pinned under the **home screen** (the
menu shown before a game starts). That is the screen every session opens on,
and it is never a board, a split, or a choice, so a banner there never lands
mid-decision.

### Where the SDK lives, and why

In the **app target only**. The Google Mobile Ads SDK is an iOS-only binary
framework, and `GoldRushUI` has to keep building on Linux so the engine tests
can run. `AdSlot` in GoldRushUI is the seam: the app fills it at launch, and
anything that does not -- Linux, the tests, a preview -- finds it empty and
renders nothing. This is the first third-party dependency in the project and
it is deliberately confined to the one target that cannot avoid it.

### Configuration

| Thing | Value |
|---|---|
| SPM package | `github.com/googleads/swift-package-manager-google-mobile-ads`, up to next major from 12.0.0 |
| App ID | `Info.plist` -> `GADApplicationIdentifier` |
| Ad unit ID | `GoldRushApp.bannerAdUnitID` |

The SDK **traps on launch** if `GADApplicationIdentifier` is missing or
malformed, rather than failing quietly at the first ad request. If the app dies
immediately on a fresh build, check that key first.

### Non-personalised ads, and the tracking prompt

The app never asks for tracking permission, so iOS returns a zeroed advertising
identifier and Google would serve non-personalised ads regardless. The request
also sets `npa=1` explicitly, so the behaviour does not depend on inferring
that, and so the privacy policy's claim is true by construction rather than by
accident.

The consequence for the store listing: **App Privacy answers "not used for
tracking"**, and there is no ATT prompt. Turning on personalised ads later
means adding the ATT prompt, changing that answer to yes, and re-submitting.

### SKAdNetworkItems

All 50 identifiers from Google's current AdMob iOS mediation list are in
`Info.plist` (developers.google.com/admob/ios/privacy/strategies). A wrong
identifier here fails silently -- that network's installs simply stop
attributing, with nothing to notice -- so the list was fetched directly and
cross-checked against an independent extraction of the same page rather than
transcribed by hand, and spliced into the plist programmatically rather than
typed. If Google revises the list, regenerate it the same way:

```bash
curl -sSL https://developers.google.com/admob/ios/privacy/strategies \
  | grep -oE '[a-z0-9]{10}\.skadnetwork' | awk '!seen[$0]++'
```

Diff the result against a second fetch before touching `Info.plist`, and
prefer scripting the substitution over hand-editing fifty `<dict>` blocks.

### app-ads.txt, and the Marketing URL it depends on

AdMob will not verify an app -- and an unverified app cannot have ad units
created against it -- until it can crawl an `app-ads.txt` naming the account's
own publisher ID. Three things have to line up, and two of them are invisible
from inside this repo:

| Thing | Where it lives | Value |
|---|---|---|
| `app-ads.txt` | root of the developer domain | `killjoy00/killjoy00.github.io` repo, served at `killjoy00.github.io/app-ads.txt` |
| Marketing URL | App Store Connect, **per version** | `https://killjoy00.github.io` |
| App ID / ad unit ID | `Info.plist`, `GoldRushApp.swift` | must share the account's `pub-` prefix |

The crawler takes only the **host** from the Marketing URL, so the file has to
sit at the domain root -- `killjoy00.github.io/app-ads.txt`, never
`.../GoldRush/app-ads.txt`, even though the support and privacy pages do live
under that path. That is why the file is in a separate repo from this one.

Two traps worth knowing, both of which cost a day here:

- **Marketing URL is versioned metadata, and it is optional.** It was simply
  never filled in, so Apple's listing exposed no developer website at all and
  AdMob had nothing to crawl -- while reporting only that app-ads.txt "didn't
  match", which points at the wrong file entirely. A released version's copy is
  frozen, so setting it means editing the *next* version and shipping it. Check
  what is actually public rather than what App Store Connect shows as saved:

  ```bash
  curl -sS "https://itunes.apple.com/lookup?bundleId=com.killjoy00.goldrush" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0].get('sellerUrl','(absent)'))"
  ```

- **Every ID under one AdMob account shares one publisher ID.** The App ID and
  ad unit ID shipped from launch until 1.1.1 carried `pub-3388571830343061`,
  a different account from the `pub-1217971050094766` in `app-ads.txt`. A
  well-formed App ID from an unrecognised account does not trap on launch and
  does not error -- ad requests just never fill. If the banner is blank,
  compare the `pub-` digits in `Info.plist` against the account's own
  app-ads.txt line before looking anywhere else.

### What CI cannot check

CI compiles the SDK and archives the app, which catches a broken API or a
mis-wired project file. It **cannot** tell you whether a banner actually
appears -- that needs a real device, and for the reason above it cannot tell
you whether the IDs belong to the right AdMob account either. Look at the home
screen on the first build carrying ads before submitting anything to review.

