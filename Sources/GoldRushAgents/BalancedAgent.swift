import GoldRushEngine

/// Maximin over its own valuation, restricted to cuts of near-equal size.
///
/// An experiment with a specific hypothesis behind it. Measurement said the
/// existing split objectives both lose to dealing the draw alternately, and
/// the obvious difference is that alternate dealing is always size-balanced
/// while a value-balanced cut can be six cards against one. A chooser that
/// weighs volume at all -- and volume is genuinely worth something, for
/// per-card scoring, for sets, and for the Gold Nugget tiebreak -- takes the
/// big pile every time, so the splitter systematically keeps the small one.
///
/// Two changes from `GreedyAgent`, either of which could be carrying the
/// result, which is why `sizeSlack` is adjustable rather than baked in:
///   1. maximise min(A, B) rather than minimise |A - B|. Equalising is happy
///      with two piles that are equally bad, and a cut can destroy value
///      rather than merely move it -- concentrate the ore in one pile and the
///      shovels in the other and every set dies.
///   2. only consider cuts whose sizes differ by at most `sizeSlack`.
public struct BalancedAgent: GameAgent {
    public let name: String
    /// Largest allowed difference in card count between the two piles.
    /// A large value disables the restriction, leaving pure maximin.
    public let sizeSlack: Int

    public init(sizeSlack: Int = 1) {
        self.sizeSlack = sizeSlack
        self.name = "balanced-\(sizeSlack)"
    }

    public func split(_ view: PlayerView, rng: inout SeededRNG) -> SplitDecision {
        let types = typeLookup(view)
        let ids = view.currentDraw.map(\.id)
        let current = view.collectionCounts
        let hand = view.hand

        func value(_ pile: [CardID]) -> Int {
            Valuation.marginal(
                adding: MiningCounts.counting(pile.compactMap { types[$0] }),
                to: current, hand: hand
            )
        }

        var bestCut = (a: [ids[0]], b: Array(ids.dropFirst()))
        var bestFloor = Int.min
        for cut in SplitEnumerator.cuts(of: ids) {
            guard abs(cut.a.count - cut.b.count) <= sizeSlack else { continue }
            let floor = min(value(cut.a), value(cut.b))
            if floor > bestFloor {
                bestFloor = floor
                bestCut = cut
            }
        }

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

    // Everything else is Greedy's, so a comparison isolates the split.
    private var fallback: GreedyAgent { GreedyAgent() }

    public func selectReveal(_ view: PlayerView, count: Int, rng: inout SeededRNG) -> [ScoringCardID] {
        fallback.selectReveal(view, count: count, rng: &rng)
    }
    public func choose(_ view: PlayerView, rng: inout SeededRNG) -> PileID {
        fallback.choose(view, rng: &rng)
    }
    public func draftPick(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID {
        fallback.draftPick(view, legal: legal, rng: &rng)
    }
    public func revealAdditional(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID {
        fallback.revealAdditional(view, legal: legal, rng: &rng)
    }
}
