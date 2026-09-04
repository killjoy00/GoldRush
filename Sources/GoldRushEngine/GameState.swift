public enum Phase: Sendable, Codable, Equatable, Hashable {
    /// Snake draft of scoring cards. Only reachable with `scoringDraft`.
    case draft
    /// Trimming the drafted seven down to the six you score with. Only
    /// reachable with `scoringDraft`.
    case draftDiscard
    /// Both players privately pick which of their cards to make public.
    case revealSelection
    /// The extra progressive-reveal pick, after round 4.
    case additionalReveal
    case split
    case choose
    case finished
}

/// What happened in the round that just ended.
///
/// Kept on the state because it would otherwise be destroyed the instant the
/// round advanced, and "what did they take?" is the single question the game
/// gives you no way to answer. It is not new information -- both players were
/// entitled to all of it as it happened -- so `PlayerView` projects it under
/// exactly the same visibility rules as the live piles.
public struct RoundOutcome: Sendable, Codable, Equatable, Hashable {
    public let round: Int
    /// The split each player made, keyed by the player who made it.
    public let splits: PlayerPair<PendingSplit?>
    /// Which pile each player took from their opponent's split.
    public let taken: PlayerPair<PileID?>

    public init(round: Int, splits: PlayerPair<PendingSplit?>, taken: PlayerPair<PileID?>) {
        self.round = round
        self.splits = splits
        self.taken = taken
    }
}

/// One split's public outcome, kept for the rest of the match after
/// `RoundOutcome` is torn down.
///
/// Deliberately card-free: draw size, how many were buried, and which pile
/// was taken are not secrets -- both players watch them happen live, the
/// same way they watch who takes a pile. What IS secret, and stays that way,
/// is which cards they were. This exists so an agent can work out how much
/// of the deck its opponent has personally drawn through over the whole
/// game, not just this round -- without ever learning what any of it was.
public struct SplitRecord: Sendable, Codable, Equatable, Hashable {
    public let round: Int
    public let splitter: PlayerID
    public let drawCount: Int
    public let faceDownCount: Int
    /// Of `faceDownCount`, how many were in the pile the chooser took --
    /// and therefore now knows, same as any other card they claimed.
    public let faceDownInTaken: Int
    public let taken: PileID

    public init(
        round: Int, splitter: PlayerID, drawCount: Int,
        faceDownCount: Int, faceDownInTaken: Int, taken: PileID
    ) {
        self.round = round
        self.splitter = splitter
        self.drawCount = drawCount
        self.faceDownCount = faceDownCount
        self.faceDownInTaken = faceDownInTaken
        self.taken = taken
    }
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
    /// Throwing away one of the seven drafted cards. Required by
    /// `scoringDraft`; unreachable when the toggle is off.
    case draftDiscard(ScoringCardID)
    /// Required by `progressiveReveal`; unreachable when the toggle is off.
    case revealAdditional(ScoringCardID)
}

public enum ActionError: Error, Sendable, Equatable {
    case wrongPhase(expected: Phase, actual: Phase)
    case notInHand(ScoringCardID)
    case alreadyRevealed(ScoringCardID)
    case wrongRevealCount(expected: Int, actual: Int)
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

    /// Cards drawn for the current round, per player. Only a player who is
    /// splitting this round has a draw; the other entry is empty.
    ///
    /// Per-player even when splitting alternates, so one code path covers both
    /// round structures instead of two that have to agree with each other.
    public private(set) var currentDraw: PlayerPair<[CardID]>
    /// The split each player has made and their opponent has yet to choose from.
    public private(set) var pendingSplits: PlayerPair<PendingSplit?>
    /// Committed this phase. Splits stay sealed until both are in, so a
    /// simultaneous round cannot leak one player's division to the other.
    private var splitSubmitted: PlayerPair<Bool>
    private var chooseSubmitted: PlayerPair<Bool>
    /// Which pile each chooser has taken this round, pending resolution.
    private var takenPile: PlayerPair<PileID?>
    /// The round that just finished, for the recap screen.
    public private(set) var lastRound: RoundOutcome?
    /// Every split's public outcome, for the whole match so far. Grows by one
    /// entry per splitter per round; never torn down the way `lastRound` is.
    public private(set) var splitLog: [SplitRecord]

