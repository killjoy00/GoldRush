/// A card as one player perceives it.
public enum VisibleCard: Sendable, Equatable, Hashable {
    case known(CardID, MiningType)
    /// Present and countable, but its identity was never observed.
    case hidden(CardID)

    public var id: CardID {
        switch self {
        case .known(let id, _): id
        case .hidden(let id): id
        }
    }

    public var type: MiningType? {
        switch self {
        case .known(_, let type): type
        case .hidden: nil
        }
    }

    public var isHidden: Bool {
        if case .hidden = self { return true }
        return false
    }
}

/// One player's restricted view of the game.
///
/// This is the ONLY surface the UI and the agents are allowed to read. It is a
/// projection, not a filter applied at the point of use: a card the player has
/// not observed is absent from the data rather than present-but-marked, so
/// there is no accessor through which hidden information could leak. That is
/// what makes the unseen tracker sound by construction rather than by
/// discipline.
public struct PlayerView: Sendable, Equatable {
    public let player: PlayerID
    public let config: GameConfig
    public let phase: Phase
    public let round: Int
    public let isFinished: Bool

    /// This player's own cards, always fully known.
    public let collection: [VisibleCard]
    public let collectionCounts: MiningCounts

    /// The opponent's cards. Those this player observed carry their type; the
    /// rest are `.hidden` -- countable, but unidentified, forever.
    public let opponentCollection: [VisibleCard]
    /// Types of opponent cards this player has actually seen.
    public let opponentKnownCounts: MiningCounts
    /// How many opponent cards this player has never identified.
    public let opponentHiddenCount: Int

    /// All six of this player's scoring cards. All six score at the end.
    public let hand: [ScoringCardID]
    public let myRevealed: [ScoringCardID]
    /// The opponent's public scoring cards. Empty until they have committed.
    public let opponentRevealed: [ScoringCardID]

    /// Everything this player has not seen, as one pool: the cards never dealt
    /// PLUS any card that reached the opponent face down without this player
    /// identifying it. Both are genuinely unknown, so they are counted together.
    public let unseen: MiningCounts
    public let unseenTotal: Int

    /// The draw awaiting a split. Populated only for the splitter, who drew it.
    public let currentDraw: [VisibleCard]
    /// The two piles YOU are choosing from -- the ones your opponent made.
    /// Face-down cards read as hidden, because you must decide without them.
    public let piles: (a: [VisibleCard], b: [VisibleCard])?
    /// The split you made, awaiting your opponent's decision. Fully known to
    /// you; you dealt it.
    ///
    /// Separate from `piles` because when both players split at once there are
    /// two divisions on the table simultaneously, and they are not the same
    /// object seen from two angles: one is yours and complete, the other is
    /// theirs and partly buried.
    public let myPiles: (a: [VisibleCard], b: [VisibleCard])?
    /// The pack in front of THIS player during a draft.
    ///
    /// Deliberately your own pack only. The pack your opponent is looking at
    /// is the one you will be handed next, minus whatever they take from it,
    /// and never seeing it beforehand is what makes their opening pick a
    /// permanent secret.
    public let draftPool: [ScoringCardID]

    /// One split from the round that just ended, as this player may see it.
    public struct ResolvedSplit: Sendable, Equatable {
        /// Who dealt these two piles.
        public let splitter: PlayerID
        public let pileA: [VisibleCard]
        public let pileB: [VisibleCard]
        /// Which pile the chooser took. The splitter kept the other.
        public let taken: PileID
        /// True when this player is the one who made the split.
        public let mine: Bool

        public var kept: PileID { taken.other }
        public func cards(_ pile: PileID) -> [VisibleCard] { pile == .a ? pileA : pileB }
    }

    /// What happened last round, for the recap. Empty before the first round
    /// resolves.
    ///
    /// A card stays hidden here for exactly as long as it stays hidden
    /// everywhere else: if your opponent buried a card and you passed on that
    /// pile, the recap will not tell you what it was either.
    public let lastRound: [ResolvedSplit]

    /// Every split's public outcome for the whole match so far -- draw sizes,
    /// who split, who took which pile, how many cards were buried. Never card
    /// identities, so unlike everything else on this type it is identical for
    /// both players: it is exactly what both of them watched happen live.
    /// Exists so an agent can work out how much of the deck its opponent has
    /// personally drawn through, without being told what any of it was.
    public let splitLog: [SplitRecord]

    public var isMyTurn: Bool { actingPlayer == player }
    public let actingPlayer: PlayerID?

    public static func == (lhs: PlayerView, rhs: PlayerView) -> Bool {
        lhs.player == rhs.player && lhs.phase == rhs.phase && lhs.round == rhs.round
            && lhs.collection == rhs.collection && lhs.opponentCollection == rhs.opponentCollection
            && lhs.hand == rhs.hand && lhs.myRevealed == rhs.myRevealed
            && lhs.opponentRevealed == rhs.opponentRevealed && lhs.unseen == rhs.unseen
            && lhs.currentDraw == rhs.currentDraw
            && lhs.piles?.a == rhs.piles?.a && lhs.piles?.b == rhs.piles?.b
            && lhs.myPiles?.a == rhs.myPiles?.a && lhs.myPiles?.b == rhs.myPiles?.b
    }

