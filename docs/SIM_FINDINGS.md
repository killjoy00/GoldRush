# Gold Rush — Simulator Findings

Produced by `GoldRushSim` on the committed engine, at the game counts stated.
Base seed `20260818`; runs are deterministic and reproducible.

**Update: the §7 proposal for P5 / P2 / P6 has been applied to the catalog**
(package "C" below — see §8 for the before/after numbers). Everything else in
the catalog is unchanged.

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

## 7. Proposals, and what shipped

In priority order, as originally proposed:

1. **Consider `scoringDraft` as the default.** It addresses the card spread in
   §5 structurally, without touching a single number — a weak card becomes one
   you chose not to take. This is the highest-leverage change available and
   still **not applied** — it's a rules-mode default, your call, not something
   I'd change unilaterally.
2. **Retune P5 / P2 / P6 — applied.** Three screening packages were tested
   before touching the catalog (a gentle version, an aggressive version, and a
   hybrid); the hybrid won and is what shipped. Numbers and effect are in §8.
3. **`L4 Riffle Box`** — the one payout outlier flagged under both agents *at
   the time this was written* (the 36-card catalog, pre-splitter-fix agent).
   **Superseded rather than applied.** §10 already shows the flag had moved
   to `D6 Muck Out` by the time the AI fix and the twelve new cards landed;
   §11 retunes D6, and a fresh 48-card sweep puts L4 unremarkably mid-table
   (50.6%, +1.06 SD) with no case for touching it.
4. **Keep `persistentHiddenCards` on.** No change — this was always the
   recommendation, not a proposal to cut it. See §3.
5. **Deck size is a weak lever** (§4). Left at 72, no change.

### Known gap

The hidden-information mechanics (§3, and the win-rate column of §4) are not
properly measured, because neither agent exploits asymmetric information. An
agent that models what its opponent *cannot* know would be needed to evaluate
them, and would also make a much better single-player opponent. That is the most
valuable remaining work on the simulator.

---

## 8. Applied: P5 / P2 / P6 retune ("package C")

Three packages were screened at 40,000 games before any catalog value changed,
specifically to avoid shipping a guess:

| Card | Before | Package A (gentle) | Package B (aggressive) | **Package C — shipped** |
|---|---|---|---|---|
| P5 Highgrader | 8/type | 11 | 13 | **13** |
| P2 Clean Claim | 20/10/0, bands ≤3/4–6 | 20/10, bands ≤4/5–7 | 24/12, bands ≤4/5–7 | **22/11, bands ≤4/5–7** |
| P6 Volume Play | −3 Fool's Gold | −4 | −5 | **−4** |

A undershot and B overshot — B flipped P6 from the strongest card in the deck
to one of the weakest, which just relocates the imbalance rather than fixing
it. C was the only package that brought all three within a few points of even.

Screening result (40k games, win rate when held):

| Card | Before | After (C, 40k screen) |
|---|---|---|
| P5 Highgrader | 36.5% | 48.2% |
| P2 Clean Claim | 40.9% | 48.6% |
| P6 Volume Play | 61.6% | 53.3% |

Confirmed at full scale — 100,000 games, matching the original measurement,
InferenceAgent mirror:

| Card | Before | After (C, 100k confirm) | Payout EV before → after |
|---|---|---|---|
| P5 Highgrader | 36.5% | **47.8%** | 10.5 → 17.0 |
| P2 Clean Claim | 40.9% | **48.3%** | 14.1 → 19.1 |
| P6 Volume Play | 61.6% | **53.5%** | 18.9 → 16.8 |

Full-deck spread, same run: SD **0.0350** (was 0.0476), min 43.2% (`S6 Grubstake`,
unchanged by this tune), max 57.0% (`O4 Sharpened Steel`, also unchanged) — a
**26% reduction in win-rate spread**, consistent with the screening estimate.
Cross-checked under `GreedyAgent` too, where all three move the same direction.

