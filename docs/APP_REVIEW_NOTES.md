# App Review Information — Notes

Paste the **Reviewer answers** section below into App Store Connect →
your app → the version → **App Review Information → Notes**. Apple asked for
it once and told us to keep it there for future submissions, so it lives here
rather than being rewritten from memory each time.

Everything below is checked against the shipping source, not recalled:
`App/Info.plist` (no usage-description keys, so no permission prompts),
`App/GoldRush/GoldRush.entitlements` (Game Center is the only entitlement),
and a grep of `Sources/` and `App/` confirming the app makes no network calls
of its own and contains no StoreKit, CloudKit, or analytics code.

## Facts this rests on

| Thing | Value |
|---|---|
| Bundle ID | `com.killjoy00.goldrush` |
| Version | 1.0 |
| Minimum iOS | 18.0 |
| Orientation | Portrait only |
| Appearance | Dark only (`UIUserInterfaceStyle = Dark`) |
| Entitlements | Game Center, and nothing else |
| Permission prompts | **None.** No location, contacts, camera, photos, notifications, or ATT |
| Accounts | None. No registration, no login, no profile, nothing to delete |
| Purchases | None. No IAP, no subscriptions, no paid tier, no ads-removal upsell |
| User-generated content | None. No chat, no names, no uploads, no sharing |
| Third-party SDKs | Google Mobile Ads only |
| Support page | https://killjoy00.github.io/GoldRush/ |
| Privacy policy | https://killjoy00.github.io/GoldRush/privacy.html |

---

# Reviewer answers

## 2. Devices and operating systems tested

<!-- FILL THIS IN before submitting. Name the real device and the real iOS
     version you played the TestFlight build on. Do not guess a model. -->

> **_[REPLACE ME — e.g. "iPhone 15 Pro running iOS 26.5" — list every device
> you actually installed and played the TestFlight build on.]_**

## 3. Purpose and target audience

Gold Rush is a two-player strategy card game built on the "I cut, you choose"
principle — the same rule children use to divide a slice of cake fairly.

Each round, one player privately draws seven mining cards and deals them into
two piles, turning one card face down. The other player then takes whichever
pile they prefer, and the splitter keeps the remainder. Because the person
dividing the cards does not choose which half they get, they are pushed toward
dividing honestly. Each player also holds six secret scoring cards that decide
what their collection is actually worth, so "fair" means something different to
each of them, and the bluffing lives in that gap.

**The problem it solves:** most two-player card games are either pure luck or
demand a long rules explanation. This one has a single rule everybody already
understands intuitively, but yields real strategic depth — deciding what to
hide, and reading what your opponent values.

**Target audience:** general audiences who enjoy strategy, card, and board
games. No reading level beyond the tutorial is required and there is no
violence, no mature content, and no chat. Suitable for roughly ages 9 and up.

**Not gambling.** Despite the prospecting theme, there is no wagering, no real
or simulated currency, no purchasable chips, no loot boxes, and no
casino-style mechanics. The gold is scoring points in a card game.

## 4. How to set up and access the main features

**No setup is required.** There is no account, no login, no credentials, and no
sample files. Launch the app and everything is immediately reachable from the
home screen.

The home screen offers three modes:

1. **Pass and play** — two people share one device. A hand-off curtain hides the
   board while the phone changes hands, so neither player sees the other's
   cards. *This mode needs no second device and is the fastest way to see the
   full game loop.*
2. **Play the prospector** — one player against the built-in AI opponent. *This
   requires nothing but the app itself and is the recommended way to review the
   app end to end.*
3. **Play a friend online** — two people on separate devices via Apple Game
   Center. This button is disabled unless the device is signed in to Game
   Center. It requires a second human on a second device; the two offline modes
   above exercise identical game rules and screens.

**How to Play** on the home screen opens a full illustrated rulebook covering
every rule, the deck composition, and the scoring families.

A complete game is eight rounds and takes roughly five minutes.

## 5. External services, tools, and platforms

| Service | What it does | Notes |
|---|---|---|
| **Google AdMob** (Google Mobile Ads SDK) | Serves a single banner ad on the home screen | The only third-party SDK in the app |
| **Apple Game Center** (GameKit) | Optional turn-based matchmaking for the online mode | Apple hosts the match state |

That is the complete list. Specifically:

- **No AI service.** The single-player opponent is a deterministic heuristic
  written in Swift and running entirely on the device. It is not a large
  language model, not a third-party AI service, and makes no network calls.
- **No backend server.** We operate no server of any kind. There is no account
  system, no database, and no analytics or crash-reporting SDK.
- **No payment processing**, no authentication provider, and no data provider.
- **No advertising tracking.** The app never presents the App Tracking
  Transparency prompt and never requests the advertising identifier. Ad
  requests are explicitly flagged non-personalised (`npa=1`), so Google serves
  contextual ads only. This matches the "not used for tracking" answers given
  in App Privacy.

The game's rules, deck, scoring, and AI opponent all run locally. Apart from
loading the banner ad and — in online mode only — relaying turns through Game
Center, the app does not use the network.

## 6. Regional differences

**There are none.** The app functions identically in every region. There is a
single English-language build with no region-gated features, no region-specific
content, no geo-detection, and no server-side configuration that could vary the
experience. The same rules, the same deck, the same modes, and the same banner
ad placement ship everywhere.

Ad *inventory* is filled by Google and will naturally differ by market, but no
app feature or content changes based on region.

## 7. Regulated industry / protected third-party material

**Not applicable.** Gold Rush does not operate in a regulated industry — there
is no gambling, wagering, finance, health, medical, legal, or educational
credentialing element.

All content is original and created by the developer: the game rules and design,
every card illustration (drawn programmatically in vector form in Swift), the
app icon, and all text. No licensed, trademarked, or third-party protected
material appears in the app. No documentation or credentials are required.

---

# 1. The screen recording

This is the one item that needs a physical device — it cannot be produced
here. Record it on the iPhone you have, using **the TestFlight build currently
under review**, so what the reviewer watches matches the binary they are
looking at.

Settings → Control Centre → add **Screen Recording**, then swipe down and hit
the record button.

**None of Apple's conditional items apply**, so the recording only needs to
show the core loop:

- No account registration, login, or deletion flow exists to show
- No purchase or subscription flow exists to show
- No user-generated content, reporting, or blocking exists to show
- No permission prompts exist to show — the app requests nothing

**Shot list — about two minutes:**

1. Start recording on the Home Screen and **tap the app icon**, so the launch is
   captured (Apple asks for this explicitly).
2. Let the home screen settle. Show the three mode buttons **and the banner ad**.
3. Tap **How to play**, scroll through the rulebook, and close it.
4. Tap **Play the prospector** to start a game against the AI.
5. Play through **at least two full rounds**, showing each step:
   - splitting the seven drawn cards into two piles
   - turning one card face down
   - confirming the split
   - the AI taking a pile
   - the round recap showing what was split and taken
   - choosing a pile yourself on the round where you are the chooser
6. Show the **collection** and the unseen-card tracker.
7. Either play to the end for the scoring screen, or start a **Pass and play**
   game to show the hand-off curtain — the second-best demonstration of the
   game's core mechanic.
8. Stop recording.

Upload it in App Store Connect under **App Review Information → Attachment**,
and reply to Apple's message in Resolution Centre pointing at it.
