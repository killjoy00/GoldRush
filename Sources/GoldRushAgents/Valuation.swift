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
    /// The pool those hidden cards were drawn from, as far as this player knows.
    public let unseen: MiningCounts

    public init(view: PlayerView) {
        self.revealedHand = view.opponentRevealed
        self.knownCounts = view.opponentKnownCounts
        self.hiddenCount = view.opponentHiddenCount
        self.unseen = view.unseen
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
