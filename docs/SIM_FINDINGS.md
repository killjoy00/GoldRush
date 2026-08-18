# Gold Rush — Simulator Findings

All numbers below were produced by `GoldRushSim` on the committed engine, at the
game counts specified. Nothing here is estimated or extrapolated. Reproduce any
row with the command in its section; the base seed is `20260818` and results are
deterministic.

**Per your instruction, no catalog values were changed.** Proposals are listed
for your decision at the end.

---

## The short version

| Question | Answer |
|---|---|
| Does P1, who chooses last, have an edge? | **No.** 50.1–50.7% across all three agents. The seat is balanced. |
| Does the reveal decision matter? | **Emphatically yes — up to 13 points of win rate.** But the intuitive heuristic is backwards. |
| Does `persistentHiddenCards` earn its rule? | **Marginally.** Real but small: 1.1–1.6 points. The hidden-card *count* is worth 12. |
| Does residual-deck uncertainty matter? | **Barely.** Doubling the unseen pool moves win rate 0.6 points. |
| Are any cards out of line? | **On payout, almost none.** On win rate when held, badly — a 26-point spread. |

One finding that is not about the game: **my InferenceAgent is weaker than
GreedyAgent**, losing ~61/39 in both seats. That is reported honestly below
rather than buried, and it qualifies how some of the other tables should be read.

---

## 1. Seat advantage — the question you asked

```
GoldRushSim seat --games 100000
```

P1 splits odd rounds, so P2 splits round 8 and **P1 chooses in the final round**.
Mirror matches use identical agents in both seats, so any gap is structural
rather than a strength difference.

| Matchup | P1 win rate | 95% CI | P1 mean | P2 mean | Mean margin |
|---|---|---|---|---|---|
| random vs random | 0.5011 | ±0.0031 | 90.61 | 90.56 | +0.05 |
| greedy vs greedy | **0.5066** | ±0.0031 | 104.20 | 103.85 | +0.36 |
| inference vs inference | 0.5015 | ±0.0031 | 89.41 | 89.28 | +0.13 |

**Choosing last is worth essentially nothing.** Two of the three mirrors are
statistically indistinguishable from 50%. The greedy mirror shows +0.66 points
against a ±0.31 interval — real, but roughly one extra win in 150 games.

This is a good result for the design, and it is not an accident of the tiebreak:
ultimate ties go to P2, so the tiebreak works *against* P1 and the measured edge
survives it. The alternation (P1 on odd rounds) gives each player four splits and
exactly one Motherlode split, and that symmetry evidently dominates whatever
last-choice advantage exists.

---

## 2. The reveal decision — the most interesting result

```
GoldRushSim reveal --games 50000
```

Every agent here is identical except for **which three cards it makes public**.
Three policies: `considered` (hide opponent-relative riders and sharp
thresholds — the intuitive heuristic), `random`, and `inverted` (reveal exactly
what `considered` would hide).

| P1 policy | P2 policy | P1 win rate | 95% CI | Mean margin |
|---|---|---|---|---|
| considered | random | 0.4786 | ±0.0044 | −1.75 |
| random | considered | 0.5278 | ±0.0044 | +2.18 |
| considered | inverted | **0.4360** | ±0.0043 | −5.31 |
| inverted | considered | **0.5678** | ±0.0043 | +5.54 |
| random | inverted | 0.4622 | ±0.0044 | −3.15 |

**The reveal decision is not decorative — it is one of the strongest levers in
the game.** The gap between the best and worst policy is about **13 points of
win rate** (43.6% vs 56.8%), consistent in both seat orderings.

**But the intuitive heuristic has the sign backwards.** The ranking is
`inverted > random > considered`. Hiding your majority riders and threshold
cards — the "obvious" play — is actively worse than advertising them.

The mechanism is worth understanding because it is a genuinely nice piece of
game design. In I-cut-you-choose, the splitter must divide the draw so that
*you* are indifferent. A splitter who cannot read you will guess, and guesses
are safe. A splitter who *can* read you will build piles that are equal to you —
which is exactly the outcome that denies you a windfall. Concealment does not
protect you; it just makes the opponent's job easier by lowering the standard
they have to meet. Revealing a convex card (a threshold, a per-Nth ladder) forces
the splitter into genuinely hard divisions, and every division they get wrong
pays you.

**This is a real design finding, and the mechanic is earning its place.** No
change is needed to the rules. What it does mean is that my `InferenceAgent`'s
`concealmentValue` heuristic is wrong and should be inverted — see §7.

---

## 3. Hidden cards and persistence

```
GoldRushSim hidden --games 50000
```

| Hidden/round | Persistent | Inference win rate | 95% CI | Mean margin | Mean unseen P1/P2 |
|---|---|---|---|---|---|
| 0 | — | 0.4785 | ±0.0044 | −0.22 | 12.00 / 12.00 |
| 1 | yes | 0.4035 | ±0.0043 | −6.07 | 13.84 / 14.71 |
| 1 | no | 0.4141 | ±0.0043 | −5.30 | 12.00 / 12.00 |
| 2 | yes | 0.3596 | ±0.0042 | −9.22 | 15.52 / 16.22 |
| 2 | no | 0.3760 | ±0.0042 | −8.11 | 12.00 / 12.00 |

