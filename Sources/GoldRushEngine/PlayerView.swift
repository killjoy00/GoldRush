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
    /// The two piles awaiting a choice. Populated during `.choose`.
    public let piles: (a: [VisibleCard], b: [VisibleCard])?
    /// The pack in front of THIS player during a draft.
    ///
    /// Deliberately your own pack only. The pack your opponent is looking at
    /// is the one you will be handed next, minus whatever they take from it,
    /// and never seeing it beforehand is what makes their opening pick a
    /// permanent secret.
    public let draftPool: [ScoringCardID]

    public var isMyTurn: Bool { actingPlayer == player }
    public let actingPlayer: PlayerID?

    public static func == (lhs: PlayerView, rhs: PlayerView) -> Bool {
        lhs.player == rhs.player && lhs.phase == rhs.phase && lhs.round == rhs.round
            && lhs.collection == rhs.collection && lhs.opponentCollection == rhs.opponentCollection
            && lhs.hand == rhs.hand && lhs.myRevealed == rhs.myRevealed
            && lhs.opponentRevealed == rhs.opponentRevealed && lhs.unseen == rhs.unseen
            && lhs.currentDraw == rhs.currentDraw
            && lhs.piles?.a == rhs.piles?.a && lhs.piles?.b == rhs.piles?.b
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

        // Only the splitter drew, so only the splitter sees the draw.
        if state.phase == .split, state.config.splitter(round: state.round) == player {
            self.currentDraw = state.currentDraw.map { .known($0, state.type($0)) }
        } else {
            self.currentDraw = []
        }

        if state.phase == .choose, let split = state.pendingSplit {
            // The splitter knows both piles fully; the chooser sees face-up cards
            // only, and must decide without knowing what is face down.
            let isSplitter = state.config.splitter(round: state.round) == player
            func pileCards(_ ids: [CardID]) -> [VisibleCard] {
                ids.map { id in
                    if isSplitter || !split.faceDown.contains(id) {
                        return .known(id, state.type(id))
                    }
                    return .hidden(id)
                }
            }
            self.piles = (pileCards(split.pileA), pileCards(split.pileB))
        } else {
            self.piles = nil
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
