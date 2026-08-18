/// How many cards are turned face down each round.
public enum HiddenPolicy: Sendable, Codable, Equatable, Hashable {
    /// One card in a normal round, two in a Motherlode round.
    case standard
    /// A fixed count every round. Exists so `sim hidden` can sweep 0/1/2
    /// independently of the Motherlode toggle.
    case fixed(Int)
}

/// Every rules variant, settable from the CLI so the simulator can A/B them.
public struct GameConfig: Sendable, Codable, Equatable, Hashable {
    /// Replaces the blind deal with a snake draft from a face-up pool of 12.
    public var scoringDraft: Bool
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

    public init(
        scoringDraft: Bool = false,
        progressiveReveal: Bool = false,
        persistentHiddenCards: Bool = true,
        motherlodeRounds: Bool = true,
        hiddenPolicy: HiddenPolicy = .standard,
        deckSize: Int = MiningDeck.standardSize,
        roundCount: Int = 8
    ) {
        self.scoringDraft = scoringDraft
        self.progressiveReveal = progressiveReveal
        self.persistentHiddenCards = persistentHiddenCards
        self.motherlodeRounds = motherlodeRounds
        self.hiddenPolicy = hiddenPolicy
        self.deckSize = deckSize
        self.roundCount = roundCount
    }

    public static let standard = GameConfig()

    // MARK: - Derived round structure

    /// Rounds 7 and 8 are Motherlode rounds when the toggle is on.
    public func isMotherlode(round: Int) -> Bool {
        motherlodeRounds && round >= roundCount - 1
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

    public var totalDrawn: Int {
        (1...roundCount).reduce(0) { $0 + drawCount(round: $1) }
    }

    /// How many scoring cards are public from the start.
    public var initialRevealCount: Int { progressiveReveal ? 2 : 3 }
    /// How many are public by the end.
    public var finalRevealCount: Int { 3 }
    /// Progressive reveal adds its extra card once this round completes.
    public var progressiveRevealAfterRound: Int { 4 }

    public static let handSize = 6
    public static let familyCap = 2
    public static let draftPoolSize = 12

    /// Snake order for the drafted setup: P2,P1,P1,P2,P2,P1,P1,P2,P2,P1,P1,P2.
    public static let draftOrder: [PlayerID] = [
        .p2, .p1, .p1, .p2, .p2, .p1, .p1, .p2, .p2, .p1, .p1, .p2,
    ]
}
