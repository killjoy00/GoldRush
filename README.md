# Gold Rush

Gold Rush is a two-player iOS card game built around **I cut, you choose**: one player divides a private draw into two piles, hides part of the information, and the opponent chooses which pile to take. Each player has six scoring cards that make the same mining cards worth different amounts to each side.

## Current game

- **60 mining cards enter play** from a 72-card deck.
- A normal split uses **7 cards with 1 face down**.
- The Motherlode uses **9 cards with 2 face down**.
- **Together** mode has both players split simultaneously for 4 rounds.
- **Take Turns** alternates splitter/chooser roles for 8 rounds.
- Both formats give each player four splits and four choices and put the same 60 mining cards into play.
- A buried card stays unknown to a chooser who declines that pile.

### Scoring-card setup

**Dealt:** six scoring cards at random. Three are public; three stay secret.

**Drafted:** each player opens a separate pack of eight.

1. From 8: keep 1, discard 1 face up, pass 6.
2. From 6, 5, 4 and 3: keep 1, pass the rest.
3. From the final 2: keep 1, discard 1 face up.
4. Each player finishes with six scoring cards. The opening keep is the one permanent secret from the pack they opened.

The full 48-card scoring catalog is split across Strike, Dig, Sluice, Vein, Outfit and Prospect families.

## Player-facing features

- Pass and Play
- Solo play against multiple AI difficulty tiers
- Game Center turn-based friend play
- Round recap and **Claim Journal** with privacy-safe historical splits
- Full **Scoring Card Compendium**
- On-device **Career Stats** by format and scoring family
- Itemized end-game scoring and Pack Mule allocation

Career data stays in local `UserDefaults`; the game does not require an account or analytics backend.

## Package architecture

The project is intentionally layered:

- `GoldRushEngine` — deterministic rules, state, scoring, hidden-information projection
- `GoldRushAgents` — AI strategies that consume only `PlayerView`
- `GoldRushUICore` — view models and match transports without SwiftUI
- `GoldRushUI` — SwiftUI screens, Game Center and player-facing presentation
- `GoldRushSim` — command-line simulation and balance tooling
- `GoldRushEngineTests` — engine, serialization, hidden-information and UI-core tests

The important boundary is `PlayerView`: UI and agents receive a projection of what one player is legitimately allowed to know rather than the full `GameState`.

## Development

```bash
swift test
swift run GoldRushSim --help
```

The package targets Swift 6. UI files are guarded with `#if canImport(SwiftUI)` so engine tests can run outside iOS while Xcode type-checks the SwiftUI target for the app.

See `docs/GAME_DESIGN_BRIEF.md` for a design-focused description of the game and `docs/SIM_FINDINGS.md` for historical simulation notes. Simulation findings written before the eight-card draft should be treated as measurements of the earlier draft implementation unless explicitly re-run against the current rules.
