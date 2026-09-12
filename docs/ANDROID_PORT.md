# Android port

Gold Rush is ported in-place rather than split into a second repository. The iOS app remains Swift/SwiftUI under `App/` + `Sources/`; Android lives under `Android/` as a Kotlin/Jetpack Compose app. Keeping both clients together makes rule-parity review and fixture testing much harder to drift accidentally.

## Architecture

The Swift engine remains the source of truth for game rules and the Swift agents remain the source of truth for bot behavior. Android ports those deterministic rules and policies into Kotlin rather than trying to bridge Swift through JNI or ship a second native toolchain.

| iOS / shared Swift | Android |
|---|---|
| `GoldRushEngine` | Kotlin engine package (`com.killjoy00.goldrush.engine`) |
| `GoldRushAgents` | Kotlin Prospector package (`com.killjoy00.goldrush.ai`) |
| `GoldRushUICore` | Kotlin/Compose controller state |
| `GoldRushUI` | Jetpack Compose |
| UserDefaults career data | Preferences DataStore (`goldrush_career_stats_v1`) |
| Game Center turn-based | Cross-platform service (later, if desired) |
| StoreKit remove-ads purchase | Google Play Billing (remaining) |
| Google Mobile Ads iOS | Google Mobile Ads Android (remaining) |

The parity contract is behavioral: identical deck composition, SplitMix64 stream, deterministic shuffle, setup/draft decisions, hidden-information boundaries, round transitions, scoring, Pack Mule optimization, tiebreaks, Prospector decision policy, career-stat aggregation, Claim Journal projection, and player-tableau privacy.

## Rules parity

The Android engine now implements the current game rather than a one-round prototype:

- 72-card mining deck with the exact eight-type composition and deterministic scaled-deck logic.
- All 48 current scoring cards across Strike, Dig, Sluice, Vein, Outfit, and Prospect.
- Every current scoring effect, including opponent-relative riders and thresholds.
- Exhaustive Pack Mule assignment to whichever Ore+Shovel / Gravel+Pan arrangement maximizes the player's score.
- Dealt setup: six scoring cards per player, three public and three secret.
- Current seven-card paired draft: take 1 / take 2 / take 2 / keep 1 and burn 1, with only the opening pick permanently secret.
- Compatibility support for the older eight-card/saved-draft paths already understood by the Swift engine.
- Together format: both players split and then choose, four rounds, 60 mining cards.
- Take Turns format: alternating split/choose, eight rounds, 60 mining cards.
- Motherlode: the final 18 mining cards come in 9-card draws with two buried cards.
- Persistent hidden information: a buried card in a declined pile remains structurally unavailable to that player forever.
- `PlayerView`, unseen-card accounting, simultaneous split sealing, round history, split log, and Claim Journal projections.
- Final scorecards and the exact tiebreak chain: score, most Gold Nuggets, fewest Fool's Gold, then Player 2.
- Full pass-and-play Compose routing for reveal/draft/split/choose/endgame instead of the temporary one-round demo.

Kotlin tests mirror the Swift scoring fixtures and full-game invariants so rule changes can be checked on both platforms.

## Claim Journal parity

Android now exposes the same match-long Claim Journal concept as iOS from inside an active game.

- Completed rounds are shown newest-first, grouped by round and split.
- Each split identifies who divided the cards and which pile the viewer took or kept.
- Mining cards are shown from the viewing player's permanent information boundary rather than from global `GameState` truth.
- A splitter remembers every card they personally drew, including a card they buried.
- A chooser learns a buried card only when they take that pile; a buried card in a declined pile remains `?` in the journal permanently.
- Pass-and-play projects the journal for the player currently holding the device; solo always projects it for the human Player 1.

Tests cover both ownership labels and the buried-card privacy boundary in each direction.

## My Claim / Tableau parity

Android now exposes the iOS-style My Claim tableau beside the Claim Journal during active play.

- The player's collected mining cards are grouped by all eight mining types with totals and compact card chips.
- The opponent section shows only cards the viewer has actually identified plus a count of cards they never saw.
- The player's six scoring cards are shown with public/secret status; all six remain visible to their owner and score normally.
- Current paired-draft face-up burns are shown for both players when present.
- Pass-and-play always builds the tableau from the player currently holding the device, while solo stays on human Player 1.
- The screen consumes only `PlayerView`, so it cannot reveal opponent collection identities outside the viewer's observation boundary.

## Prospector parity

Android also ports the shipping iOS `InferenceAgent` rather than using a simplified bot. The agent receives only `PlayerView`, never omniscient `GameState`, so secret scoring cards and unobserved buried cards remain genuinely unavailable to it.

- **Steady** matches iOS basic fidelity: maximin near-even splits, opponent-aware split tiebreaking, and expected-value pile selection without deliberate hidden-card placement.
- **Cunning** adds the iOS hidden-card placement policy, burying cards whose true opponent value is furthest from the opponent's inferred unseen-pool average.
- **Ruthless** adds the iOS full chooser model, including the hidden-card suspicion adjustment on close pile decisions.
- The opponent model reconstructs opponent-specific uncertainty from the public split log rather than incorrectly reusing the bot's own unseen pool.
- Scoring-card reveal priorities and the six-board draft prior match the Swift agent, including the current seven-card paired draft and saved-draft compatibility path.
- Solo keeps the human in Player 1 and the Prospector in Player 2, matching iOS `AgentTransport`.
- Compose exposes the same Steady / Cunning / Ruthless choice and defaults to Ruthless.

Integration tests drive complete games through the real Kotlin reducer for every Prospector tier, plus a drafted Take-Turns game. They assert that every bot action remains legal, control returns to the human correctly, the game terminates, and every drawn mining card is claimed.

## Career stats parity

Android now mirrors the on-device iOS career model and keeps the data local in Jetpack Preferences DataStore.

- Overall games, wins/losses, win rate, average score, average margin, and best score.
- Per-format records for Dealt/Drafted × Together/Take Turns using the same display labels as iOS.
- Per-scoring-family card counts, total points, games touched, and points per card for Strike, Dig, Sluice, Vein, Outfit, and Prospect.
- Pass-and-play records Player 1; solo records the human Player 1, matching the current iOS seat convention.
- Each started game receives a stable UUID and completed games are deduplicated before recording.
- The dedupe history retains the newest 500 game IDs, matching iOS's bounded-history behavior.
- Recording is triggered when the reducer first reaches `FINISHED`, so quickly leaving the score screen does not lose the result.
- Compose exposes a Career screen from the main menu and observes DataStore as a live Flow.

Pure Kotlin tests cover aggregation, all four format labels, deduplication, the 500-ID cap, and DataStore preference round-tripping.

## Remaining Android platform work

The remaining work is platform functionality, not game-rule, AI, career-stat, journal, or tableau reconstruction:

1. Add Android AdMob and Google Play Billing remove-ads entitlement.
2. Add Play Console signing/release automation and store metadata/screenshots.
3. Decide online architecture. Game Center cannot provide Android/iOS cross-play; if cross-platform friend play is desired, move turn transport to a small shared backend while keeping the engine client-side.

## Vercel

There is no Gold Rush Vercel project today. Pass-and-play, solo, career stats, the Claim Journal, and the My Claim tableau are on-device and should stay that way. Vercel becomes relevant only if Gold Rush replaces Game Center with cross-platform online matches or adds a web companion/admin surface.

## Build

CI is authoritative:

```bash
gradle -p Android :app:testDebugUnitTest :app:assembleDebug
```

The workflow uploads `app-debug.apk` as `gold-rush-android-debug`, so the current build can be sideloaded without a local Android toolchain.