Two separate effects, and they are very different sizes.

**The hidden-card count is a huge lever.** Going from 0 to 2 face-down cards per
round swings the outcome by **12 points** (47.85% → 35.96%) and the mean margin
by 9 points. Face-down cards are doing an enormous amount of work in this design.

**`persistentHiddenCards` is a real but small effect.** Turning persistence off
moves win rate by **1.06 points** at one hidden card and **1.64 points** at two.
Both exceed the ±0.43 interval, so the mechanic is not inert — it genuinely
changes outcomes.

**Verdict on your framing:** persistence does move win rates, so by the standard
you set it earns its rule. But it earns it by the narrowest margin of any
mechanic measured here, while carrying real costs — it is the rule that makes the
unseen tracker per-player rather than global, and it is the reason the GameKit
implementation has a `matchData` visibility caveat at all. If you ever want to
simplify the game, **this is the first rule I would cut**, and the data says you
would lose about 1.5 points of strategic depth doing it.

Note the asymmetry in the unseen columns: at 2 hidden per round with persistence
on, P2 ends with more unseen cards than P1 (16.22 vs 15.52). That is the seat
structure showing up — P1 chooses in four rounds including the final Motherlode.

---

## 4. Residual-deck uncertainty

```
GoldRushSim deck --games 50000 --deck-size 60,72,84
```

Cards **drawn** stay fixed at 60, so deck size varies residual uncertainty alone.

| Deck | Residual | Inference win rate | 95% CI | Mean unseen | Score SD |
|---|---|---|---|---|---|
| 60 | 0 | 0.3870 | ±0.0043 | 2.69 | 18.29 |
| 72 | 12 | 0.3930 | ±0.0043 | 14.69 | 18.54 |
| 84 | 24 | 0.3985 | ±0.0043 | 26.69 | 18.89 |

**Residual uncertainty barely matters.** Going from a deck that is fully dealt to
one that leaves 24 cards unseen — a tenfold increase in the unseen pool — moves
win rate by **1.2 points total** and score SD by 0.6.

The 12 never-dealt cards in the standard deck are close to inert. If you wanted
the residual to matter you would need to make deck-tracking pay off more
directly; as the rules stand, what a player does not know about the *undealt*
deck is far less important than what they do not know about the *opponent's
face-down claims*, which §3 shows is worth ten times as much.

**Practical implication:** 72 is a fine deck size, but not because of the
residual. Choose it for the type proportions, not the uncertainty.

---

## 5. Card balance

```
GoldRushSim balance --games 100000 --agent greedy
GoldRushSim balance --games 100000 --agent inference
```

### Payout is well balanced

Family means of per-card payout sit in a tight band: Strike 17.7, Dig 17.6,
Sluice 17.0, Vein 19.0, Outfit 16.9, Prospect 15.8.

Under the flag criterion you specified — payout more than 1.5 SD from the family
mean — **only one card trips under greedy play**:

| Card | Name | Payout EV | Family mean | Deviation |
|---|---|---|---|---|
| L4 | Riffle Box | 19.50 | 17.04 | **+1.53 SD** |

Under inference play three cards trip (S3 −1.64, D1 −1.72, L1 −1.87), but those
reflect that agent's weaker set-building rather than the cards themselves, so I
would not act on them.

**By the metric you asked for, the catalog is in good shape.** That is a real
result: 36 hand-tuned cards landing this close is unusual.

### Win rate when held is *not* balanced

The flag criterion misses the more important signal. Mean win rate when held is
50.0% by construction, but the **standard deviation across the 36 cards is 5.3
points**, and the extremes are far apart:

| Strongest | Win rate | | Weakest | Win rate |
|---|---|---|---|---|
| P6 Volume Play | **0.629** | | P2 Clean Claim | **0.368** |
| S1 Rich Vein | 0.576 | | P5 Highgrader | **0.370** |
| V4 Prism | 0.572 | | L1 Wash Plant | 0.429 |
| O4 Sharpened Steel | 0.570 | | S6 Grubstake | 0.437 |
| V3 Crystal Trade | 0.552 | | L5 Downstream Claim | 0.448 |

**A 26-point spread between the best and worst card to be dealt.** Drawing P6
instead of P2 is worth more than any decision you make during the game.

Why payout EV misses this: a card can pay average points and still lose, if the
collection it rewards is one that loses. P2 Clean Claim pays 14.4 — near its
family mean — but it is a flat 20/10/0 with no scaling, so it cannot ever produce
a big score, and holding it means holding one fewer card that can. P5 Highgrader
pays 10.5 and asks you to beat your opponent in three separate types at once,
which is close to conjunctive impossibility. P6 Volume Play just counts cards,
which is always achievable and always on.

**Recommendation: judge the catalog on win rate when held, not payout EV.** The
flag threshold you specified is measuring the wrong quantity. I have left both
columns in the CSV so you can use either.

---

## 6. Rules variants

