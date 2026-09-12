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
| UserDefaults career data | Android DataStore (remaining) |
| Game Center turn-based | Cross-platform service (later, if desired) |
| StoreKit remove-ads purchase | Google Play Billing (remaining) |
| Google Mobile Ads iOS | Google Mobile Ads Android (remaining) |

The parity contract is behavioral: identical deck composition, SplitMix64 stream, deterministic shuffle, setup/draft decisions, hidden-information boundaries, round transitions, scoring, Pack Mule optimization, tiebreaks, and Prospector decision policy.

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

## Remaining Android platform work

The remaining work is platform functionality, not game-rule or AI reconstruction:

1. Port career/stat persistence to Android DataStore.
2. Add Android AdMob and Google Play Billing remove-ads entitlement.
3. Add Play Console signing/release automation and store metadata/screenshots.
4. Decide online architecture. Game Center cannot provide Android/iOS cross-play; if cross-platform friend play is desired, move turn transport to a small shared backend while keeping the engine client-side.

## Vercel

There is no Gold Rush Vercel project today. Pass-and-play and solo are on-device and should stay that way. Vercel becomes relevant only if Gold Rush replaces Game Center with cross-platform online matches or adds a web companion/admin surface.

## Build

CI is authoritative:

```bash
gradle -p Android :app:testDebugUnitTest :app:assembleDebug
```

The workflow uploads `app-debug.apk` as `gold-rush-android-debug`, so the current build can be sideloaded without a local Android toolchain.
