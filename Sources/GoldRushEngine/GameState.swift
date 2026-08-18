public enum Phase: Sendable, Codable, Equatable, Hashable {
    /// Snake draft of scoring cards. Only reachable with `scoringDraft`.
    case draft
    /// Both players privately pick which of their cards to make public.
    case revealSelection
    /// The extra progressive-reveal pick, after round 4.
    case additionalReveal
    case split
    case choose
    case finished
}

/// A split awaiting the chooser's decision.
public struct PendingSplit: Sendable, Codable, Equatable, Hashable {
    public let pileA: [CardID]
    public let pileB: [CardID]
    /// Which cards were turned face down, across both piles.
    public let faceDown: CardSet

    public init(pileA: [CardID], pileB: [CardID], faceDown: CardSet) {
        self.pileA = pileA
        self.pileB = pileB
        self.faceDown = faceDown
    }

    public func pile(_ id: PileID) -> [CardID] {
        id == .a ? pileA : pileB
    }
}

public enum Action: Sendable, Codable, Equatable, Hashable {
    case selectRevealedScoringCards([ScoringCardID])
    case split(pileA: [CardID], pileB: [CardID], faceDown: [CardID])
    case choose(pile: PileID)

    /// Required by `scoringDraft`; unreachable when the toggle is off.
    case draftPick(ScoringCardID)
    /// Required by `progressiveReveal`; unreachable when the toggle is off.
    case revealAdditional(ScoringCardID)
}

public enum ActionError: Error, Sendable, Equatable {
    case wrongPhase(expected: Phase, actual: Phase)
    case notInHand(ScoringCardID)
    case alreadyRevealed(ScoringCardID)
    case wrongRevealCount(expected: Int, actual: Int)
    case familyCapExceeded(ScoringFamily)
    case cardNotInPool(ScoringCardID)
    case pileEmpty(PileID)
    case splitDoesNotMatchDraw
    case faceDownCountWrong(expected: Int, actual: Int)
    case faceDownCardNotInPiles(CardID)
    case gameFinished
}

/// The complete game, as an immutable value.
///
/// This is global truth: it knows every card, including ones a given player has
/// never seen. Nothing user-facing may read it directly -- rendering and agent
/// decisions go through `PlayerView`, which is a projection restricted to what
/// one player has legitimately observed.
public struct GameState: Sendable, Codable, Equatable {
    public let config: GameConfig

    public private(set) var rng: SeededRNG
    public private(set) var phase: Phase
    public private(set) var round: Int

    /// The shuffled mining deck. `drawn` cards have left it, in order.
    public private(set) var deck: [MiningCard]
    public private(set) var drawn: Int

    public private(set) var collections: PlayerPair<[CardID]>
    /// All six scoring cards each player holds. Three are public; all six score.
    public private(set) var hands: PlayerPair<[ScoringCardID]>
    public private(set) var revealed: PlayerPair<[ScoringCardID]>
    /// Every card each player has legitimately observed.
    public private(set) var observations: PlayerPair<CardSet>

    /// Cards drawn for the current round. The splitter has seen all of them.
    public private(set) var currentDraw: [CardID]
    public private(set) var pendingSplit: PendingSplit?

    /// Reveal selections submitted so far this phase.
    private var revealSubmitted: PlayerPair<Bool>
    /// Remaining face-up pool during a draft.
    public private(set) var draftPool: [ScoringCardID]
    private var draftPickIndex: Int

    // MARK: - Lookup

    public func card(_ id: CardID) -> MiningCard {
        deck[Int(id.rawValue)]
    }

    public func type(_ id: CardID) -> MiningType {
        deck[Int(id.rawValue)].type
    }

    public func counts(for player: PlayerID) -> MiningCounts {
        var counts = MiningCounts()
        for id in collections[player] { counts[type(id)] += 1 }
        return counts
    }

    /// Who must act next. Reveal selection resolves p1 before p2, which keeps the
    /// action sequence deterministic without letting either player see the
    /// other's choice -- `PlayerView` withholds it until both have submitted.
    public var actingPlayer: PlayerID? {
        switch phase {
        case .draft:
            guard draftPickIndex < GameConfig.draftOrder.count else { return nil }
            return GameConfig.draftOrder[draftPickIndex]
        case .revealSelection, .additionalReveal:
            if !revealSubmitted.p1 { return .p1 }
            if !revealSubmitted.p2 { return .p2 }
            return nil
        case .split:
            return config.splitter(round: round)
        case .choose:
            return config.chooser(round: round)
        case .finished:
            return nil
        }
    }

    public var isFinished: Bool { phase == .finished }

    // MARK: - Setup