    /// Reveal selections submitted so far this phase.
    private var revealSubmitted: PlayerPair<Bool>
    /// The pack currently in front of each player during a draft.
    ///
    /// Two packs are dealt and passed back and forth: you see a pack, take one
    /// card, and hand the remainder to your opponent. That produces exactly the
    /// information structure this game wants, for free. You see every card in
    /// the pack you open, so you learn all three of your opponent's picks from
    /// it; but the pack THEY opened reaches you with their first pick already
    /// gone, and you never learn what it was. Each player therefore finishes
    /// the draft knowing five of the opponent's six cards, with one permanent
    /// unknown -- which is why a drafted game needs no reveal phase.
    public private(set) var draftPacks: PlayerPair<[ScoringCardID]>
    /// Picked this pass. Both players pick before the packs swap.
    private var draftSubmitted: PlayerPair<Bool>
    /// The one card each player's opponent never sees.
    public private(set) var draftFirstPick: PlayerPair<ScoringCardID?>
    /// What each player threw away to get from seven cards down to six.
    ///
    /// Public, and deliberately so. The alternative -- discarding face down --
    /// looks like it adds a secret but does not: your opponent watched you
    /// draft six of your seven, so a hidden discard is one they can usually
    /// name by elimination, and the cases where they cannot are exactly the
    /// cases where `revealed` would give it away instead. Face up, the
    /// information structure stays the one the draft already produced: your
    /// opening pick is the single card they never see.
    public private(set) var draftDiscarded: PlayerPair<ScoringCardID?>

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
        case .draft, .draftDiscard:
            // Both players pick from their own pack before the packs swap, so
            // this resolves p1 then p2 the same way reveal selection does. The
            // order leaks nothing: neither player can see the other's pack.
            // The discard is simultaneous for the same reason -- each is
            // choosing from their own seven, blind to the other's choice.
            if !draftSubmitted.p1 { return .p1 }
            if !draftSubmitted.p2 { return .p2 }
            return nil
        case .revealSelection, .additionalReveal:
            if !revealSubmitted.p1 { return .p1 }
            if !revealSubmitted.p2 { return .p2 }
            return nil
        case .split:
            // Resolved p1 before p2 so the action sequence is deterministic.
            // That leaks nothing: PlayerView withholds a split until both are
            // committed, exactly as it does for reveal selection.
            return config.splitters(round: round).first { !splitSubmitted[$0] }
        case .choose:
            return config.choosers(round: round).first { !chooseSubmitted[$0] }
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

        var scoring = (0..<ScoringCardID.total).map { ScoringCardID.at(index: $0) }
        rng.shuffle(&scoring)

        var hands = PlayerPair<[ScoringCardID]>(repeating: [])
        var draftPacks = PlayerPair<[ScoringCardID]>(repeating: [])

