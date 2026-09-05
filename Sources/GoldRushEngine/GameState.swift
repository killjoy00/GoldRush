public enum Phase: Sendable, Codable, Equatable, Hashable {
    /// Pack draft of scoring cards. Only reachable with `scoringDraft`.
    case draft
    /// Legacy seven-card drafts trim the drafted seven down to six here.
    /// New eight-card drafts discard from the pack at the opening and close.
    case draftDiscard
    /// Both players privately pick which of their cards to make public.
    case revealSelection
    /// The extra progressive-reveal pick, after round 4.
    case additionalReveal
    case split
    case choose
    case finished
}

/// What happened in one resolved round.
///
/// Stored in the state so the recap and Claim Journal can project exactly the
/// information a player was entitled to see without reconstructing it later.
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

    /// Opening an eight-card draft pack: one card is kept, one is discarded
    /// face up after both players have committed, and the remaining six pass.
    case draftOpen(keep: ScoringCardID, discard: ScoringCardID)
    /// Middle draft passes: keep one and pass the remainder.
    case draftPick(ScoringCardID)
    /// Closing a two-card pack: keep one and discard the other face up after
    /// both players have committed.
    case draftClose(keep: ScoringCardID, discard: ScoringCardID)
    /// Legacy seven-card saved matches only.
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
    case wrongDraftPackSize(expected: Int, actual: Int)
    case draftCardsMustDiffer
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
    /// All six scoring cards each player holds. Three are public in dealt games;
    /// drafted games expose every pick except the opening keep.
    public private(set) var hands: PlayerPair<[ScoringCardID]>
    public private(set) var revealed: PlayerPair<[ScoringCardID]>
    /// Every mining card each player has legitimately observed.
    public private(set) var observations: PlayerPair<CardSet>

    /// Cards drawn for the current round, per player. Only a player who is
    /// splitting this round has a draw; the other entry is empty.
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
    /// Detailed resolved rounds for the Claim Journal. Optional so match data
    /// written by versions before the Journal existed still decodes.
    public private(set) var roundHistory: [RoundOutcome]?
    /// Every split's public outcome, for the whole match so far.
    public private(set) var splitLog: [SplitRecord]

    /// Reveal selections submitted so far this phase.
    private var revealSubmitted: PlayerPair<Bool>
    /// The pack currently in front of each player during a draft.
    public private(set) var draftPacks: PlayerPair<[ScoringCardID]>
    /// Committed this draft decision. Both players act before packs pass.
    private var draftSubmitted: PlayerPair<Bool>
    /// The opening keep from the pack each player first saw. In the eight-card
    /// rules this can never be discarded and is the one permanent secret.
    public private(set) var draftFirstPick: PlayerPair<ScoringCardID?>
    /// The latest pair of committed face-up discards. Retained under the old
    /// name so seven-card saved matches continue to decode.
    public private(set) var draftDiscarded: PlayerPair<ScoringCardID?>
    /// All public draft discards: opening and closing. Optional for backwards
    /// decoding of matches saved before the eight-card draft existed.
    public private(set) var draftDiscards: PlayerPair<[ScoringCardID]>?
    /// A discard chosen by one seat but not yet publishable because the other
    /// seat has not committed. Keeping it out of `PlayerView` preserves the
    /// simultaneous decision even though actions resolve in seat order.
    private var draftPendingDiscard: PlayerPair<ScoringCardID?>?
    /// Compatibility escape hatch. If an older client/test begins an eight-card
    /// pack with the old one-card action, finish that draft using the legacy
    /// seven-kept-then-discard flow rather than stranding the game. A nil value
    /// means this state was decoded from a version that predates the flag.
    private var draftLegacyMode: Bool?

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

    /// Who must act next. Paired setup decisions resolve p1 before p2 for a
    /// deterministic action sequence, while their private choices stay sealed.
    public var actingPlayer: PlayerID? {
        switch phase {
        case .draft, .draftDiscard:
            if !draftSubmitted.p1 { return .p1 }
            if !draftSubmitted.p2 { return .p2 }
            return nil
        case .revealSelection, .additionalReveal:
            if !revealSubmitted.p1 { return .p1 }
            if !revealSubmitted.p2 { return .p2 }
            return nil
        case .split:
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
            // Sixteen cards off the shuffled scoring deck, cut into two packs
            // of eight -- one opened by each player. No family cap: every card
            // in a pack is always a legal keep or discard.
            let pool = Array(scoring.prefix(GameConfig.draftOpeningPoolSize))
            draftPacks = PlayerPair(
                p1: Array(pool.prefix(GameConfig.draftOpeningPackSize)),
                p2: Array(pool.suffix(GameConfig.draftOpeningPackSize))
            )
        } else {
            // Deal 6 each, straight off the shuffled deck.
            for (index, player) in [PlayerID.p1, .p2].enumerated() {
                let start = index * GameConfig.handSize
                hands[player] = Array(scoring[start..<(start + GameConfig.handSize)])
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
            roundHistory: [],
            splitLog: [],
            revealSubmitted: PlayerPair(repeating: false),
            draftPacks: draftPacks,
            draftSubmitted: PlayerPair(repeating: false),
            draftFirstPick: PlayerPair(repeating: nil),
            draftDiscarded: PlayerPair(repeating: nil),
            draftDiscards: PlayerPair(repeating: []),
            draftPendingDiscard: PlayerPair(repeating: nil),
            draftLegacyMode: false
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
        case .draftOpen(let keep, let discard):
            guard phase == .draft else { throw .wrongPhase(expected: .draft, actual: phase) }
            let pack = draftPacks[actor]
            guard pack.count == GameConfig.draftOpeningPackSize else {
                throw .wrongDraftPackSize(expected: GameConfig.draftOpeningPackSize, actual: pack.count)
            }
            guard keep != discard else { throw .draftCardsMustDiffer }
            guard pack.contains(keep) else { throw .cardNotInPool(keep) }
            guard pack.contains(discard) else { throw .cardNotInPool(discard) }

        case .draftPick(let id):
            guard phase == .draft else { throw .wrongPhase(expected: .draft, actual: phase) }
            guard draftPacks[actor].contains(id) else { throw .cardNotInPool(id) }

        case .draftClose(let keep, let discard):
            guard phase == .draft else { throw .wrongPhase(expected: .draft, actual: phase) }
            let pack = draftPacks[actor]
            guard pack.count == 2 else { throw .wrongDraftPackSize(expected: 2, actual: pack.count) }
            guard keep != discard else { throw .draftCardsMustDiffer }
            guard pack.contains(keep) else { throw .cardNotInPool(keep) }
            guard pack.contains(discard) else { throw .cardNotInPool(discard) }

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
            guard pendingSplits[actor.opponent] != nil else {
                throw .wrongPhase(expected: .choose, actual: phase)
            }
        }
    }

    // MARK: - Reducer

    /// Pure. An illegal action leaves the state untouched rather than trapping.
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

        /// Makes a pair of pending modern draft discards public at once.
        func publishDraftDiscards(_ state: inout GameState) {
            guard let pending = state.draftPendingDiscard,
                  let p1 = pending.p1, let p2 = pending.p2 else { return }
            state.draftDiscarded = PlayerPair(p1: p1, p2: p2)
            if state.draftDiscards == nil { state.draftDiscards = PlayerPair(repeating: []) }
            state.draftDiscards?.p1.append(p1)
            state.draftDiscards?.p2.append(p2)
            state.draftPendingDiscard = PlayerPair(repeating: nil)
        }

        switch action {
        case .draftOpen(let keep, let discard):
            next.draftLegacyMode = false
            next.draftFirstPick[actor] = keep
            next.hands[actor].append(keep)
            next.draftPacks[actor].removeAll { $0 == keep || $0 == discard }
            if next.draftPendingDiscard == nil { next.draftPendingDiscard = PlayerPair(repeating: nil) }
            next.draftPendingDiscard?[actor] = discard
            next.draftSubmitted[actor] = true

            if next.draftSubmitted.p1 && next.draftSubmitted.p2 {
                publishDraftDiscards(&next)
                next.draftSubmitted = PlayerPair(repeating: false)
                // Each opened pack now has six; hand it to the opponent.
                next.draftPacks = PlayerPair(p1: next.draftPacks.p2, p2: next.draftPacks.p1)
            }

        case .draftPick(let id):
            // `draftLegacyMode` did not exist in seven-card match data. A nil
            // value therefore identifies an old saved draft and must behave as
            // legacy before the first post-upgrade pick is applied.
            if next.draftLegacyMode == nil { next.draftLegacyMode = true }
            // An old caller/test that starts a modern eight-card pack with the
            // old one-card action also completes through the legacy path.
            if next.hands[actor].isEmpty && next.draftPacks[actor].count == GameConfig.draftOpeningPackSize {
                next.draftLegacyMode = true
            }
            if next.hands[actor].isEmpty { next.draftFirstPick[actor] = id }
            next.hands[actor].append(id)
            next.draftPacks[actor].removeAll { $0 == id }
            next.draftSubmitted[actor] = true

            if next.draftSubmitted.p1 && next.draftSubmitted.p2 {
                next.draftSubmitted = PlayerPair(repeating: false)
                next.draftPacks = PlayerPair(p1: next.draftPacks.p2, p2: next.draftPacks.p1)

                if next.draftLegacyMode == true,
                   next.hands.p1.count >= GameConfig.draftPackSize,
                   next.hands.p2.count >= GameConfig.draftPackSize {
                    // Two cards from the modern 16-card pool are intentionally
                    // unused when a current game is driven by an old caller;
                    // genuinely old saved games simply exhaust their 14-card pool.
                    next.draftPacks = PlayerPair(repeating: [])
                    next.phase = .draftDiscard
                }
            }

        case .draftClose(let keep, let discard):
            next.hands[actor].append(keep)
            next.draftPacks[actor].removeAll { $0 == keep || $0 == discard }
            if next.draftPendingDiscard == nil { next.draftPendingDiscard = PlayerPair(repeating: nil) }
            next.draftPendingDiscard?[actor] = discard
            next.draftSubmitted[actor] = true

            if next.draftSubmitted.p1 && next.draftSubmitted.p2 {
                publishDraftDiscards(&next)
                next.draftSubmitted = PlayerPair(repeating: false)
                next.draftPacks = PlayerPair(repeating: [])
                // No reveal-selection phase after a draft. Every kept card
                // except the opening keep passed through the opponent's hands.
                for player in [PlayerID.p1, .p2] {
                    let first = next.draftFirstPick[player]
                    next.revealed[player] = next.hands[player].filter { $0 != first }
                }
                next.beginRound()
            }

        case .draftDiscard(let id):
            // Legacy saved drafts only.
            next.hands[actor].removeAll { $0 == id }
            next.draftDiscarded[actor] = id
            next.draftSubmitted[actor] = true

            if next.draftSubmitted.p1 && next.draftSubmitted.p2 {
                next.draftSubmitted = PlayerPair(repeating: false)
                if next.draftDiscards == nil { next.draftDiscards = PlayerPair(repeating: []) }
                if let p1 = next.draftDiscarded.p1 { next.draftDiscards?.p1.append(p1) }
                if let p2 = next.draftDiscarded.p2 { next.draftDiscards?.p2.append(p2) }
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

            next.chooseSubmitted[chooser] = true
            next.takenPile[chooser] = pile
            if config.choosers(round: round).allSatisfy({ next.chooseSubmitted[$0] }) {
                // Snapshot before tearing the round down. Keep the exact same
                // snapshot in the short recap and the permanent Claim Journal.
                let outcome = RoundOutcome(
                    round: round, splits: next.pendingSplits, taken: next.takenPile
                )
                next.lastRound = outcome
                if next.roundHistory == nil { next.roundHistory = [] }
                next.roundHistory?.append(outcome)

                // splitLog only ever grows, but deliberately contains no card
                // identities because agents need only the public metadata.
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
            // including cards that will end up in the pile it loses.
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
