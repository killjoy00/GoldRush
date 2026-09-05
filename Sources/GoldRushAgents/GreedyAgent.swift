import GoldRushEngine

/// Plays its own sheet and nothing else.
///
/// As splitter it maximises the worse of the two piles by its own valuation,
/// among cuts of near-equal size -- the textbook I-cut-you-choose response
/// when you have no model of your opponent, with the sharp edge that the two
/// piles must also be comparably large. As chooser
/// it takes the pile worth more to itself, pricing face-down cards at the
/// expectation of its own tracked residual deck.
///
/// Its blind spot is deliberate and is what the InferenceAgent exists to
/// exploit: piles that are equal to Greedy are frequently very unequal to an
/// opponent chasing a different family.
public struct GreedyAgent: GameAgent {
    public let name = "greedy"

    /// Largest difference in card count between the two piles a split may
    /// offer. One keeps a 7-card draw at 4/3 and a 9-card draw at 5/4.
    static let sizeSlack = 1

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

        // Maximise the worse pile, over cuts of near-equal SIZE.
        //
        // Both halves of that were measured. Against a chooser that simply
        // takes the bigger pile, the original objective -- minimise the value
        // gap -- won 44.0%, and swapping it for maximin alone moved it only to
        // 45.0%. Adding the size restriction took it to 61.7%. Size balance was
        // carrying almost all of it.
        //
        // The reason is that a value-balanced cut need not be a size-balanced
        // one: "one Gold Nugget" and "six pieces of junk" can price the same to
        // this agent, and it was happy to offer that. Any chooser who weighs
        // volume at all -- and volume is genuinely worth something, for
        // per-card scoring, for sets, and for the Gold Nugget tiebreak -- takes
        // the big pile every time, so the splitter kept the small one all game.
        //
        // Maximin stays because it is strictly the better objective: equalising
        // is satisfied by two piles that are equally BAD, and a cut can destroy
        // value rather than merely move it. Concentrate the ore in one pile and
        // the shovels in the other and every set dies, evenly.
        var bestCut = (a: [ids[0]], b: Array(ids.dropFirst()))
        var bestFloor = Int.min
        for cut in SplitEnumerator.cuts(of: ids) {
            guard abs(cut.a.count - cut.b.count) <= GreedyAgent.sizeSlack else { continue }
            let floor = min(value(cut.a), value(cut.b))
            if floor > bestFloor {
                bestFloor = floor
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
        // The shared draft prior evaluates a six-board ensemble of full 30-card
        // collections and symmetric opponent boards. That keeps comparison and
        // nonlinear cards in the ranking instead of evaluating them on an
        // undersized single average board.
        var best = legal[0]
        var bestValue = Int.min
        for candidate in legal {
            let value = draftPriorValue(hand: view.hand + [candidate])
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
}