        if config.scoringDraft {
            // Fourteen cards off the top of the shuffled deck, cut into two
            // packs of seven -- one opened by each player.
            //
            // An earlier version stratified this pool to hold exactly two of
            // every family, because a two-per-family cap on hands could
            // otherwise deadlock the draft: a pack whose last card belonged to
            // a family you were already full on left you with no legal pick.
            // With the cap gone there is no such thing as an illegal pick, so
            // the pool no longer has to be engineered to keep one available,
            // and drawing it blind restores the variance stratifying removed --
            // a pack can now arrive four-deep in one family, which is a
            // decision rather than a dead end.
            let pool = Array(scoring.prefix(GameConfig.draftPoolSize))
            draftPacks = PlayerPair(
                p1: Array(pool.prefix(GameConfig.draftPackSize)),
                p2: Array(pool.suffix(GameConfig.draftPackSize))
            )
        } else {
            // Deal 6 each, straight off the shuffled deck.
            for (index, player) in [PlayerID.p1, .p2].enumerated() {
                let start = index * GameConfig.handSize
                hands[player] = Array(
                    scoring[start..<(start + GameConfig.handSize)]
                )
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
            currentDraw: PlayerPair(repeating: []),
            pendingSplits: PlayerPair(repeating: nil),
            splitSubmitted: PlayerPair(repeating: false),
            chooseSubmitted: PlayerPair(repeating: false),
            takenPile: PlayerPair(repeating: nil),
            lastRound: nil,
            splitLog: [],
            revealSubmitted: PlayerPair(repeating: false),
            draftPacks: draftPacks,
            draftSubmitted: PlayerPair(repeating: false),
            draftFirstPick: PlayerPair(repeating: nil),
            draftDiscarded: PlayerPair(repeating: nil)
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
            guard draftPacks[actor].contains(id) else { throw .cardNotInPool(id) }

        case .draftDiscard(let id):
            guard phase == .draftDiscard else {
                throw .wrongPhase(expected: .draftDiscard, actual: phase)
            }
            guard hands[actor].contains(id) else { throw .notInHand(id) }

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
            // Every card THIS player drew must appear exactly once across the
            // two piles -- their own draw, not the other splitter's.
            let mine = currentDraw[actor]
            let combined = pileA + pileB
            guard combined.count == mine.count,
                  Set(combined).count == combined.count,
                  Set(combined) == Set(mine)
            else { throw .splitDoesNotMatchDraw }

            let expected = config.faceDownCount(round: round)
            guard faceDown.count == expected, Set(faceDown).count == faceDown.count else {
                throw .faceDownCountWrong(expected: expected, actual: faceDown.count)
            }
            let placed = Set(combined)
            for id in faceDown where !placed.contains(id) { throw .faceDownCardNotInPiles(id) }

        case .choose:
            guard phase == .choose else { throw .wrongPhase(expected: .choose, actual: phase) }
            // You choose from the split your opponent made.
            guard pendingSplits[actor.opponent] != nil else {
                throw .wrongPhase(expected: .choose, actual: phase)
            }
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
            if next.hands[actor].isEmpty { next.draftFirstPick[actor] = id }
            next.hands[actor].append(id)
            next.draftPacks[actor].removeAll { $0 == id }
            next.draftSubmitted[actor] = true

            if next.draftSubmitted.p1 && next.draftSubmitted.p2 {
                next.draftSubmitted = PlayerPair(repeating: false)
                // Pass the packs. What is left of the pack you opened goes to
                // your opponent, and theirs comes to you.
                next.draftPacks = PlayerPair(p1: next.draftPacks.p2, p2: next.draftPacks.p1)

                if next.hands.p1.count >= GameConfig.draftPackSize
                    && next.hands.p2.count >= GameConfig.draftPackSize {
                    // Both packs are exhausted and both players hold seven.
                    // One card each still has to go.
                    next.phase = .draftDiscard
                }
            }

        case .draftDiscard(let id):
            next.hands[actor].removeAll { $0 == id }
            next.draftDiscarded[actor] = id
            next.draftSubmitted[actor] = true

            if next.draftSubmitted.p1 && next.draftSubmitted.p2 {
                next.draftSubmitted = PlayerPair(repeating: false)
                // No reveal phase after a draft. Your opponent watched you
                // take everything except your opening pick, so publishing
                // those five cards tells them nothing they had not already
                // worked out -- and pretending otherwise would hide the
                // information from the UI, not from the player.
                //
                // The discard does not change that count, only which card the
                // gap falls on. Throw away your opening pick and the six you
                // keep are all cards they watched you take, so all six become
                // public; throw away any other and your opening pick is still
                // the one they never saw, leaving five. Filtering the hand by
                // the first pick expresses both cases without a branch.
                for player in [PlayerID.p1, .p2] {
                    let first = next.draftFirstPick[player]
                    next.revealed[player] = next.hands[player].filter { $0 != first }
                }
                next.beginRound()
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
            next.pendingSplits[actor] = PendingSplit(
                pileA: pileA, pileB: pileB, faceDown: CardSet(faceDown)
            )
            next.splitSubmitted[actor] = true
            // Nobody chooses until every split this round is sealed.
            if config.splitters(round: round).allSatisfy({ next.splitSubmitted[$0] }) {
                next.splitSubmitted = PlayerPair(repeating: false)
                next.phase = .choose
            }

        case .choose(let pile):
            let chooser = actor
            let splitter = actor.opponent
            guard let split = next.pendingSplits[splitter] else { return self }
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

            next.chooseSubmitted[chooser] = true
            next.takenPile[chooser] = pile
            if config.choosers(round: round).allSatisfy({ next.chooseSubmitted[$0] }) {
                // Snapshot before tearing the round down; this is the only
                // moment both splits and both choices exist together.
                next.lastRound = RoundOutcome(
                    round: round, splits: next.pendingSplits, taken: next.takenPile
                )
                // splitLog only ever grows -- unlike lastRound, which the
                // recap consumes and this round's teardown then discards.
                for splitter in config.splitters(round: round) {
                    guard let split = next.pendingSplits[splitter],
                          let taken = next.takenPile[splitter.opponent] else { continue }
                    let faceDownInTaken = split.pile(taken).count { split.faceDown.contains($0) }
                    next.splitLog.append(SplitRecord(
                        round: round,
                        splitter: splitter,
                        drawCount: split.pileA.count + split.pileB.count,
                        faceDownCount: split.faceDown.count,
                        faceDownInTaken: faceDownInTaken,
                        taken: taken
                    ))
                }
                next.chooseSubmitted = PlayerPair(repeating: false)
                next.takenPile = PlayerPair(repeating: nil)
                next.pendingSplits = PlayerPair(repeating: nil)
                next.currentDraw = PlayerPair(repeating: [])
                next.advanceAfterChoose()
            }
        }

        return next
    }

    // MARK: - Round transitions

    private mutating func beginRound() {
        currentDraw = PlayerPair(repeating: [])
        // Dealt in seat order so a simultaneous round is reproducible from its
        // seed rather than from whoever the UI happened to prompt first.
        for splitter in config.splitters(round: round) {
            let count = config.drawCount(round: round)
            let available = deck.count - drawn
            let take = min(count, available)
            var drawnIDs: [CardID] = []
            drawnIDs.reserveCapacity(take)
            for offset in 0..<take {
                drawnIDs.append(deck[drawn + offset].id)
            }
            drawn += take
            currentDraw[splitter] = drawnIDs

            // A splitter draws privately, so it observes its whole draw --
            // including cards that will end up in the pile it loses. This
            // asymmetry is why splitting costs nothing informationally.
            for id in drawnIDs { observations[splitter].insert(id) }
        }

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