    /// Builds a new game. Setup consumes the RNG; from here on the only source
    /// of change is `apply`.
    public static func newGame(config: GameConfig = .standard, seed: UInt64) -> GameState {
        var rng = SeededRNG(seed: seed)

        var deck = MiningDeck.build(composition: MiningDeck.scaledComposition(to: config.deckSize))
        rng.shuffle(&deck)
        // Re-key to positional ids so `card(_:)` is an array index, and so the
        // ids a player observes carry no information about the shuffle.
        deck = deck.enumerated().map { MiningCard(id: CardID(UInt16($0.offset)), type: $0.element.type) }

        var scoring = (0..<36).map { ScoringCardID.at(index: $0) }
        rng.shuffle(&scoring)

        var hands = PlayerPair<[ScoringCardID]>(repeating: [])
        var draftPool: [ScoringCardID] = []

        if config.scoringDraft {
            // Two cards from each of the six families.
            //
            // A pool drawn blindly from the 36 can deadlock: if it happened to
            // hold only two families, no player could assemble six cards under
            // the two-per-family cap, and the draft would stall with no legal
            // pick. Stratifying makes the draft provably completable -- holding
            // two of a family means both of that family's pool cards are already
            // yours, so any card still in the pool is one you may legally take.
            var pool: [ScoringCardID] = []
            for family in ScoringFamily.allCases {
                let members = scoring.filter { $0.family == family }
                pool.append(contentsOf: members.prefix(GameConfig.familyCap))
            }
            rng.shuffle(&pool)
            draftPool = pool
        } else {
            // Deal 6 each. A card that would give a player a third of one family
            // is set aside and replaced, per the redeal rule.
            var cursor = 0
            for player in [PlayerID.p1, .p2] {
                var familyCounts = [Int](repeating: 0, count: ScoringFamily.allCases.count)
                var hand: [ScoringCardID] = []
                while hand.count < GameConfig.handSize, cursor < scoring.count {
                    let candidate = scoring[cursor]
                    cursor += 1
                    let slot = Int(candidate.family.rawValue)
                    if familyCounts[slot] < GameConfig.familyCap {
                        familyCounts[slot] += 1
                        hand.append(candidate)
                    }
                }
                hands[player] = hand
            }
        }

        return GameState(
            config: config,
            rng: rng,
            phase: config.scoringDraft ? .draft : .revealSelection,
            round: 1,
            deck: deck,
            drawn: 0,
            collections: PlayerPair(repeating: []),
            hands: hands,
            revealed: PlayerPair(repeating: []),
            observations: PlayerPair(repeating: CardSet()),
            currentDraw: [],
            pendingSplit: nil,
            revealSubmitted: PlayerPair(repeating: false),
            draftPool: draftPool,
            draftPickIndex: 0
        )
    }

    // MARK: - Legality

    public func isLegal(_ action: Action) -> Bool {
        (try? validate(action)) != nil
    }

    public func validate(_ action: Action) throws(ActionError) {
        guard phase != .finished else { throw .gameFinished }
        guard let actor = actingPlayer else { throw .wrongPhase(expected: phase, actual: phase) }

        switch action {
        case .draftPick(let id):
            guard phase == .draft else { throw .wrongPhase(expected: .draft, actual: phase) }
            guard draftPool.contains(id) else { throw .cardNotInPool(id) }
            let held = hands[actor].count { $0.family == id.family }
            guard held < GameConfig.familyCap else { throw .familyCapExceeded(id.family) }

        case .selectRevealedScoringCards(let ids):
            guard phase == .revealSelection else {
                throw .wrongPhase(expected: .revealSelection, actual: phase)
            }
            guard ids.count == config.initialRevealCount else {
                throw .wrongRevealCount(expected: config.initialRevealCount, actual: ids.count)
            }
            guard Set(ids).count == ids.count else {
                throw .wrongRevealCount(expected: config.initialRevealCount, actual: Set(ids).count)
            }
            for id in ids where !hands[actor].contains(id) { throw .notInHand(id) }

        case .revealAdditional(let id):
            guard phase == .additionalReveal else {
                throw .wrongPhase(expected: .additionalReveal, actual: phase)
            }
            guard hands[actor].contains(id) else { throw .notInHand(id) }
            guard !revealed[actor].contains(id) else { throw .alreadyRevealed(id) }

        case .split(let pileA, let pileB, let faceDown):
            guard phase == .split else { throw .wrongPhase(expected: .split, actual: phase) }
            guard !pileA.isEmpty else { throw .pileEmpty(.a) }
            guard !pileB.isEmpty else { throw .pileEmpty(.b) }
            // Every drawn card must appear exactly once across the two piles.
            let combined = pileA + pileB
            guard combined.count == currentDraw.count,
                  Set(combined).count == combined.count,
                  Set(combined) == Set(currentDraw)
            else { throw .splitDoesNotMatchDraw }

            let expected = config.faceDownCount(round: round)
            guard faceDown.count == expected, Set(faceDown).count == faceDown.count else {
                throw .faceDownCountWrong(expected: expected, actual: faceDown.count)
            }
            let placed = Set(combined)
            for id in faceDown where !placed.contains(id) { throw .faceDownCardNotInPiles(id) }

        case .choose:
            guard phase == .choose else { throw .wrongPhase(expected: .choose, actual: phase) }
            guard pendingSplit != nil else { throw .wrongPhase(expected: .choose, actual: phase) }
        }
    }