```
GoldRushSim toggles --games 20000
```

Selected rows (full table in `simdata/toggles.csv`; win rate is InferenceAgent
as P1 versus GreedyAgent, so read the *differences*, not the absolute level):

| Draft | Prog. reveal | Persistent | Motherlode | Win rate | Mean score | Score SD | Range |
|---|---|---|---|---|---|---|---|
| no | no | yes | yes | 0.3905 | 96.26 | 18.57 | 16–222 |
| no | **yes** | yes | yes | **0.3123** | 96.00 | 19.15 | 16–222 |
| no | no | yes | **no** | 0.4216 | 90.55 | 17.44 | 17–193 |
| **yes** | no | yes | yes | 0.4276 | 97.83 | 19.88 | 27–212 |

- **`progressiveReveal` is the biggest single lever** — 7.8 points of win rate.
  Revealing only two cards at setup withholds a lot of the information that §2
  showed is decisive. It makes the game substantially more about hidden
  information and substantially swingier.
- **`motherlodeRounds` off** costs ~6 points of mean score (96.3 → 90.6) and
  narrows the range from 16–222 to 17–193. It is doing what it was designed to
  do: producing big finishes.
- **`scoringDraft` on** raises mean score slightly and widens SD, and it removes
  the 26-point deal luck documented in §5 — with a draft, a weak card is a card
  you chose not to take. **If the card-strength spread in §5 concerns you,
  turning on the draft is a more robust fix than retuning.**
- The observed score range of **16 to 222** around a mean of ~96 is very wide.
  Worth knowing before you tune anything for "typical" scores.

---

## 7. The InferenceAgent is currently weaker than GreedyAgent

Reported plainly because it qualifies several tables above.

| Matchup | Inference win rate |
|---|---|
| inference (P1) vs greedy (P2) | 0.3915 |
| greedy (P1) vs inference (P2) | 0.6192 → inference as P2: 0.3808 |

It loses about 61/39 in **both** seats, so this is the strategy, not the seat.
Mirror mean scores confirm it: greedy mirrors average 104.2, inference mirrors
89.4 — the inference strategy accumulates fewer points outright.

Two likely causes, both fixable and both now evidenced:

1. **Its reveal heuristic is backwards.** §2 shows `considered` — the policy
   InferenceAgent uses — is the *worst* of the three tested. Inverting
   `concealmentValue` should be worth several points on its own.
2. **Its split objective may be overreaching.** It maximizes the pile it expects
   to be left with, penalizing the opponent-gap at a hand-set weight of 1.5. If
   its opponent model is noisy — and built from only three public cards, it is —
   that objective offers exploitable splits, while Greedy's equalize-to-self is
   robust precisely because it assumes nothing.

Where this matters for the tables above: §3, §4 and §6 all report *InferenceAgent
win rate* as their metric, so their absolute levels sit below 50%. The
**differences between rows remain valid** — the agent is held constant within
each table — but do not read the absolute numbers as statements about balance.
§1 and §5 use mirror matches and are unaffected.

This is worth fixing before the app ships single-player, since InferenceAgent is
what the difficulty tiers will run.

---

## 8. Proposals, for your decision

No values have been changed. In priority order:

1. **Invert `InferenceAgent.concealmentValue`** (agent code, not catalog). §2 says
   the current sign is wrong and §7 says it is costing the agent real strength.
   This is a strategy bug, not a balance change, and I would do it regardless.
2. **Consider `scoringDraft` as the default.** It addresses the 26-point card
   spread in §5 structurally, without touching a single catalog number, and it
   measurably widens outcomes. This is the highest-leverage change available.
3. **If you want to retune anyway, act on these three**, judged by win rate:
   - `P5 Highgrader` (37.0%) — three simultaneous majorities is too conjunctive.
     Suggest 8 → 10 per type, or requiring only two of the three.
   - `P2 Clean Claim` (36.8%) — flat payouts cannot compete with scaling ones.
     Suggest 20/10/0 → 26/14/0.
   - `P6 Volume Play` (62.9%) — always-on and unconditional. Suggest 1 per card →
     1 per card with the Fool's Gold penalty at −4.
   Each is a single integer in `ScoringCardCatalog.swift`; I can re-run the full
   balance sweep after any change.
4. **`persistentHiddenCards` is the cut candidate** if you ever want to simplify
   (§3). It is worth ~1.5 points and costs real complexity.
5. **Deck size is not a useful lever** (§4). Leave it at 72.

---

## Reproducing

```bash
swift build -c release
./.build/release/GoldRushSim seat    --games 100000
./.build/release/GoldRushSim balance --games 100000 --agent greedy
./.build/release/GoldRushSim hidden  --games 50000
./.build/release/GoldRushSim reveal  --games 50000
./.build/release/GoldRushSim deck    --games 50000 --deck-size 60,72,84
./.build/release/GoldRushSim toggles --games 20000
```

Raw CSV for every table is in `docs/simdata/`. Runs are deterministic from the
base seed, and parallel execution reproduces serial execution exactly, so any
number here can be regenerated bit-for-bit.
