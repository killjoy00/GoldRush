import GoldRushEngine

/// Counts cards. Reads nothing.
///
/// The deliberately stupid baseline: it splits the draw into two piles of equal
/// SIZE and always takes whichever pile has more cards, without ever consulting
/// a scoring card. "More stuff is better" is the first heuristic a new player
/// reaches for, and it is a real strategy -- volume genuinely correlates with
/// points -- so it is the honest bar every smarter agent has to clear.
///
/// It exists to be beaten. If a sophisticated agent cannot beat this by a wide
/// margin then that agent is not doing anything, and the measurement is the
/// only way to find out.
public struct NaiveAgent: GameAgent {
    public let name = "naive"

    public init() {}

    public func selectReveal(
        _ view: PlayerView, count: Int, rng: inout SeededRNG
    ) -> [ScoringCardID] {
        Array(view.hand.prefix(count))
    }

    public func split(_ view: PlayerView, rng: inout SeededRNG) -> SplitDecision {
        // Deal alternately into two piles: even by count, blind to content.
        let ids = view.currentDraw.map(\.id)
        var a: [CardID] = []
        var b: [CardID] = []
        for (index, id) in ids.enumerated() {
            if index.isMultiple(of: 2) { a.append(id) } else { b.append(id) }
        }
        let k = view.config.faceDownCount(round: view.round)
        return SplitDecision(pileA: a, pileB: b, faceDown: Array(ids.prefix(k)))
    }

    public func choose(_ view: PlayerView, rng: inout SeededRNG) -> PileID {
        guard let piles = view.piles else { return .a }
        if piles.a.count == piles.b.count { return .a }
        return piles.a.count > piles.b.count ? .a : .b
    }

    public func draftPick(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        legal[0]
    }

    public func revealAdditional(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        legal[0]
    }
}
