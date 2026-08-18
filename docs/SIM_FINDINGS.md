# Gold Rush — Simulator Findings

Produced by `GoldRushSim` on the committed engine, at the game counts stated.
Base seed `20260818`; runs are deterministic and reproducible.

**No catalog values were changed.** Proposals are at the end, for your decision.

---

## Correction notice

An earlier version of this report was measured with a defective `InferenceAgent`
— it was losing to the trivial `GreedyAgent` 61/39 because it bet each split on
a noisy read of its opponent. That agent has been fixed (it now plays maximin
and edges the baseline in both seats), and **every table below has been
re-measured against the fixed agent.**

What that changed:

| Finding | Then | Now | Verdict |
|---|---|---|---|
| P1's last-choice edge | none | none | **unchanged, confirmed** |
| Card strength spread | 26 points | 25 points | **unchanged, confirmed** |
| Reveal choice | ~13 points | ~4.6 points | **shrank, still real** |
| Hidden-card count | ~12 points | within noise | **withdrawn — see §3** |
| `persistentHiddenCards` | 1.1–1.6 points | within noise | **withdrawn — see §3** |

The seat and balance results were measured with *mirror* matches — identical
agents in both seats — so the agent's absolute strength cancels out and those
numbers were never affected. The reveal and hidden-card results were not, and
were substantially artifacts of the broken agent.

**I also withdraw the recommendation to cut `persistentHiddenCards`.** See §3
for why the experiment could not have answered that question in the first place.

---

## The short version

| Question | Answer |
|---|---|
| Does P1, who chooses last, have an edge? | **No.** 49.9–50.7% across three agents. The seat is balanced. |
| Does the reveal decision matter? | **Yes, ~4.6 points** — and the intuitive heuristic is backwards. |
| Does hidden-card persistence matter? | **My test cannot tell you.** It is not a null result; it is a bad experiment. |
| Does residual-deck uncertainty matter? | Slightly. It adds ~7% to score spread across the range tested. |
| Are any cards out of line? | **On payout, two.** On win rate when held, a 25-point spread. |

---

## 1. Seat advantage — the question you asked

```
GoldRushSim seat --games 100000
```

P1 splits odd rounds, so P2 splits round 8 and **P1 chooses in the final round.**
Mirror matches use identical agents in both seats, so any gap is structural.

| Matchup | P1 win rate | 95% CI | P1 mean | P2 mean |
|---|---|---|---|---|
| random vs random | 0.5011 | ±0.0031 | 90.61 | 90.56 |
| greedy vs greedy | 0.5066 | ±0.0031 | 104.20 | 103.85 |
| inference vs inference | 0.4990 | ±0.0031 | 106.31 | 106.42 |

**Choosing last is worth essentially nothing.** Two mirrors are statistically
indistinguishable from 50%, and the third (greedy, +0.66 points) is small enough
to be one extra win per 150 games. Notably the strongest agent sits *below* 50%,
so the tiny greedy edge is a quirk of that strategy, not a property of the seat.

This is robust: the tiebreak awards ultimate ties to **P2**, so the seat carries
a handicap and still comes out level. Giving each player four splits and exactly
one Motherlode split evidently swamps whatever last-choice advantage exists.

**No change needed.**

---

## 2. The reveal decision

```
GoldRushSim reveal --games 50000
```

Three agents identical except for **which three cards they make public**:
`considered` (hide your riders and thresholds — the intuitive play), `random`,
and `inverted` (reveal exactly what `considered` hides).

| P1 policy | P2 policy | P1 win rate | 95% CI |
|---|---|---|---|
| considered | random | 0.4866 | ±0.0044 |
| random | considered | 0.5114 | ±0.0044 |
| considered | inverted | 0.4726 | ±0.0044 |
| inverted | considered | 0.5178 | ±0.0044 |
| random | inverted | 0.4843 | ±0.0044 |

Averaging each pairing across both seats:

- **inverted beats considered** by ~4.6 points of win rate (52.3% vs 47.7%)
- **inverted beats random** by ~1.6 points
- **random beats considered** by ~1.3 points

Ranking: `inverted > random > considered`, consistent in every ordering.

