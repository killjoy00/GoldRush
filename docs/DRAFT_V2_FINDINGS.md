# Eight-card draft validation

Validated September 5, 2026 after the scoring-card draft was changed to:

- open 8;
- keep 1, burn 1 face up, pass 6;
- keep/pass through packs of 6, 5, 4 and 3;
- from the final 2, keep 1 and burn 1 face up;
- finish with 6 scoring cards per player.

## Simulation

The final targeted balance run used 5,000 games, the full inference agent in both seats, Together mode, and the new drafted scoring-card setup:

```bash
swift run -c release GoldRushSim balance \
  --games 5000 \
  --seed 20260905 \
  --threads 4 \
  --agent inference \
  --scoring-draft \
  --simultaneous-split
```

## Draft valuation fixes

Two setup-only AI problems surfaced while validating the new draft.

### Opponent-relative scoring cards

The previous draft picker evaluated cards without a useful opponent board. That made comparison riders artificially weak during the draft itself.

The new draft prior scores each candidate against symmetric opponent boards one card per type ahead and behind. The targeted comparison cards now land near the Prospect-family mean instead of being systematically discarded:

| Card | Contribution EV | Win rate when held | Family mean |
| --- | ---: | ---: | ---: |
| P5 Highgrader | 18.04 | 46.8% | 17.44 |
| P8 Grubstake Partner | 17.97 | 50.6% | 17.44 |

The important result is not that either comparison card should always be strong. It is that their draft valuation is now non-zero and competitive with the rest of their family.

### Nonlinear / build-around scoring cards

The old "typical 30-card collection" was built by independently flooring each mining type's expected count. Those floors summed to only 27 cards. Even after correcting that arithmetic with a full-size reference ensemble, a static average board still undervalued cards whose purpose is to make a player chase one more copy of a mining type.

Draft valuation now uses six exactly-30-card reference boards whose average exactly matches the standard deck's expected 30-card composition, then gives the scoring hand one card of strategic agency: it also asks which single additional mining type would help that hand most.

That generic change recovered V7 Crystal Cache from never being held in the first rerun to normal play in the final run:

| Card | Contribution EV | Win rate when held | Family mean |
| --- | ---: | ---: | ---: |
| V7 Crystal Cache | 19.65 | 58.1% | 21.03 |

No card-specific exception was added for Crystal Cache.

## Remaining balance signals

The final run still flags several cards as statistical outliers relative to their family: S6 Grubstake, D7 Prospector's Eye, V4 Prism, V6 Cut and Polish, and P1 Pyrite Hoarder. Those are useful future balance-review candidates, but they are distinct from the draft-selection bugs fixed here: all are being selected and scored by the new draft AI.

This run is the first balance measurement in `docs/` that applies to the eight-card draft. Older draft findings in `SIM_FINDINGS.md` describe earlier rules unless explicitly noted otherwise.
