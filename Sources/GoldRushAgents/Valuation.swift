import GoldRushEngine

/// How an agent puts a number on cards it might acquire.
///
/// Everything here works from a `PlayerView`, so an agent's estimate of the
/// opponent is genuinely an inference from public information rather than a
/// peek at the truth.
public enum Valuation {

    /// What a collection of counts is worth to a hand, ignoring the opponent.
    /// Comparison riders are excluded because their value depends on a board the
    /// agent cannot see; `Estimator` handles those separately.
    public static func selfValue(counts: MiningCounts, hand: [ScoringCardID]) -> Int {
        Scoring.bestAllocation(counts: counts, hand: hand, opponent: nil).total
    }

    /// The gain from adding `additions` to what is already held.
    ///
    /// Marginal rather than absolute because almost every decision in this game
    /// is "is this pile worth more to me than that one", and set-completion and
    /// threshold effects make that strongly non-linear -- a Shovel is worth a
    /// great deal more when you are holding unmatched Ore.
    public static func marginal(
        adding additions: MiningCounts,
        to current: MiningCounts,
        hand: [ScoringCardID]
    ) -> Int {
        selfValue(counts: current + additions, hand: hand)
            - selfValue(counts: current, hand: hand)
    }

    public static func counts(of types: [MiningType]) -> MiningCounts {
        MiningCounts.counting(types)
    }

    /// Marginal value of a set of visible cards, where a hidden card is worth
    /// its expectation over the player's own unseen pool.
    ///
    /// This is where the residual tracker earns its keep: a player who has seen
    /// more of the deck holds a sharper estimate of what a face-down card is
    /// worth, which is precisely the edge the hidden-card mechanic is meant to
    /// create.
    public static func expectedMarginal(
        cards: [VisibleCard],
        current: MiningCounts,
        hand: [ScoringCardID],
        unseen: MiningCounts
    ) -> Double {
        var known = MiningCounts()
        var hiddenCount = 0
        for card in cards {
            if let type = card.type { known[type] += 1 } else { hiddenCount += 1 }
        }

        let base = Double(marginal(adding: known, to: current, hand: hand))
        guard hiddenCount > 0 else { return base }

        let pool = unseen.total
        guard pool > 0 else { return base }

        // Expectation over one unseen card, then scaled. Treating the hidden
        // cards independently slightly overstates variance for multi-card cases,
        // but it is unbiased in the mean and avoids a combinatorial blow-up.
        let after = current + known
        var expectedPerCard = 0.0
        for type in MiningType.allCases where unseen[type] > 0 {
            var one = MiningCounts()
            one[type] = 1
            let gain = marginal(adding: one, to: after, hand: hand)
            expectedPerCard += Double(gain) * Double(unseen[type]) / Double(pool)
        }
        return base + expectedPerCard * Double(hiddenCount)
    }
}

/// A model of what the opponent is trying to collect.
///
/// Built from their three public scoring cards plus whatever of their collection
/// this player has observed. The three secret cards are unknowable, so the model
/// is deliberately partial -- an InferenceAgent that assumed otherwise would be
/// cheating, not inferring.
public struct OpponentModel: Sendable {
    public let revealedHand: [ScoringCardID]
    public let knownCounts: MiningCounts
    /// Cards in their collection whose identity was never observed.
    public let hiddenCount: Int
    /// The pool this player believes the OPPONENT is still uncertain about --
    /// not this player's own uncertainty. See `opponentUnseen` below.
    public let unseen: MiningCounts

    public init(view: PlayerView) {
        self.revealedHand = view.opponentRevealed
        self.knownCounts = view.opponentKnownCounts
        self.hiddenCount = view.opponentHiddenCount
        self.unseen = Self.opponentUnseen(view: view)
    }

    /// Ablation only: reproduces the model's PRE-`splitLog` behaviour, where
    /// the opponent's uncertainty was silently assumed to equal this player's
    /// own. Exists so the fix in `opponentUnseen` below can be measured
    /// against its own prior behaviour (docs/SIM_FINDINGS.md §12) rather than
    /// merely asserted -- never selected by the shipping app.
    init(naiveFrom view: PlayerView) {
        self.revealedHand = view.opponentRevealed
        self.knownCounts = view.opponentKnownCounts
        self.hiddenCount = view.opponentHiddenCount
        self.unseen = view.unseen
    }

