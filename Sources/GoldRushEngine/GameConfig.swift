/// How many cards are turned face down each round.
public enum HiddenPolicy: Sendable, Codable, Equatable, Hashable {
    /// One card in a normal round, two in a Motherlode round.
    case standard
    /// A fixed count every round. Exists so `sim hidden` can sweep 0/1/2
    /// independently of the Motherlode toggle.
    case fixed(Int)
}

/// How the scoring-card draft is shaped.
///
/// A config option rather than a replacement so the simulator can play both
/// and the numbers can decide, which is the only way to answer "is this
/// better" for a rules change.
public enum DraftShape: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    /// Open eight: keep one and burn one face up, pass six, then single picks
    /// down to a final pair where one is kept and one burned. Six decisions
    /// and two burns per player. What every shipped version plays.
    case eightSingles
    /// Open seven: take one and pass, then two, then two, then keep one and
    /// burn one. Four decisions and one burn per player.
    ///
    /// Your own pack comes back to you at four cards, so you learn exactly
    /// which two the opponent took from it -- an information beat the single
    /// picks give up more diffusely.
    case sevenPaired

    /// Cards dealt to each player's opening pack.
    public var openingPackSize: Int {
        switch self {
        case .eightSingles: GameConfig.handSize + 2
        case .sevenPaired: GameConfig.handSize + 1
        }
    }

    /// Pack sizes at which the player takes two cards rather than one.
    public var pairedPackSizes: Set<Int> {
        switch self {
        case .eightSingles: []
        case .sevenPaired: [6, 4]
        }
    }
}

/// Every rules variant, settable from the CLI so the simulator can A/B them.
public struct GameConfig: Sendable, Codable, Equatable, Hashable {
    /// Replaces the blind deal with a two-pack draft. Each player opens eight:
    /// keep one, discard one face up, pass six; then keep/pass down to two,
    /// where one is kept and the other discarded face up. Six cards remain.
    public var scoringDraft: Bool
    /// Both players split their own draw every round and each chooses from the
    /// other's, instead of one player splitting while the other waits.
    ///
    /// Halves the number of turns anyone waits through, which is what makes a
    /// remote game bearable. It is a genuinely different game rather than a
    /// presentation change -- see `roundCount` below -- so it is a toggle the
    /// simulator can A/B rather than a silent rewrite of the rules.
    public var simultaneousSplit: Bool
    /// Reveal 2 at setup, then 1 more after round 4, instead of 3 up front.
    public var progressiveReveal: Bool
    /// When false, face-down cards are revealed to BOTH players on claim.
    public var persistentHiddenCards: Bool
    /// When false, all 8 rounds draw 7 (56 drawn instead of 60).
    public var motherlodeRounds: Bool
    public var hiddenPolicy: HiddenPolicy
    /// Total mining deck size. Drawn cards stay constant, so this sets how much
    /// of the deck is never seen -- the quantity `sim deck` studies.
    public var deckSize: Int
    public var roundCount: Int
    /// Only consulted when `scoringDraft` is on.
    public var draftShape: DraftShape

    public init(
        scoringDraft: Bool = false,
        simultaneousSplit: Bool = false,
        progressiveReveal: Bool = false,
        persistentHiddenCards: Bool = true,
        motherlodeRounds: Bool = true,
        hiddenPolicy: HiddenPolicy = .standard,
        deckSize: Int = MiningDeck.standardSize,
        roundCount: Int? = nil,
        draftShape: DraftShape = .sevenPaired
    ) {
        self.draftShape = draftShape
        self.scoringDraft = scoringDraft
        self.simultaneousSplit = simultaneousSplit
        self.progressiveReveal = progressiveReveal
        self.persistentHiddenCards = persistentHiddenCards
        self.motherlodeRounds = motherlodeRounds
        self.hiddenPolicy = hiddenPolicy
        self.deckSize = deckSize
        // Two splits a round instead of one, so half the rounds cover the same
        // ground. Four rounds of two draws is 3x(7+7) + (9+9) = 60 cards, the
        // same 60 the eight-round game deals, and it still gives each player
        // four splits and four choices. Every invariant the sequential game is
        // measured against carries over exactly.
        self.roundCount = roundCount ?? (simultaneousSplit ? 4 : 8)
    }

