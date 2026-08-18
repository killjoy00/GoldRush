import GoldRushEngine

/// Plays its own sheet and nothing else.
///
/// As splitter it divides the draw into two piles of equal value TO ITSELF,
/// which is the textbook I-cut-you-choose response when you have no model of
/// your opponent: whichever pile you lose, you keep the same value. As chooser
/// it takes the pile worth more to itself, pricing face-down cards at the
/// expectation of its own tracked residual deck.
///
/// Its blind spot is deliberate and is what the InferenceAgent exists to
/// exploit: piles that are equal to Greedy are frequently very unequal to an
/// opponent chasing a different family.
public struct GreedyAgent: GameAgent {
    public let name = "greedy"

    public init() {}

    public func selectReveal(
        _ view: PlayerView, count: Int, rng: inout SeededRNG
    ) -> [ScoringCardID] {
        // Reveal the cards whose scoring is least sensitive to what the opponent
        // does, keeping the opponent-relative ones secret where they cannot be
        // played around.
        let ranked = view.hand.sorted { lhs, rhs in
            let l = ScoringCardCatalog[lhs].effects.contains { $0.isOpponentRelative }
            let r = ScoringCardCatalog[rhs].effects.contains { $0.isOpponentRelative }
            if l != r { return !l && r }
            return lhs.index < rhs.index
        }
        return Array(ranked.prefix(count))
    }

    public func split(_ view: PlayerView, rng: inout SeededRNG) -> SplitDecision {
        let draw = view.currentDraw
        let types = typeLookup(view)
        let ids = draw.map(\.id)
        let current = view.collectionCounts
        let hand = view.hand

        func value(_ pile: [CardID]) -> Int {
            let additions = MiningCounts.counting(pile.compactMap { types[$0] })
            return Valuation.marginal(adding: additions, to: current, hand: hand)
        }

        var bestCut = (a: [ids[0]], b: Array(ids.dropFirst()))
        var bestGap = Int.max
        for cut in SplitEnumerator.cuts(of: ids) {
            let gap = abs(value(cut.a) - value(cut.b))
            if gap < bestGap {
                bestGap = gap
                bestCut = cut
            }
        }

        // Hide the cards that matter least, so the information the opponent
        // loses is information Greedy was not relying on either.
        let k = view.config.faceDownCount(round: view.round)
        let byValue = ids.sorted { lhs, rhs in
            let l = value([lhs]), r = value([rhs])
            if l != r { return l < r }
            return lhs.rawValue < rhs.rawValue
        }

        return SplitDecision(
            pileA: bestCut.a, pileB: bestCut.b, faceDown: Array(byValue.prefix(k))
        )
    }

    public func choose(_ view: PlayerView, rng: inout SeededRNG) -> PileID {
        guard let piles = view.piles else { return .a }
        let a = Valuation.expectedMarginal(
            cards: piles.a, current: view.collectionCounts, hand: view.hand, unseen: view.unseen
        )
        let b = Valuation.expectedMarginal(
            cards: piles.b, current: view.collectionCounts, hand: view.hand, unseen: view.unseen
        )
        if a == b { return .a }
        return a > b ? .a : .b
    }

    public func draftPick(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        // Value each candidate against a typical mid-game collection rather than
        // an empty one, since a card's worth is decided by what it eventually
        // pairs with, not by what is on the table during setup.
        let reference = typicalCollection()
        var best = legal[0]
        var bestValue = Int.min
        for candidate in legal {
            let value = Valuation.selfValue(counts: reference, hand: view.hand + [candidate])
            if value > bestValue {
                bestValue = value
                best = candidate
            }
        }
        return best
    }

    public func revealAdditional(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        let ranked = legal.sorted { lhs, rhs in
            let l = ScoringCardCatalog[lhs].effects.contains { $0.isOpponentRelative }
            let r = ScoringCardCatalog[rhs].effects.contains { $0.isOpponentRelative }
            if l != r { return !l && r }
            return lhs.index < rhs.index
        }
        return ranked[0]
    }

    /// Roughly what half the drawn deck looks like: the yardstick for judging a
    /// scoring card before any cards are on the table.
    func typicalCollection() -> MiningCounts {
        var counts = MiningCounts()
        for entry in MiningDeck.standardComposition {
            counts[entry.type] = entry.count * 30 / MiningDeck.standardSize
        }
        return counts
    }
}