**One honest side effect.** The payout-outlier check (>1.5 SD from family mean,
§5's criterion) now also flags `P1 Pyrite Hoarder` (+1.71 SD) alongside the
pre-existing `L4 Riffle Box` (+1.58 SD). P1 itself is untouched — its family
mean moved because P2's payout dropped, which pulled Prospect's average down and
left P1 relatively further above it. Not a new problem, just the §5 metric
reacting to a shift elsewhere in the same family. Worth knowing if you retune
again, not urgent on its own.

`docs/simdata/balance-C-inference.csv` and `balance-C-greedy.csv` hold the full
36-card tables for this run, alongside the earlier `balance-inference.csv` /
`balance-greedy.csv` for direct comparison.

### What did not change

Only the three effects above moved. `S1`–`S6`, `D1`–`D6`, `L1`–`L6`, `V1`–`V6`,
`O1`–`O6`, and `P1`, `P3`, `P4` are untouched. Fixture 1 (§ the test suite) still
asserts **97** unchanged — it hand-verifies the PackMule optimizer against a
frozen snapshot of the original card definitions rather than the live catalog,
specifically so a retune like this one can't silently invalidate it. See the
"Decouple Fixture 1" commit for how that works.

---

## 9. Applied: twelve new cards (S7–P8)

Twelve candidate cards were proposed, taking each family from six to eight and
the catalog from 36 to 48. All twelve were screened at **100,000 games** with
the `inference` agent before any of them shipped, on the same footing as § 5.

Three needed new `ScoringEffect` cases: `bonusIfAtMost` (a ceiling rather than a
floor), `bonusIfExceeds` (one of your own types leading another by a margin),
and `bonusPerTypeWithinMargin` (parity with the opponent rather than a majority
over them). Each is covered by a boundary-checked fixture, since an off-by-one
in a threshold scores plausibly forever without ever looking wrong.

### First screen: nine landed, three did not

| Card | Win rate held | Verdict |
|---|---|---|
| S7 Gold Fever | 53.3% | ship |
| S8 Assay Office | 50.4% | ship |
| D7 Prospector's Eye | 46.4% | ship |
| **D8 Union Crew** | **41.9%** | re-tune |
| L7 River Rat | 53.8% | ship |
| L8 Fine Gold | 48.4% | ship |
| V7 Crystal Cache | 46.6% | ship |
| V8 Lode Miner | 53.0% | ship |
| O7 Traveling Crew | 53.6% | ship |
| O8 Broken Handles | 55.8% | ship |
| **P7 Lucky Strike** | **56.9%** | re-tune |
| **P8 Grubstake Partner** | **35.5%** | re-tune |

**D8** was strictly dominated by D1: the same 4-per-set rate, plus a penalty.
There was never a reason to prefer it.

**P8** was the worst card of all 48, and for two compounding reasons. Parity
within 1 turned out to be *rare* across ~30-card collections, so it paid the
least of anything in the deck (mean 9.5). And what it paid for — standing level
with your opponent — is not how anyone wins.

**P7** was the strongest of all 48, but the interesting part is *why*. Its
payout (19.9) was lower than P1 Pyrite Hoarder's (21.7), yet it won 5 points
more often. The difference is variance: SD **0.57** against P1's 8.49. Four
conditions each met by any ordinary collection meant it paid ~20 every single
game. It was not a scoring card so much as a flat bonus, and reliability beat
raw magnitude.

### What changed, and the confirmation run

| Card | Was | Now |
|---|---|---|
| D8 Union Crew | 4 per set, −4 per unmatched Shovel | **5** per set, −4 per unmatched Shovel |
| P7 Lucky Strike | 5 for each of ≥1 Nugget / ≥1 Quartz / ≥1 O+S set / ≥1 G+P set | **6** for each of **5+** Nugget / **4+** Quartz / **3+** O+S sets / **3+** G+P sets |
| P8 Grubstake Partner | 6 per type within **1** | **7** per type within **2** |

An intermediate pass is worth recording as a mistake avoided: D8 was first
tried at 6-per-set with the penalty softened to −3, which buffed both halves at
once and overshot to 57.3%. Buying the fairness with the base rate alone, and
leaving the −4 bite intact, is what landed it.

P7 at the raised thresholds *and* 6 points came back at 57.2% — unmoved. The
thresholds had done their job (SD rose 0.57 → 3.43, so the card finally had a
decision attached), but the extra point per condition cancelled the nerf out.
Pushing the thresholds further, rather than simply paying less, is what fixed
it: the card should be an achievement, not a formality.

Confirmed at 100,000 games:

| Card | First screen | Shipped |
|---|---|---|
| D8 Union Crew | 41.9% | **49.3%** |
| P7 Lucky Strike | 56.9% | **49.6%** |
| P8 Grubstake Partner | 35.5% | **50.9%** |

### Effect on the deck as a whole

Across all 48 cards the win-rate-when-held spread is **42.6% – 56.2%**, SD
**3.34pp**. The 36-card catalog after package C was 3.50pp, so the deck is
marginally *tighter* than before despite being a third larger — every one of
the twelve new cards sits inside the range the original 36 already spanned.

The two `OUTLIER` flags in the run are D6 Muck Out and P1 Pyrite Hoarder, both
original cards, both flagged on within-family payout deviation rather than win
rate. Neither is new and neither was touched here.

Raw CSV: `docs/simdata/balance_48cards_inference_100k.csv`.

### Caveat

The § 5 caveat applies unchanged: these are win rates under *random dealing*,
measured with agents that are decent but not strong. A card that rewards an
exotic line may be undervalued here simply because no agent plays that line.
P8 in particular pays for an objective — deliberate parity — that no agent
pursues on purpose, so its 50.9% is the floor of what a human could do with it,
not a measurement of the card at its best.

---

## 10. The agents were not beating "take the biggest pile"

`NaiveAgent` deals the draw alternately into two piles and always takes the
pile with more cards, never consulting a scoring card. It is the first
heuristic a new player reaches for, and it is a real strategy, so it is the
honest bar. Every agent in § 1–§ 6 was measured without it existing.

Both seats averaged, 20k games:

| | before the fix | after |
|---|---|---|
| inference vs naive | 50.9% | **63.4%** |
| greedy vs naive | **48.6%** (a loss) | **65.6%** |

### Which half was broken

The `dissect` subcommand pairs one agent's splitter with another's chooser, so
a result can be attributed rather than guessed at. Against the naive baseline,
40k games:

| | win rate |
|---|---|
| smart choosing (greedy) | 53.5% |
| smart choosing (inference) | 51.5% |
| smart splitting (inference) | 48.2% |
| smart splitting (greedy) | 44.0% |

Choosing well was worth about **+3.5pp**. Splitting "well" was worth **−6pp**.
They cancelled, which is exactly why the finished agents came out level with a
baseline that reads nothing.

### It was not the objective, it was the sizes

Two candidate causes, separated by measurement:

| splitter objective | vs naive |
|---|---|
| minimise the value gap (Greedy's original) | 44.0% |
| maximise the floor — maximin, no size limit | 45.0% |
| maximin, piles within one card of each other | **61.7%** |

Maximin is the better objective on principle and is worth a point, but **size
balance was carrying almost all of it.** A value-balanced cut need not be a
size-balanced one: "one Gold Nugget" and "six pieces of junk" can price the
same to the splitter, and it offered that division happily. Any chooser who
weighs volume at all — and volume genuinely scores, through per-card cards,
through sets, and through the Gold Nugget tiebreak — takes the big pile every
time, so the splitter kept the small one all game.

Both agents now maximise `min(value(A), value(B))` over cuts whose sizes
differ by at most one. `BalancedAgent` is kept as the ablation — `maximin` is
the size restriction off, `balanced` is it on — so the table above regenerates
rather than being a claim about a version of the code that no longer exists.

Seat balance is unchanged and slightly tighter: **49.5%–50.4%** across all four
agents, against 49.1%–50.4% before.

### What this costs the card measurements

Every number in § 5 and § 9 was produced by the agents this section just
changed, so they are all measured against a weaker player than the app now
ships. Re-running § 9's balance sweep with the fixed splitter (100k games,
`inference`, raw CSV in `docs/simdata/balance_48cards_fixed_splitter_100k.csv`):

- Deck-wide spread **43.1%–57.1%, SD 3.87pp**, against 42.6%–56.2% and 3.34pp
  before. Comparable, slightly wider.
- The largest movers are **P8 Grubstake Partner 50.9% → 56.7%** and **P2 Clean
  Claim 48.9% → 54.4%**, both up; **S7 Gold Fever 52.6% → 48.1%** down.
- The only within-family payout outlier is D6 Muck Out, as before.

P8 is the awkward one: § 9 tuned it *to* 50.9% against the old agent, and a
better splitter puts it at 56.7%. Nothing is broken — the spread is in the same
band and no card is wild — but the honest reading is that the catalog is tuned
against a moving target, and a retune should wait until the agents stop
improving rather than chase them.

### Still open

`inference` and `greedy` are now a dead heat head-to-head (49.8%), so the
opponent-modelling machinery continues to earn nothing measurable. That is a
separate problem from the one this section fixed.

---

## 11. Applied: D6 Muck Out retune, and L4's flag retired

A fresh full-catalog sweep (100k games, `inference`, seed 42, shipping code at
the time — the same conditions as § 10) to check whether anything has drifted
since, now that the app is live rather than mid-development:

```
card,name,family,win_rate_held,deviation_sd,flag
D6,"Muck Out",Dig,0.5782,+1.55,OUTLIER
```

Every other card sat comfortably under the ±1.5 SD flag, L4 Riffle Box
included (50.6%, +1.06 SD — squarely mid-table, not close to a flag). § 7
proposed retuning L4; § 10 already shows the flag had moved to D6 by the time
the AI fix and the twelve new cards landed. L4 was never actually the live
problem after that point — nobody had gone back to update § 7 to say so. It
doesn't need a change; the stale proposal needed correcting, which it now is.

### Why D6 specifically

D6 and L8 Fine Gold are the only two set-family cards paying 6 per set, the
highest base rate in the deck. L8's offsetting cost is `-1 per Gold Nugget` —
a type worth building toward on its own, so the penalty genuinely competes
with the rest of a hand. D6's is `-1 per Fool's Gold`, which a competent
player is already avoiding for free; the "cost" rarely bites. Same rate, a
penalty that isn't really one.

### The fix

```
6 per Ore+Shovel set  ->  5 per Ore+Shovel set     (penalty unchanged)
```

Screened at 40k games before touching anything (49.9%, essentially exact on
the first candidate — no second round needed), then confirmed with a full
48-card sweep at 100k:

| | before | after |
|---|---|---|
| D6 win rate when held | 57.8% | **49.4%** |
| D6 deviation from family mean | +1.55 SD (flagged) | −0.10 SD |
| Deck-wide spread | 43.0%–57.8%, SD 3.85pp | 43.3%–57.4%, SD 3.69pp |

D6 now sits alongside D3 Deep Shaft, D8 Union Crew and L4 Riffle Box — the
other "5 per set plus a real cost" cards — at 49–52%, rather than standing
apart from all of them. No other card's rate or SD moved outside normal
run-to-run noise, with one boundary case worth naming rather than
quietly ignoring: **P1 Pyrite Hoarder's flag deviation moved from 1.49 to
1.50** between the two runs and now prints `OUTLIER` at the threshold. P1 was
not touched, is in a different family from D6, and its win rate moved 0.25pp
(47.40% → 47.65%) — well inside the ~0.16pp standard error at 100k games for
a card sitting near 50%. `balance` measures every card against one shared
pool of simulated games rather than isolated batches, so a change to D6
perturbs the games it appears in, which cascades into other cards' numbers by
a fraction of a point. That is what happened here. Not a real outlier, and
not chased.

Raw CSVs: `docs/simdata/balance_48cards_before_D6_retune_100k.csv` and
`..._after_D6_retune_100k.csv`.

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
