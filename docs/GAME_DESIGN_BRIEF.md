# Gold Rush — current design brief

Gold Rush is a two-player card game about dividing a mining claim when the other player gets first choice. The core mechanism is **I cut, you choose** with asymmetric scoring and persistent hidden information.

This document describes the current rules. It is intended as a design handoff rather than an engineering specification.

## The central decision

A player privately draws mining cards, divides all of them into two non-empty piles, and turns part of the draw face down. The opponent chooses one pile; the splitter keeps the other.

The piles may be any sizes as long as both are non-empty. Near-equal pile sizes are an AI strategy, not a game rule.

The interesting problem is that the players do not value the piles the same way. Each player has six scoring cards, so an apparently balanced split for one scoring plan can be very lopsided for the other.

## Mining deck and rounds

The mining deck has 72 cards. A standard game puts 60 into play.

- Normal split: 7 cards, 1 face down.
- Motherlode split: 9 cards, 2 face down.
- The splitter knows every card they drew, including the buried cards.
- The chooser sees the face-up cards before choosing.
- The chooser learns any buried card in the pile they take.
- A buried card in the pile the chooser declines remains unknown to them permanently.

There are two pacing formats:

### Together

Both players draw and split simultaneously, then each chooses from the opponent's split. There are 4 rounds: three normal rounds and one Motherlode round.

Each player still makes four splits and four choices. Total cards in play: 60.

### Take Turns

One player splits and the other chooses, then the roles alternate. There are 8 rounds: six normal rounds and two Motherlode rounds.

Each player makes four splits and four choices. Total cards in play: 60.

## Scoring-card setup

Every player ends setup with six scoring cards, all of which score at the end.

### Dealt

Six cards are dealt at random to each player. Three are public and three stay secret.

### Drafted

Each player opens a separate eight-card pack.

1. From 8: **keep 1, discard 1 face up, pass 6**.
2. From 6: keep 1, pass 5.
3. From 5: keep 1, pass 4.
4. From 4: keep 1, pass 3.
5. From 3: keep 1, pass 2.
6. From the final 2: **keep 1, discard 1 face up**.

Each player finishes with six cards. The opening keep is the one card from that opening pack the opponent never sees; all later kept cards have passed through the opponent's hands. Both discards are public.

This draft uses 16 of the 48 scoring cards: 12 are kept and 4 are burned.

## Scoring system

The scoring deck contains 48 cards: eight in each of six families.

- **Strike** — primarily Gold Nuggets.
- **Dig** — primarily Ore + Shovel sets.
- **Sluice** — primarily Gravel + Pan sets.
- **Vein** — primarily Quartz.
- **Outfit** — primarily Tools.
- **Prospect** — broader or stranger incentives: junk, breadth, volume and comparisons.

Scoring cards include linear rewards, caps, thresholds, escalating rewards, set rewards, opponent-relative majorities and other conditional payouts.

### Sets and Pack Mules

- One Gold Ore + one Shovel forms an Ore set.
- One Gravel + one Pan forms a Gravel set.
- A Pack Mule can fill the Shovel slot of one Ore set or the Pan slot of one Gravel set.
- Pack Mules also count as Tools for Tool-scoring effects.
- The game searches legal Mule allocations and uses the one that maximizes the player's final score.

## Winning

After the final claim, all six scoring cards pay out.

Tiebreaks:

1. Most Gold Nuggets.
2. Fewest Fool's Gold.
3. If still tied, Player 2 wins the final tiebreak.

## Information model

Gold Rush treats information as a game resource rather than a presentation effect.

A player can know:

- their own scoring cards;
- the opponent's public scoring cards;
- every mining card they personally drew;
- every face-up mining card they saw while choosing;
- every mining card in a pile they ultimately claimed.

A player cannot retroactively learn a face-down card that they declined. The round recap and Claim Journal preserve that boundary instead of revealing the card later.

## Current supporting features

The iOS implementation includes:

- Pass and Play;
- solo AI with multiple difficulty levels;
- Game Center turn-based friend play;
- Together and Take Turns formats;
- Dealt and Drafted scoring-card setups;
- round recaps;
- a match-long Claim Journal;
- a full scoring-card compendium;
- on-device career statistics;
- itemized final scoring.

## AI and simulation

The engine is deterministic from a seed and supports large simulation runs. Agents receive the same restricted `PlayerView` as the UI rather than full game state, so an AI cannot accidentally inspect hidden cards.

Draft valuation uses a symmetric ahead/behind opponent prior for opponent-relative scoring cards. This prevents comparison cards from being treated as zero-value simply because no opponent collection exists during setup.

`docs/SIM_FINDINGS.md` contains historical measurements. Any section measuring the previous seven-card draft should be considered historical until it is explicitly re-run against the eight-card rules described above.

## Design questions still worth studying

- Does the eight-card draft create enough meaningful denial decisions without taking too long?
- How much does Drafted reduce deal variance relative to Dealt after strong draft AI is used?
- Are the best face-down decisions strategically legible to human players?
- Do Together and Take Turns produce meaningfully different strategies despite identical split/choice counts?
- Which scoring cards create the most interesting cross-purposes rather than simply the highest points?
- Does the permanent-hidden-card rule create memorable inference, or mostly uncertainty players cannot use?
- Is the 48-card scoring catalog learnable enough now that the compendium exists, or does it still need onboarding structure?
