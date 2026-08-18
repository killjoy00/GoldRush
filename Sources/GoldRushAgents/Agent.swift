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
    func revealAdditional(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID
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
