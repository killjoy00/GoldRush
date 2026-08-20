/// How the Pack Mules were spent.
///
/// Each mule may fill the Shovel slot of ONE Ore+Shovel set, OR the Pan slot of
/// ONE Gravel+Pan set, or nothing at all. Mules are interchangeable, so an
/// allocation is fully described by two integers rather than a per-mule
/// assignment -- which is what keeps the optimiser's search space at 15
/// candidates for 4 mules instead of 3^4.
public struct MuleAllocation: Sendable, Equatable, Hashable, Codable {
    public let toShovel: Int
    public let toPan: Int

    public init(toShovel: Int, toPan: Int) {
        self.toShovel = toShovel
        self.toPan = toPan
    }

    public static let none = MuleAllocation(toShovel: 0, toPan: 0)

    /// Every legal way to spend `mules`. Enumerated in a fixed order so ties
    /// resolve identically on every platform.
    public static func candidates(mules: Int) -> [MuleAllocation] {
        guard mules > 0 else { return [.none] }
        var out: [MuleAllocation] = []
        out.reserveCapacity((mules + 1) * (mules + 2) / 2)
        for a in 0...mules {
            for b in 0...(mules - a) {
                out.append(MuleAllocation(toShovel: a, toPan: b))
            }
        }
        return out
    }
}

/// A collection resolved into the quantities scoring actually reads.
///
/// Derived once per candidate allocation, then handed to every effect. Keeping
/// this separate from `MiningCounts` means an effect never has to know how sets
/// were formed.
public struct Board: Sendable, Equatable, Hashable {
    public let counts: MiningCounts
    public let allocation: MuleAllocation
    public let oreShovelSets: Int
    public let gravelPanSets: Int
    public let unmatched: MiningCounts

    public init(counts: MiningCounts, allocation: MuleAllocation) {
        self.counts = counts
        self.allocation = allocation

        // A mule only pays off if there is an unmatched resource for it to serve.
        // Over-assignment is harmless because the optimiser searches every split.
        let oreSets = min(counts.goldOre, counts.shovel + allocation.toShovel)
        let gravelSets = min(counts.gravel, counts.pan + allocation.toPan)
        self.oreShovelSets = oreSets
        self.gravelPanSets = gravelSets

        var left = MiningCounts()
        left.goldOre = counts.goldOre - oreSets
        left.gravel = counts.gravel - gravelSets
        // Literal tools left over once sets are formed. Mules are spent first,
        // so a leftover Shovel means the Shovel supply genuinely exceeded the ore.
        left.shovel = max(0, counts.shovel - max(0, oreSets - allocation.toShovel))
        left.pan = max(0, counts.pan - max(0, gravelSets - allocation.toPan))
        self.unmatched = left
    }

    public func sets(_ kind: SetKind) -> Int {
        switch kind {
        case .oreShovel: oreShovelSets
        case .gravelPan: gravelPanSets
        }
    }

    /// Tool = Shovel | Pan | PackMule, whether or not consumed by a set.
    public var toolCount: Int { counts.toolCount }

    public func count(_ countable: Countable) -> Int {
        switch countable {
        case .type(let type): counts[type]
        case .set(let kind): sets(kind)
        case .tools: toolCount
        case .totalMiningCards: counts.total
        }
    }
}

/// What one scoring card paid, and why.
public struct CardScore: Sendable, Equatable, Hashable, Identifiable {
    public let id: ScoringCardID
    public let points: Int
    /// Per-effect breakdown, in catalog order. Drives the end-of-game itemisation.
    public let components: [Int]

    public init(id: ScoringCardID, points: Int, components: [Int]) {
        self.id = id
        self.points = points
        self.components = components
    }
}

/// A fully resolved score for one player.
public struct Scorecard: Sendable, Equatable, Hashable {
    public let total: Int
    public let allocation: MuleAllocation
    public let board: Board
    public let cards: [CardScore]

    public init(total: Int, allocation: MuleAllocation, board: Board, cards: [CardScore]) {
        self.total = total
        self.allocation = allocation
        self.board = board
        self.cards = cards
    }
}

public enum Scoring {
    // MARK: - Effect evaluation