    /// Decoding that survives match data written before `draftShape` existed.
    ///
    /// A `GameState` travels between devices as GameKit `matchData`, so an
    /// online game already in flight was encoded without this key. Synthesised
    /// decoding would reject it outright and strand the match. Absence is not
    /// ambiguous: a game encoded before the option existed was played under
    /// the only shape there was.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scoringDraft = try container.decode(Bool.self, forKey: .scoringDraft)
        simultaneousSplit = try container.decode(Bool.self, forKey: .simultaneousSplit)
        progressiveReveal = try container.decode(Bool.self, forKey: .progressiveReveal)
        persistentHiddenCards = try container.decode(Bool.self, forKey: .persistentHiddenCards)
        motherlodeRounds = try container.decode(Bool.self, forKey: .motherlodeRounds)
        hiddenPolicy = try container.decode(HiddenPolicy.self, forKey: .hiddenPolicy)
        deckSize = try container.decode(Int.self, forKey: .deckSize)
        roundCount = try container.decode(Int.self, forKey: .roundCount)
        draftShape = try container.decodeIfPresent(DraftShape.self, forKey: .draftShape)
            ?? .eightSingles
    }

    public static let standard = GameConfig()

    // MARK: - Derived round structure

    /// The big finish. Two rounds of it when players alternate, one when they
    /// split together -- either way it is the last 18 cards of the 60.
    public func isMotherlode(round: Int) -> Bool {
        guard motherlodeRounds else { return false }
        return simultaneousSplit ? round == roundCount : round >= roundCount - 1
    }

    /// 7 normally, 9 in a Motherlode round. Independent of `deckSize`.
    public func drawCount(round: Int) -> Int {
        isMotherlode(round: round) ? 9 : 7
    }

    /// The specification ties the face-down count to the Motherlode rounds but
    /// does not say what happens when they are switched off. Adopted: a normal
    /// round faces down one card, so an all-normal game faces down one per round.
    public func faceDownCount(round: Int) -> Int {
        switch hiddenPolicy {
        case .standard:
            return isMotherlode(round: round) ? 2 : 1
        case .fixed(let n):
            // Never face down more than the pile can spare -- both piles need a card.
            return max(0, min(n, drawCount(round: round) - 1))
        }
    }

    /// P1 splits odd rounds. With 8 rounds that gives each player 4 splits and
    /// exactly one Motherlode split, and leaves P1 choosing in the final round.
    public func splitter(round: Int) -> PlayerID {
        round.isMultiple(of: 2) ? .p2 : .p1
    }

    public func chooser(round: Int) -> PlayerID {
        splitter(round: round).opponent
    }

    /// Everyone who draws and splits this round. Both players when splitting is
    /// simultaneous; just the round's splitter when it alternates.
    public func splitters(round: Int) -> [PlayerID] {
        simultaneousSplit ? [.p1, .p2] : [splitter(round: round)]
    }

    /// Everyone who takes a pile this round. You always choose from the split
    /// your opponent made, so this is exactly the opponents of `splitters`.
    public func choosers(round: Int) -> [PlayerID] {
        splitters(round: round).map(\.opponent)
    }

    public var totalDrawn: Int {
        (1...roundCount).reduce(0) { $0 + drawCount(round: $1) * splitters(round: $1).count }
    }

    /// How many scoring cards are public from the start.
    public var initialRevealCount: Int { progressiveReveal ? 2 : 3 }
    /// How many are public by the end.
    public var finalRevealCount: Int { 3 }
    /// Progressive reveal adds its extra card once this round completes: the
    /// midpoint, whichever round structure is in play.
    public var progressiveRevealAfterRound: Int { roundCount / 2 }

    public static let handSize = 6

    /// The live draft. Each player opens eight cards, removes two immediately
    /// (one kept, one face-up discard), passes six, and eventually receives a
    /// final two-card choice. The opening keep is the one card from that pack
    /// the opponent never gets to see.
    public static let draftOpeningPackSize = handSize + 2
    public static let draftOpeningPoolSize = draftOpeningPackSize * 2
    public static let draftDiscardsPerPlayer = 2

    // MARK: Legacy draft compatibility
    // Retained so already-saved seven-card draft states and older deterministic
    // harnesses still decode and can finish. New games do not use these sizes.
    public static let draftPackSize = handSize + 1
    public static let draftPoolSize = draftPackSize * 2
    public static let draftDiscardCount = draftPackSize - handSize
}