    /// What the OPPONENT has not seen, estimated from public information only
    /// -- never from anything only this player has observed.
    ///
    /// `view.unseen` is this player's own uncertainty. Reusing it for the
    /// opponent silently assumes both players have watched the same amount of
    /// the deck go by, which is true turn one and false almost everywhere
    /// after: every round a player splits, they see their WHOLE draw, not
    /// just whatever became public. A splitter's uncertainty drops by the
    /// full draw size; a chooser's drops by less. Conflating the two is
    /// exactly the gap `docs/SIM_FINDINGS.md` §3 names -- "both agents price
    /// an unknown card identically" -- because there was previously no way for
    /// an agent to tell the two apart at all.
    ///
    /// `view.splitLog` carries every past split's draw size, buried count, and
    /// which pile was taken, without ever carrying a card identity, so the
    /// COUNT of what the opponent has personally drawn through is computable
    /// exactly. Which specific cards they saw when THEY split is not
    /// recoverable from public information -- that is the whole point of the
    /// mechanic -- so the pool's composition is estimated by assuming their
    /// extra sightings looked like an average draw from this player's own
    /// unseen pool, apportioned by largest remainder so the estimate's total
    /// matches the count exactly rather than drifting from independent
    /// per-type rounding.
    static func opponentUnseen(view: PlayerView) -> MiningCounts {
        let opponent = view.player.opponent
        var opponentSeen = 0
        for record in view.splitLog {
            if record.splitter == opponent {
                // They drew it, so they saw all of it -- including whatever
                // they went on to bury.
                opponentSeen += record.drawCount
            } else {
                // This player split; the opponent chose. Face-up cards are
                // seen by anyone watching, face-down ones only once claimed --
                // and, if hidden cards are not persistent, eventually anyway.
                opponentSeen += (record.drawCount - record.faceDownCount) + record.faceDownInTaken
                if !view.config.persistentHiddenCards {
                    opponentSeen += record.faceDownCount - record.faceDownInTaken
                }
            }
        }
        // When both players split every round, the opponent's current-round
        // draw is dealt (and privately observed by them) before either split
        // is submitted -- `splitLog` has no entry for it yet, since it only
        // grows once a split resolves, but the round's draw size is public,
        // so this is not a peek at anything secret.
        if view.config.splitters(round: view.round).contains(opponent) {
            opponentSeen += view.config.drawCount(round: view.round)
        }

        let myUnseen = view.unseen
        let myUnseenTotal = myUnseen.total
        let opponentUnseenTotal = max(0, view.config.deckSize - opponentSeen)
        // The opponent has not necessarily seen MORE than this player -- mid-
        // game, before either has split as often as the other, it can go
        // either way. Scaling `myUnseen` by the ratio handles both directions
        // the same way; only the degenerate all-seen case needs a guard.
        guard myUnseenTotal > 0 else { return myUnseen }

        // Largest-remainder apportionment: floor each type's proportional
        // share, then hand the shortfall -- always fewer than the eight
        // types, since each floor loses less than one whole share -- to
        // whichever types lost the most to flooring. Ties break on
        // `MiningType`'s fixed declaration order rather than sort stability,
        // so the result is reproducible rather than incidentally so.
        var estimate = MiningCounts()
        var remainders: [(index: Int, type: MiningType, remainder: Int)] = []
        var allocated = 0
        for (index, type) in MiningType.allCases.enumerated() {
            let scaled = myUnseen[type] * opponentUnseenTotal
            estimate[type] = scaled / myUnseenTotal
            allocated += estimate[type]
            remainders.append((index, type, scaled % myUnseenTotal))
        }
        let shortfall = opponentUnseenTotal - allocated
        let ranked = remainders.sorted {
            $0.remainder != $1.remainder ? $0.remainder > $1.remainder : $0.index < $1.index
        }
        for entry in ranked.prefix(shortfall) {
            estimate[entry.type] += 1
        }
        return estimate
    }

    /// Their best guess at the opponent's collection, spreading unidentified
    /// cards across the unseen pool in proportion rather than pretending they
    /// do not exist.
    public var estimatedCounts: MiningCounts {
        guard hiddenCount > 0, unseen.total > 0 else { return knownCounts }
        var estimate = knownCounts
        // Integer apportionment keeps this deterministic; the residue is dropped
        // rather than rounded up, which biases slightly low but never oscillates.
        for type in MiningType.allCases {
            estimate[type] += (unseen[type] * hiddenCount) / unseen.total
        }
        return estimate
    }

    /// What a pile is likely worth to them. Uses only their public cards, since
    /// that is all this player can legitimately reason about.
    public func value(adding additions: MiningCounts) -> Int {
        guard !revealedHand.isEmpty else { return additions.total }
        let base = estimatedCounts
        return Valuation.selfValue(counts: base + additions, hand: revealedHand)
            - Valuation.selfValue(counts: base, hand: revealedHand)
    }
}
