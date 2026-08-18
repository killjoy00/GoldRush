import GoldRushEngine

/// Uniformly random among legal choices. The baseline every other agent must
/// beat; also the fastest way to shake out illegal-move bugs in the engine.
public struct RandomAgent: GameAgent {
    public let name = "random"

    public init() {}

    public func selectReveal(
        _ view: PlayerView, count: Int, rng: inout SeededRNG
    ) -> [ScoringCardID] {
        var hand = view.hand
        rng.shuffle(&hand)
        return Array(hand.prefix(count))
    }

    public func split(_ view: PlayerView, rng: inout SeededRNG) -> SplitDecision {
        let draw = view.currentDraw.map(\.id)
        var shuffled = draw
        rng.shuffle(&shuffled)
        let cut = 1 + rng.next(upperBound: max(1, shuffled.count - 1))

        var faceDownPool = draw
        rng.shuffle(&faceDownPool)
        let k = view.config.faceDownCount(round: view.round)

        return SplitDecision(
            pileA: Array(shuffled[..<cut]),
            pileB: Array(shuffled[cut...]),
            faceDown: Array(faceDownPool.prefix(k))
        )
    }

    public func choose(_ view: PlayerView, rng: inout SeededRNG) -> PileID {
        rng.next(upperBound: 2) == 0 ? .a : .b
    }

    public func draftPick(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        legal[rng.next(upperBound: legal.count)]
    }

    public func revealAdditional(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        legal[rng.next(upperBound: legal.count)]
    }
}