**The reveal decision is real but moderate — roughly 4.6 points, not the 13 I
first reported.** And the intuitive heuristic is still backwards: hiding your
majority riders and thresholds is the *worst* of the three policies.

The mechanism is a nice piece of design. In I-cut-you-choose the splitter must
divide so that *you* are indifferent. A splitter who cannot read you guesses, and
a guess is safe for them — concealment lowers the standard their split has to
meet. Advertising a convex card forces genuinely hard divisions, and every one
they misjudge pays you.

One caveat that also explains why the effect shrank: this only pays against an
opponent who **reads** your public cards. `GreedyAgent` ignores them entirely, so
against it the reveal policy is worth nothing measurable. The 13-point figure
came from a broken agent whose splits were exploitable in the first place.

**No change needed.** The agent's heuristic has been inverted to match.

---

## 3. Hidden cards and persistence — withdrawn

```
GoldRushSim hidden --games 50000
```

| Hidden/round | Persistent | Inference win rate | 95% CI | Mean unseen P1/P2 | Score SD |
|---|---|---|---|---|---|
| 0 | — | 0.5095 | ±0.0044 | 12.00 / 12.00 | 15.25 |
| 1 | yes | 0.5082 | ±0.0044 | 13.85 / 13.50 | 15.25 |
| 1 | no | 0.5077 | ±0.0044 | 12.00 / 12.00 | 15.28 |
| 2 | yes | 0.5056 | ±0.0044 | 15.52 / 15.05 | 15.35 |
| 2 | no | 0.5029 | ±0.0044 | 12.00 / 12.00 | 15.37 |

Every difference here is inside the confidence interval. The persistence effect
is 0.05 points at one hidden card and 0.27 at two; the hidden-card count moves
win rate 0.39 points across its whole range.

**I am not reporting this as "the mechanic does nothing." I am reporting it as a
failed experiment.**

Both agents price an unknown card the same way: the average of what remains in
their own unseen pool. Neither one *exploits* holding information the other
lacks — neither infers what the opponent is missing, nor plays differently
because a card is permanently secret rather than temporarily so. So the
experiment measured two players who do not use the information and found that
the information does not matter. That conclusion is about my agents, not about
your game.

Answering the question properly needs an agent built to exploit the asymmetry,
tested against one that ignores it. That does not exist yet.

What the data does show, weakly: hidden cards raise the unseen pool as designed
(12 → 15.5 cards) and nudge score spread up (15.25 → 15.35).

**Retraction:** my earlier suggestion that `persistentHiddenCards` was "the first
rule to cut" was wrong on the design merits regardless of the statistics. If a
face-down card is revealed to both players on claim, it is only secret during the
choice, and the permanent asymmetry — the reason to place a card face down at all
— disappears. The default (`true`) is correct.

---

## 4. Residual-deck uncertainty

```
GoldRushSim deck --games 50000 --deck-size 60,72,84
```

Cards **drawn** stay fixed at 60, so deck size varies residual uncertainty alone.

| Deck | Residual | Inference win rate | Mean unseen | Score SD |
|---|---|---|---|---|
| 60 | 0 | 0.5010 | 2.07 | 14.78 |
| 72 | 12 | 0.5069 | 14.07 | 15.34 |
| 84 | 24 | 0.5107 | 26.08 | 15.90 |

Small but monotonic: a tenfold increase in the unseen pool raises score SD by
about **7.6%** and win rate by 1 point. Residual uncertainty adds variance
rather than skill.

**72 is a reasonable choice.** Note this shares the §3 limitation — neither agent
exploits deck knowledge aggressively, so treat the win-rate column as a floor.

---

## 5. Card balance

```
GoldRushSim balance --games 100000 --agent greedy
GoldRushSim balance --games 100000 --agent inference
```

### Payout is close to balanced

Family means of per-card payout sit in a tight band. Under the criterion you
specified — payout more than 1.5 SD from the family mean — the flagged cards are:

| Agent | Flagged |
|---|---|
| greedy | L4 Riffle Box (+1.53 SD) |
| inference | L4 Riffle Box (+1.58 SD), D6 Muck Out (+1.50 SD) |

