import GoldRushEngine

public struct SplitDecision: Sendable, Equatable {
    public let pileA: [CardID]
    public let pileB: [CardID]
    public let faceDown: [CardID]

    public init(pileA: [CardID], pileB: [CardID], faceDown: [CardID]) {
        self.pileA = pileA
        self.pileB = pileB
        self.faceDown = faceDown
    }
}

/// A strategy that plays Gold Rush.
///
/// Every method takes a `PlayerView`, never a `GameState`. That is the whole
/// guarantee against an agent cheating: there is no accessor on the view that
/// exposes a card the player has not observed, so an agent cannot consult
/// hidden information even by mistake.
///
/// The RNG is passed in rather than owned so a simulated game stays reproducible
/// from its seed regardless of which agents are playing.
public protocol GameAgent: Sendable {
    var name: String { get }

    func selectReveal(_ view: PlayerView, count: Int, rng: inout SeededRNG) -> [ScoringCardID]
    func split(_ view: PlayerView, rng: inout SeededRNG) -> SplitDecision
    func choose(_ view: PlayerView, rng: inout SeededRNG) -> PileID
    func draftPick(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID
    func draftDiscard(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID
    func revealAdditional(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID
}

extension GameAgent {
    /// Which of the drafted seven to throw away.
    ///
    /// Defaulted rather than required, because the answer that suits almost
    /// every agent is the same one: keep the best six. What goes is the card
    /// the rest of the hand misses least, which is not the same as the
    /// weakest card -- a rider that duplicates another rider's job is worth
    /// less beside it than alone, and this drops that one.
    ///
    /// It deliberately does NOT use `Valuation.selfValue`, which every other
    /// decision here uses. That function scores comparison riders as zero,
    /// because their value genuinely depends on a board the agent cannot see.
    /// Everywhere else that costs a little accuracy; here it was fatal.
    /// Scoring a comparison card at zero makes it the cheapest card in every
    /// hand it ever appears in, so it is discarded every single time -- and a
    /// 100k-game sweep confirmed exactly that, with P5 Highgrader and P8
    /// Grubstake Partner held in zero games despite P8 being one of the
    /// strongest cards in the deck when dealt. A card that can never be
    /// played is worse than a mistuned one.
    ///
    /// So comparison riders are resolved here against a symmetric opponent
    /// rather than skipped: the hand is scored twice, once against a
    /// reference collection one card per type leaner than this player's and
    /// once one card richer, and the two are averaged. That prices a
    /// "strictly more" card at about half its face value and a "close to
    /// level" card at about half of its, which is the right prior in a game
    /// where both players draft from the same pool and neither is favoured.
    public func draftDiscard(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        guard let first = legal.first else { return view.hand[0] }

        var reference = MiningCounts()
        for entry in MiningDeck.standardComposition {
            reference[entry.type] = entry.count * 30 / MiningDeck.standardSize
        }
        // One step either side of level, so every comparison rider resolves
        // true in one branch and false in the other.
        var leaner = reference
        var richer = reference
        for type in MiningType.allCases {
            leaner[type] = max(0, reference[type] - 1)
            richer[type] = reference[type] + 1
        }
        let behind = Scoring.bestAllocation(counts: leaner, hand: [], opponent: nil).board
        let ahead = Scoring.bestAllocation(counts: richer, hand: [], opponent: nil).board

        func keptValue(_ kept: [ScoringCardID]) -> Int {
            let winning = Scoring.bestAllocation(counts: reference, hand: kept, opponent: behind)
            let losing = Scoring.bestAllocation(counts: reference, hand: kept, opponent: ahead)
            return winning.total + losing.total
        }

        var best = first
        var bestKept = Int.min
        for candidate in legal {
            let value = keptValue(legal.filter { $0 != candidate })
            if value > bestKept {
                bestKept = value
                best = candidate
            }
        }
        return best
    }
}

// MARK: - Split enumeration

public enum SplitEnumerator {
    /// Every way to cut `cards` into two non-empty piles.
    ///
    /// Enumerated exhaustively rather than sampled: 7 cards give 63 distinct
    /// cuts and 9 give 255, which is small enough to search completely and
    /// removes any question of a heuristic missing the best division. Only
    /// masks containing the first card are generated, since a cut and its mirror
    /// are the same division.
    public static func cuts(of cards: [CardID]) -> [(a: [CardID], b: [CardID])] {
        let n = cards.count
        guard n >= 2 else { return [] }
        var out: [(a: [CardID], b: [CardID])] = []
        out.reserveCapacity(1 << (n - 1))
        let total = 1 << n
        for mask in 1..<total {
            guard mask & 1 == 1 else { continue }   // canonical: card 0 in pile A
            guard mask != total - 1 else { continue }  // pile B must be non-empty
            var a: [CardID] = []
            var b: [CardID] = []
            for i in 0..<n {
                if mask & (1 << i) != 0 { a.append(cards[i]) } else { b.append(cards[i]) }
            }
            out.append((a, b))
        }
        return out
    }

    /// Every way to choose `k` cards to turn face down.
    public static func faceDownChoices(from cards: [CardID], count k: Int) -> [[CardID]] {
        guard k > 0 else { return [[]] }
        guard k <= cards.count else { return [] }
        var out: [[CardID]] = []
        var current: [CardID] = []
        func recurse(_ start: Int) {
            if current.count == k { out.append(current); return }
            guard start < cards.count else { return }
            for i in start..<cards.count {
                current.append(cards[i])
                recurse(i + 1)
                current.removeLast()
            }
        }
        recurse(0)
        return out
    }
}

// MARK: - Shared helpers

extension GameAgent {
    /// Cards this agent can see in the draw it is splitting. The splitter drew
    /// them privately, so all are known.
    func drawTypes(_ view: PlayerView) -> [(id: CardID, type: MiningType)] {
        view.currentDraw.compactMap { card in
            guard let type = card.type else { return nil }
            return (card.id, type)
        }
    }

    func typeLookup(_ view: PlayerView) -> [CardID: MiningType] {
        var map: [CardID: MiningType] = [:]
        for card in view.currentDraw {
            if let type = card.type { map[card.id] = type }
        }
        return map
    }
}