    /// Scores one effect against a resolved board.
    ///
    /// `opponent` supplies the counts that comparison riders read. It is always
    /// the opponent's own best arrangement -- see `opponentReference`.
    public static func evaluate(
        _ effect: ScoringEffect,
        board: Board,
        opponent: Board?
    ) -> Int {
        switch effect {
        case .perType(let type, let points):
            return board.counts[type] * points

        case .perTypeBeyond(let type, let threshold, let points):
            return max(0, board.counts[type] - threshold) * points

        case .perTypeCapped(let type, let points, let maxCount):
            return min(board.counts[type], maxCount) * points

        case .perSet(let kind, let points):
            return board.sets(kind) * points

        case .perUnmatched(let type, let points):
            return board.unmatched[type] * points

        case .perTool(let points):
            return board.toolCount * points

        case .perToolCapped(let points, let maxCount):
            return min(board.toolCount, maxCount) * points

        case .perToolExcluding(let excluded, let points):
            return (board.toolCount - board.counts[excluded]) * points

        case .perNthScaling(let type, let schedule, let repeatLast):
            guard !schedule.isEmpty else { return 0 }
            var sum = 0
            let held = board.counts[type]
            for n in 1...max(held, 1) where n <= held {
                if n <= schedule.count {
                    sum += schedule[n - 1]
                } else if repeatLast {
                    sum += schedule[schedule.count - 1]
                }
            }
            return sum

        case .perNthLinear(let type, let multiplier):
            let held = board.counts[type]
            // multiplier * (1 + 2 + ... + held)
            return multiplier * (held * (held + 1) / 2)

        case .perTotalMiningCards(let points):
            return board.counts.total * points

        case .typesHeldAtLeast(let types, let count, let points):
            var sum = 0
            for type in types where board.counts[type] >= count { sum += points }
            return sum

        case .bonusIfAtLeast(let countable, let count, let points):
            return board.count(countable) >= count ? points : 0

        case .bonusIfAtMost(let countable, let count, let points):
            return board.count(countable) <= count ? points : 0

        case .bonusIfStrictlyMore(let countable, let points):
            guard let opponent else { return 0 }
            return board.count(countable) > opponent.count(countable) ? points : 0

        case .bonusIfExceeds(let type, let other, let margin, let points):
            return board.counts[type] - board.counts[other] >= margin ? points : 0

        case .bonusPerTypeStrictlyMore(let types, let points):
            guard let opponent else { return 0 }
            var sum = 0
            for type in types where board.counts[type] > opponent.counts[type] { sum += points }
            return sum

        case .bonusPerTypeWithinMargin(let types, let margin, let points):
            guard let opponent else { return 0 }
            var sum = 0
            for type in types where abs(board.counts[type] - opponent.counts[type]) <= margin { sum += points }
            return sum

        case .tieredByCount(let countable, let tiers):
            let n = board.count(countable)
            for tier in tiers where n <= tier.maxCount { return tier.points }
            return 0
        }
    }

    // MARK: - Scoring a hand
    //
    // Each function here comes in two forms: one over `[ScoringCard]` (the real
    // math, working on card data), and a thin `[ScoringCardID]` wrapper that
    // looks the ids up in the live `ScoringCardCatalog`. Everyday callers --
    // the engine, the agents, the simulator -- want the id form, since a hand is
    // just ids. But it means those calls are only as stable as the mutable
    // catalog: retune a card and every caller's result shifts with it.
    //
    // Fixture 1 is explicitly NOT supposed to shift. It hand-verifies the
    // optimiser itself, and the catalog is expected to be re-tuned by the
    // simulator over the life of this project -- so the fixture holds a frozen
    // snapshot of card data and calls the `[ScoringCard]` form directly,
    // bypassing the catalog entirely. A retune can change what P6 pays without
    // ever touching what "97" means.

    static func scoreCards(
        _ cards: [ScoringCard],
        board: Board,
        opponent: Board?
    ) -> (total: Int, cards: [CardScore]) {
        var total = 0
        var details: [CardScore] = []
        details.reserveCapacity(cards.count)
        for card in cards {
            var points = 0
            var components: [Int] = []
            components.reserveCapacity(card.effects.count)
            for effect in card.effects {
                let value = evaluate(effect, board: board, opponent: opponent)
                components.append(value)
                points += value
            }
            total += points
            details.append(CardScore(id: card.id, points: points, components: components))
        }
        return (total, details)
    }

    static func scoreCards(
        _ hand: [ScoringCardID],
        board: Board,
        opponent: Board?
    ) -> (total: Int, cards: [CardScore]) {
        scoreCards(hand.map { ScoringCardCatalog[$0] }, board: board, opponent: opponent)
    }

    /// Total only. Hot path for the optimiser and the agents.
    static func total(
        _ cards: [ScoringCard],
        board: Board,
        opponent: Board?
    ) -> Int {
        var total = 0
        for card in cards {
            for effect in card.effects {
                total += evaluate(effect, board: board, opponent: opponent)
            }
        }
        return total
    }

    static func total(
        _ hand: [ScoringCardID],
        board: Board,
        opponent: Board?
    ) -> Int {
        total(hand.map { ScoringCardCatalog[$0] }, board: board, opponent: opponent)
    }

    // MARK: - The PackMule optimiser

