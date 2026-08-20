# Gold Rush — design brief

*A self-contained handover for discussing this game's design somewhere else.
Paste the whole thing into a fresh conversation; it assumes no prior context.*

---

## What I want from you

I've designed and built a two-player card game called **Gold Rush**. It works,
it's balanced, and it's on TestFlight. I want to think about the *design* — is
it actually fun, what's weak, what could be sharper. Please engage with it as a
game designer, not an engineer: I'm not looking for code.

Things I'd find useful: where the interesting decisions are and where they're
absent, whether the scoring catalog has dead weight, what a third player would
break, whether the theme and mechanics reinforce each other, and what you'd cut.

Push back on my assumptions. I've already been wrong about several of these and
found out the hard way.

---

## The core loop

It's **I-cut-you-choose**, eight times, with a deck of mining cards.

Each round:

1. The **splitter** privately draws 7 cards (9 in the last two rounds). The
   chooser never sees the drawn set as a whole.
2. The splitter divides them into **two piles**, each at least one card.
3. The splitter turns **exactly one card face down** (two in the last two
   rounds), placed in either pile as they like.
4. The **chooser** takes a pile. The splitter keeps the other.
5. Face-down cards are revealed only to whoever took that pile — and stay hidden
   from the opponent **permanently**.

The splitter role alternates. Over 8 rounds each player splits 4 times and
chooses 4 times, and each splits exactly one of the two big final rounds.

60 of the 72 cards are dealt. **Twelve never enter play**, so neither player ever
knows the full picture.

## What you're collecting

The 72-card mining deck:

| Card | Count |
|---|---|
| Gold Nugget | 14 |
| Fool's Gold | 10 |
| Gold Ore | 10 |
| Gravel | 10 |
| Shovel | 8 |
| Pan | 8 |
| Quartz | 8 |
| Pack Mule | 4 |

Two of these pair up into **sets**, matched 1:1:
- **Gold Ore + Shovel**
- **Gravel + Pan**

**Pack Mule** is the wildcard. Each mule can fill the Shovel slot of one
Ore+Shovel set *or* the Pan slot of one Gravel+Pan set — not both. It does *not*
count as a Shovel or Pan for cards that pay per-Shovel or per-Pan. It always
counts as exactly one **Tool** (Tool = Shovel, Pan, or Pack Mule).

Because a mule can go either way, scoring involves a small optimisation: you
allocate mules to whichever slots maximise your total.

## How you score

Separately, there are **48 scoring cards** in six families of eight. Each player
gets **6**, and **all six score at the end** — but only **3 are made public** at
the start. The other three stay secret the whole game.

The six families, by what they reward:

- **STRIKE** — Gold Nuggets
- **DIG** — Ore+Shovel sets
- **SLUICE** — Gravel+Pan sets
- **VEIN** — Quartz
- **OUTFIT** — Tools
- **PROSPECT** — odd angles: junk, breadth, volume, cross-category majorities

Within each family the eight cards vary the shape of the payout: flat per-card
rates, per-set rates, escalating ladders (the Nth quartz is worth more than the
first), caps, thresholds ("+8 if you have 4+ sets"), ceilings ("+8 if you hold 7
or *fewer* Tools"), penalties for unmatched cards, **majority riders** ("+7 if
you have strictly more Gold Nuggets than your opponent"), and one card that pays
for staying *level* with your opponent rather than beating them.

All majority comparisons require **strictly more**. Ties pay nothing to either
player.

**Tiebreak:** most Gold Nugget, then fewest Fool's Gold, then Player 2.

## The two setup variants

- **Dealt** (default): six random scoring cards each, with a rule that no player
  may hold more than two from the same family.
- **Drafted**: twelve cards face up, players alternate picking in a snake order
  until each has six. No luck of the deal.

---

## What I've measured

I built a headless simulator and ran roughly 570,000 games with three AI
opponents of increasing sophistication. Findings that matter for design:

**The seat is balanced.** Player 1 chooses in the final round, which sounded like
an advantage. It isn't — 49.9%–50.7% across three different AIs. The alternation
apparently swamps it.

**Which card you're dealt matters more than how you play.** Under random dealing,
win rate when holding a given scoring card ranges from **43% to 56%** across the
48 cards. That's a bigger swing than any in-game decision produces. Drafting
removes it entirely, which is why it exists as an option.

That range used to be 36%–62%, over the original 36 cards. It narrowed because
the worst offenders were re-tuned on simulator data, not because the problem is
solved — the spread is still wider than anything skill contributes.

**The reveal decision is real but modest** — about 4.5 points of win rate between
the best and worst policy for choosing which 3 cards to make public.

**And the intuitive reveal heuristic is backwards.** Hiding your majority riders
and threshold cards is the *worst* policy; advertising them is the best. The
reason seems structural: in I-cut-you-choose the splitter must divide so that
*you* are indifferent. A splitter who can't read you just guesses, and guessing
is safe for them. Concealment lowers the bar their split has to clear.
Advertising a sharp card forces genuinely hard divisions, and every one they
misjudge pays you.

**I could not measure whether the hidden-card mechanic earns its place.** My AIs
all price an unknown card the same way — the average of what they haven't seen —
and none of them *exploit* holding information the other lacks. So the experiment
measured players who ignore the mechanic and unsurprisingly found it didn't
matter. That's a flaw in my test, not a finding about the game. Genuinely open
question.

---

## What I'm uncertain about

Honest list, in rough priority order:

1. **Is the hidden card doing enough work?** It's one card out of seven, and
   permanently secret. It should create paranoia; I don't know whether it
   actually does, or whether players just shrug and move on.

2. **Is 48 scoring cards too many?** It started at 36 and grew by twelve. Six
   families of eight is tidy, but several cards within a family are
   near-substitutes (a flat rate vs. a slightly different flat rate). Would 24
   sharper cards be better than 48 varied ones? Growing the catalog also means
   any given card shows up less often, which cuts both ways: more variety per
   game, less chance to learn what a specific card does.

3. **Does the PROSPECT family belong?** The other five families each own a
   resource. PROSPECT is a grab bag — junk-hoarding, breadth, raw volume,
   cross-category majorities. It's where my weakest and strongest cards both
   live.

4. **Eight rounds — right length?** Total game is 60 cards. It might be one or
   two rounds too long; the last round can feel decided.

5. **Drafted vs dealt as the default.** Drafting is strictly fairer. But "I got a
   terrible hand" is also a story people enjoy, and the draft adds setup time.

6. **The Motherlode rounds** (last two draw 9 instead of 7, with 2 face-down
   instead of 1) exist to make endings dramatic. They do raise final scores. I
   don't know if they make endings *better* or just louder.

7. **Two players only.** Three-player I-cut-you-choose is a genuinely different
   problem — who chooses, in what order? I haven't touched it.

---

## Constraints I care about

- **No hidden state that a server would be needed to enforce.** Everything is
  either public or known to exactly one player by the rules of the game.
- **A round should be quick.** Split, choose, done.
- **The scoring should be readable at the table.** Someone should be able to
  eyeball their claim and roughly know where they stand.
- It should be **explainable in under two minutes**. I-cut-you-choose does a lot
  of work here because most people already understand it.

---

## One thing worth knowing about the theme

The mechanics and the setting line up better than I expected. Splitting a claim
and letting the other prospector pick is a real thing gold-rush miners did. Fool's
Gold being worthless-but-bulky matters mechanically (it pads piles and poisons
volume-scoring). Pack Mules being flexible-but-limited maps onto a real
constraint. I'd like to keep that alignment if the design changes.
