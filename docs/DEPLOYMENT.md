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

Remote play over Game Center comes in the next build. When it lands, both
players must be signed into Game Center — Settings → Game Center on the iPhone.

---

## Rebuilding after changes

Just run the workflow again. The build number is taken from the GitHub run
number automatically, so it always increments and TestFlight never rejects it as
a duplicate.

The app is also declared as using no non-exempt encryption, so TestFlight will
not ask you the export-compliance question on every upload.

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
