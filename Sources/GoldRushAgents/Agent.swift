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
    /// Six equally weighted, exactly-30-card boards used to judge a scoring
    /// hand before the mining game has begun.
    ///
    /// The old draft heuristic independently floored `deckCount * 30 / 72` for
    /// every mining type. Those floors add to only 27 cards, not 30. That is a
    /// meaningful bias for nonlinear cards: Quartz's expectation is 3 1/3, so
    /// Crystal Cache was always judged at exactly 3 Quartz and its "beyond the
    /// third" rider never fired. In an eight-card draft the bot then burned it
    /// every time it appeared.
    ///
    /// These six boards encode the fractional expectation without floating point:
    /// their per-type average is exactly the standard deck's 30-card expectation,
    /// and every individual board contains exactly 30 cards. Repeated boards are
    /// intentional probability weight, not a typo.
    public func draftReferenceProfiles() -> [MiningCounts] {
        var floor = MiningCounts()
        for entry in MiningDeck.standardComposition {
            floor[entry.type] = entry.count * 30 / MiningDeck.standardSize
        }

        // The floor board totals 27. Across six samples, the 18 residual slots
        // reproduce the exact fractional remainders:
        // Nugget 5/6; Pyrite/Ore/Gravel 1/6; Shovel/Pan/Quartz 2/6; Mule 4/6.
        let residuals: [[MiningType]] = [
            [.goldNugget, .packMule, .shovel],
            [.goldNugget, .packMule, .pan],
            [.goldNugget, .packMule, .quartz],
            [.goldNugget, .packMule, .shovel],
            [.goldNugget, .pan, .quartz],
            [.foolsGold, .goldOre, .gravel],
        ]

        return residuals.map { extras in
            var counts = floor
            for type in extras { counts[type] += 1 }
            return counts
        }
    }

    /// Pre-game hand value, including opponent-relative, nonlinear and
    /// build-around effects.
    ///
    /// Comparison riders need an opponent board. During the draft neither side
    /// has one yet, so each 30-card reference profile is scored against two
    /// symmetric priors: an opponent one card per type behind and one card per
    /// type ahead. Adding both outcomes prices "strictly more" and "stay close"
    /// effects around their neutral pre-game probability instead of deleting
    /// them from the draft.
    ///
    /// A second term gives the hand one card of strategic agency: after scoring
    /// the expected 30-card board, ask which single mining type would help this
    /// hand most if the player deliberately chased one extra copy. This matters
    /// for build-around thresholds and convex cards. It is intentionally only
    /// one card, so it captures the direction a scoring hand will steer play
    /// without pretending the player can rewrite the whole deck distribution.
    public func draftPriorValue(hand: [ScoringCardID]) -> Int {
        func value(
            counts: MiningCounts,
            hand: [ScoringCardID],
            opponentBehind: Board,
            opponentAhead: Board
        ) -> Int {
            Scoring.bestAllocation(counts: counts, hand: hand, opponent: opponentBehind).total
                + Scoring.bestAllocation(counts: counts, hand: hand, opponent: opponentAhead).total
        }

        var total = 0
        for reference in draftReferenceProfiles() {
            var leaner = reference
            var richer = reference
            for type in MiningType.allCases {
                leaner[type] = max(0, reference[type] - 1)
                richer[type] = reference[type] + 1
            }
            let behind = Scoring.bestAllocation(counts: leaner, hand: [], opponent: nil).board
            let ahead = Scoring.bestAllocation(counts: richer, hand: [], opponent: nil).board

            let baseline = value(
                counts: reference, hand: hand,
                opponentBehind: behind, opponentAhead: ahead
            )
            var focused = baseline
            for type in MiningType.allCases {
                var oneMore = reference
                oneMore[type] += 1
                focused = max(
                    focused,
                    value(
                        counts: oneMore, hand: hand,
                        opponentBehind: behind, opponentAhead: ahead
                    )
                )
            }
            total += baseline + focused
        }
        return total
    }

    /// Which of a legacy seven-card hand to throw away. New eight-card drafts
    /// discard from the pack at the opening and closing decisions instead, but
    /// this remains for saved matches that were already in `.draftDiscard`.
    public func draftDiscard(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        guard let first = legal.first else { return view.hand[0] }

        var best = first
        var bestKept = Int.min
        for candidate in legal {
            let value = draftPriorValue(hand: legal.filter { $0 != candidate })
            if value > bestKept {
                bestKept = value
                best = candidate
            }
        }
        return best
    }

    /// Converts an agent's existing card-ranking strategy into the complete
    /// eight-card draft action. Keeping this here makes the simulator, solo AI
    /// and any future bot use exactly the same draft protocol.
    public func draftAction(_ view: PlayerView, rng: inout SeededRNG) -> Action? {
        let pack = view.draftPool
        guard !pack.isEmpty else { return nil }

        if pack.count == GameConfig.draftOpeningPackSize {
            let keep = draftPick(view, legal: pack, rng: &rng)
            let remaining = pack.filter { $0 != keep }
            guard !remaining.isEmpty else { return nil }
            // The second-best card for our own hand is a sensible denial burn:
            // it is the card we least want to hand to the opponent after taking
            // our first choice. Both decisions still use only visible draft data.
            let discard = draftPick(view, legal: remaining, rng: &rng)
            return .draftOpen(keep: keep, discard: discard)
        }

        if pack.count == 2 {
            let keep = draftPick(view, legal: pack, rng: &rng)
            guard let discard = pack.first(where: { $0 != keep }) else { return nil }
            return .draftClose(keep: keep, discard: discard)
        }

        let keep = draftPick(view, legal: pack, rng: &rng)
        return .draftPick(keep)
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