**L4 Riffle Box is flagged under both agents** and is the one payout outlier
worth taking seriously. Thirty-six hand-tuned cards landing this close is
genuinely unusual.

### Win rate when held is not balanced — and this survived the agent fix

| Strongest | Win rate | | Weakest | Win rate |
|---|---|---|---|---|
| P6 Volume Play | **0.618** | | P5 Highgrader | **0.365** |
| O4 Sharpened Steel | 0.573 | | P2 Clean Claim | 0.403 |
| S1 Rich Vein | 0.563 | | S6 Grubstake | 0.436 |

**A 25-point spread between the best and worst card to be dealt** (SD 4.8 points
across all 36). This matched the previous measurement almost exactly under a
completely different agent, which makes it the most robust finding in this
report.

Drawing P6 instead of P5 is worth more than any decision you make during the
game.

Why payout EV misses this: a card can pay average points and still lose. P2 Clean
Claim is a flat 20/10/0, so it can never produce a big score. P5 Highgrader asks
you to beat your opponent in three separate types at once — close to conjunctive
impossibility. P6 Volume Play just counts cards, which is always achievable and
always on.

**Judge the catalog on win rate when held, not payout EV.** The criterion you
specified measures the wrong quantity.

---

## 6. Rules variants

```
GoldRushSim toggles --games 20000
```

| Draft | Prog. reveal | Persistent | Motherlode | Mean score | Score SD | Range |
|---|---|---|---|---|---|---|
| no | no | yes | yes | 105.81 | 15.36 | 35–192 |
| no | no | yes | **no** | 99.11 | 14.91 | 42–190 |
| no | **yes** | yes | yes | 105.67 | 15.28 | 35–192 |

- **`motherlodeRounds` off** costs ~6.7 points of mean score and narrows the
  floor from 35 to 42. It is doing its job: producing big finishes.
- **`progressiveReveal`** barely moves scores now (105.81 → 105.67). Its large
  effect in the previous report was an artifact of the broken agent.
- Competent play compresses outcomes considerably: the score range tightened
  from 16–222 to **35–192**, and SD from ~18.6 to ~15.3.

---

## 7. Proposals, for your decision

Nothing has been changed in the catalog. In priority order:

1. **Consider `scoringDraft` as the default.** It addresses the 25-point card
   spread in §5 structurally, without touching a single number — a weak card
   becomes one you chose not to take. This is the highest-leverage change
   available and the one I would make first.
2. **If you retune, act on these three** (judged by win rate, and all three
   survived the agent fix):
   - `P5 Highgrader` (36.5%) — three simultaneous majorities is too conjunctive.
     Suggest 8 → 10 per type, or requiring only two of the three.
   - `P2 Clean Claim` (40.3%) — a flat payout cannot compete with scaling ones.
     Suggest 20/10/0 → 26/14/0.
   - `P6 Volume Play` (61.8%) — always-on and unconditional. Suggest the Fool's
     Gold penalty at −4 rather than −3.
   Each is one integer in `ScoringCardCatalog.swift`.
3. **`L4 Riffle Box`** is the one payout outlier flagged under both agents. Its
   −2 per unmatched Gravel is a smaller drag than intended. Suggest −3.
4. **Keep `persistentHiddenCards` on.** See §3.
5. **Deck size is a weak lever** (§4). Leave it at 72.

### Known gap

The hidden-information mechanics (§3, and the win-rate column of §4) are not
properly measured, because neither agent exploits asymmetric information. An
agent that models what its opponent *cannot* know would be needed to evaluate
them, and would also make a much better single-player opponent. That is the most
valuable remaining work on the simulator.

---

## Reproducing

```bash
swift build -c release
./.build/release/GoldRushSim seat    --games 100000
./.build/release/GoldRushSim balance --games 100000 --agent greedy
./.build/release/GoldRushSim balance --games 100000 --agent inference
./.build/release/GoldRushSim hidden  --games 50000
./.build/release/GoldRushSim reveal  --games 50000
./.build/release/GoldRushSim deck    --games 50000 --deck-size 60,72,84
./.build/release/GoldRushSim toggles --games 20000
```

Raw CSV for every table is in `docs/simdata/`.