    // MARK: - Reducer

    /// Pure. An illegal action leaves the state untouched rather than trapping,
    /// so a misbehaving client cannot crash a game in progress. Tests use
    /// `applyChecked` so a typo in a test cannot silently pass by no-op.
    public func apply(_ action: Action) -> GameState {
        guard isLegal(action) else { return self }
        return reduce(action)
    }

    public func applyChecked(_ action: Action) throws(ActionError) -> GameState {
        try validate(action)
        return reduce(action)
    }

    private func reduce(_ action: Action) -> GameState {
        var next = self
        guard let actor = actingPlayer else { return self }

        switch action {
        case .draftPick(let id):
            next.hands[actor].append(id)
            next.draftPool.removeAll { $0 == id }
            next.draftPickIndex += 1
            if next.draftPickIndex >= GameConfig.draftOrder.count {
                next.phase = .revealSelection
            }

        case .selectRevealedScoringCards(let ids):
            next.revealed[actor] = ids
            next.revealSubmitted[actor] = true
            if next.revealSubmitted.p1 && next.revealSubmitted.p2 {
                next.revealSubmitted = PlayerPair(repeating: false)
                next.beginRound()
            }

        case .revealAdditional(let id):
            next.revealed[actor].append(id)
            next.revealSubmitted[actor] = true
            if next.revealSubmitted.p1 && next.revealSubmitted.p2 {
                next.revealSubmitted = PlayerPair(repeating: false)
                next.round += 1
                next.beginRound()
            }

        case .split(let pileA, let pileB, let faceDown):
            next.pendingSplit = PendingSplit(pileA: pileA, pileB: pileB, faceDown: CardSet(faceDown))
            next.phase = .choose

        case .choose(let pile):
            guard let split = next.pendingSplit else { return self }
            let chooser = config.chooser(round: round)
            let splitter = config.splitter(round: round)
            let taken = split.pile(pile)
            let left = split.pile(pile.other)

            next.collections[chooser].append(contentsOf: taken)
            next.collections[splitter].append(contentsOf: left)

            // The chooser sees every face-up card in both piles, and the full
            // contents of the pile it claimed. Face-down cards in the pile it
            // passed on stay unknown -- permanently, when hidden cards persist.
            for id in split.pileA + split.pileB where !split.faceDown.contains(id) {
                next.observations[chooser].insert(id)
            }
            for id in taken { next.observations[chooser].insert(id) }
            if !config.persistentHiddenCards {
                for id in split.pileA + split.pileB { next.observations[chooser].insert(id) }
            }
            // The splitter drew every card, so it already knows them all.

            next.pendingSplit = nil
            next.currentDraw = []
            next.advanceAfterChoose()
        }

        return next
    }

    // MARK: - Round transitions

    private mutating func beginRound() {
        let count = config.drawCount(round: round)
        let available = deck.count - drawn
        let take = min(count, available)
        var drawnIDs: [CardID] = []
        drawnIDs.reserveCapacity(take)
        for offset in 0..<take {
            drawnIDs.append(deck[drawn + offset].id)
        }
        drawn += take
        currentDraw = drawnIDs

        // The splitter draws privately, so it observes the whole draw -- including
        // cards that will end up in the pile it loses. This asymmetry is the
        // reason splitting costs nothing informationally.
        let splitter = config.splitter(round: round)
        for id in drawnIDs { observations[splitter].insert(id) }

        phase = .split
    }

    private mutating func advanceAfterChoose() {
        if config.progressiveReveal,
           round == config.progressiveRevealAfterRound,
           revealed.p1.count < config.finalRevealCount {
            phase = .additionalReveal
            return
        }
        if round >= config.roundCount {
            phase = .finished
            return
        }
        round += 1
        beginRound()
    }

    // MARK: - Scoring

    public func scorecard(for player: PlayerID) -> Scorecard {
        Scoring.score(
            counts: counts(for: player),
            hand: hands[player],
            opponentCounts: counts(for: player.opponent),
            opponentHand: hands[player.opponent]
        )
    }

    /// Final result. Tiebreak: most Gold Nugget, then fewest Fool's Gold, then
    /// Player 2.
    public func winner() -> PlayerID {
        let s1 = scorecard(for: .p1).total
        let s2 = scorecard(for: .p2).total
        if s1 != s2 { return s1 > s2 ? .p1 : .p2 }

        let c1 = counts(for: .p1)
        let c2 = counts(for: .p2)
        if c1.goldNugget != c2.goldNugget { return c1.goldNugget > c2.goldNugget ? .p1 : .p2 }
        if c1.foolsGold != c2.foolsGold { return c1.foolsGold < c2.foolsGold ? .p1 : .p2 }
        return .p2
    }
}