    /// Chooses the mule allocation that maximises this player's total.
    ///
    /// Explicit brute force over every candidate rather than a greedy rule: the
    /// catalog is expected to change, and a heuristic that happens to be right
    /// for today's 36 cards could silently become wrong after a retune. At 4
    /// mules this is 15 candidates, so exhaustive search costs nothing.
    ///
    /// Ties go to the earliest candidate in `MuleAllocation.candidates`, which is
    /// a fixed order -- so the result is deterministic, not merely optimal.
    public static func bestAllocation(
        counts: MiningCounts,
        cards: [ScoringCard],
        opponent: Board?
    ) -> (allocation: MuleAllocation, board: Board, total: Int) {
        var bestAllocation = MuleAllocation.none
        var bestBoard = Board(counts: counts, allocation: .none)
        var bestTotal = Int.min

        for candidate in MuleAllocation.candidates(mules: counts.packMule) {
            let board = Board(counts: counts, allocation: candidate)
            let value = total(cards, board: board, opponent: opponent)
            if value > bestTotal {
                bestTotal = value
                bestAllocation = candidate
                bestBoard = board
            }
        }
        return (bestAllocation, bestBoard, bestTotal)
    }

    public static func bestAllocation(
        counts: MiningCounts,
        hand: [ScoringCardID],
        opponent: Board?
    ) -> (allocation: MuleAllocation, board: Board, total: Int) {
        bestAllocation(counts: counts, cards: hand.map { ScoringCardCatalog[$0] }, opponent: opponent)
    }

    /// The board an opponent is assumed to present when a comparison rider reads
    /// their totals.
    ///
    /// D5 and L5 compare SET counts, and a player's set count depends on their
    /// own mule allocation -- which depends on their scoring, which depends on
    /// the comparison. That is circular, and the spec does not resolve it.
    ///
    /// The rule adopted here: a player's board is whatever maximises their score
    /// with comparison riders switched off. Their own board is their own
    /// business; it does not shift depending on who is looking at it. This is
    /// deterministic, symmetric between players, and independent of evaluation
    /// order, with no fixpoint iteration.
    public static func opponentReference(
        counts: MiningCounts,
        hand: [ScoringCardID]
    ) -> Board {
        let selfRegarding = hand.filter { id in
            ScoringCardCatalog[id].effects.contains { !$0.isOpponentRelative }
        }
        // If a hand is nothing but comparison riders there is no self-regarding
        // signal to optimise, so fall back to maximising sets formed.
        guard !selfRegarding.isEmpty else {
            var best = Board(counts: counts, allocation: .none)
            for candidate in MuleAllocation.candidates(mules: counts.packMule) {
                let board = Board(counts: counts, allocation: candidate)
                if board.oreShovelSets + board.gravelPanSets
                    > best.oreShovelSets + best.gravelPanSets {
                    best = board
                }
            }
            return best
        }
        return bestAllocation(counts: counts, hand: selfRegarding, opponent: nil).board
    }

    // MARK: - Public entry point

    /// Scores one player against an opponent, choosing the arrangement that
    /// maximises this player's total.
    public static func score(
        counts: MiningCounts,
        hand: [ScoringCardID],
        opponentCounts: MiningCounts,
        opponentHand: [ScoringCardID]
    ) -> Scorecard {
        let reference = opponentReference(counts: opponentCounts, hand: opponentHand)
        let best = bestAllocation(counts: counts, hand: hand, opponent: reference)
        let resolved = scoreCards(hand, board: best.board, opponent: reference)
        return Scorecard(
            total: resolved.total,
            allocation: best.allocation,
            board: best.board,
            cards: resolved.cards
        )
    }

    /// Scores a player with no opponent on the table. Comparison riders pay
    /// nothing, which is what the fixtures exercise.
    public static func scoreSolo(counts: MiningCounts, cards: [ScoringCard]) -> Scorecard {
        let best = bestAllocation(counts: counts, cards: cards, opponent: nil)
        let resolved = scoreCards(cards, board: best.board, opponent: nil)
        return Scorecard(
            total: resolved.total,
            allocation: best.allocation,
            board: best.board,
            cards: resolved.cards
        )
    }

    public static func scoreSolo(counts: MiningCounts, hand: [ScoringCardID]) -> Scorecard {
        scoreSolo(counts: counts, cards: hand.map { ScoringCardCatalog[$0] })
    }

    /// Scores a specific arrangement rather than the best one. Used by the tests
    /// that assert the optimiser beat the alternatives.
    public static func score(
        counts: MiningCounts,
        cards: [ScoringCard],
        allocation: MuleAllocation,
        opponent: Board? = nil
    ) -> Scorecard {
        let board = Board(counts: counts, allocation: allocation)
        let resolved = scoreCards(cards, board: board, opponent: opponent)
        return Scorecard(
            total: resolved.total,
            allocation: allocation,
            board: board,
            cards: resolved.cards
        )
    }

    public static func score(
        counts: MiningCounts,
        hand: [ScoringCardID],
        allocation: MuleAllocation,
        opponent: Board? = nil
    ) -> Scorecard {
        score(counts: counts, cards: hand.map { ScoringCardCatalog[$0] }, allocation: allocation, opponent: opponent)
    }
}