    public init(state: GameState, player: PlayerID) {
        self.player = player
        self.config = state.config
        self.phase = state.phase
        self.round = state.round
        self.isFinished = state.isFinished
        self.actingPlayer = state.actingPlayer

        let observed = state.observations[player]

        func visible(_ id: CardID) -> VisibleCard {
            observed.contains(id) ? .known(id, state.type(id)) : .hidden(id)
        }

        let mine = state.collections[player]
        self.collection = mine.map { .known($0, state.type($0)) }
        self.collectionCounts = state.counts(for: player)

        let theirs = state.collections[player.opponent]
        let theirVisible = theirs.map(visible)
        self.opponentCollection = theirVisible
        var knownCounts = MiningCounts()
        var hiddenCount = 0
        for card in theirVisible {
            if let type = card.type { knownCounts[type] += 1 } else { hiddenCount += 1 }
        }
        self.opponentKnownCounts = knownCounts
        self.opponentHiddenCount = hiddenCount

        self.hand = state.hands[player]
        self.myRevealed = state.revealed[player]
        self.draftPool = state.draftPacks[player]
        self.splitLog = state.splitLog
        // Reveals are simultaneous: the opponent's picks stay private until both
        // players have committed, so resolving p1 before p2 in the action
        // sequence leaks nothing.
        let bothCommitted = state.phase != .revealSelection
        self.opponentRevealed = bothCommitted ? state.revealed[player.opponent] : []

        // The unseen pool: full deck composition minus everything observed.
        var observedCounts = MiningCounts()
        for id in observed.cards { observedCounts[state.type(id)] += 1 }
        var pool = MiningCounts()
        for entry in MiningDeck.scaledComposition(to: state.config.deckSize) {
            pool[entry.type] = entry.count
        }
        self.unseen = pool - observedCounts
        self.unseenTotal = self.unseen.total

        // You only ever see your own draw. When both players split at once,
        // the other draw is on the table at the same moment -- and must stay
        // invisible, or simultaneous splitting would hand each player a look
        // at cards they never drew.
        if state.phase == .split {
            self.currentDraw = state.currentDraw[player].map { .known($0, state.type($0)) }
        } else {
            self.currentDraw = []
        }

        // The piles you are choosing from are always the ones your opponent
        // made. You see their face-up cards only, and must decide without
        // knowing what they buried.
        if state.phase == .choose, let split = state.pendingSplits[player.opponent] {
            func pileCards(_ ids: [CardID]) -> [VisibleCard] {
                ids.map { id in
                    split.faceDown.contains(id) ? .hidden(id) : .known(id, state.type(id))
                }
            }
            self.piles = (pileCards(split.pileA), pileCards(split.pileB))
        } else {
            self.piles = nil
        }

        if let outcome = state.lastRound {
            var resolved: [ResolvedSplit] = []
            // Seat order, so the recap reads the same on both devices.
            for splitter in [PlayerID.p1, .p2] {
                guard let split = outcome.splits[splitter],
                      let taken = outcome.taken[splitter.opponent] else { continue }
                let isMine = splitter == player
                let iChose = splitter.opponent == player
                func pileCards(_ ids: [CardID], _ pile: PileID) -> [VisibleCard] {
                    ids.map { id in
                        // Your own split is entirely yours to see. Otherwise a
                        // buried card is visible only if you ended up holding
                        // it -- which is the same rule that governed the choice.
                        let claimed = iChose && pile == taken
                        if isMine || claimed || !split.faceDown.contains(id) {
                            return .known(id, state.type(id))
                        }
                        return .hidden(id)
                    }
                }
                resolved.append(ResolvedSplit(
                    splitter: splitter,
                    pileA: pileCards(split.pileA, .a),
                    pileB: pileCards(split.pileB, .b),
                    taken: taken,
                    mine: isMine
                ))
            }
            self.lastRound = resolved
        } else {
            self.lastRound = []
        }

        if state.phase == .choose, let mine = state.pendingSplits[player] {
            func known(_ ids: [CardID]) -> [VisibleCard] {
                ids.map { .known($0, state.type($0)) }
            }
            self.myPiles = (known(mine.pileA), known(mine.pileB))
        } else {
            self.myPiles = nil
        }
    }

    /// Probability-weighted composition of a single unseen card, as counts.
    /// Agents use this to value a face-down card without seeing it.
    public var unseenDistribution: [(type: MiningType, probability: Double)] {
        let total = unseenTotal
        guard total > 0 else { return [] }
        return MiningType.allCases.map { ($0, Double(unseen[$0]) / Double(total)) }
    }
}

extension GameState {
    public func view(for player: PlayerID) -> PlayerView {
        PlayerView(state: self, player: player)
    }
}
