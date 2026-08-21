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
    /// Replaces the blind deal with a pack draft: two packs of six, passed
    /// back and forth a card at a time.
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

    public init(
        scoringDraft: Bool = false,
        simultaneousSplit: Bool = false,
        progressiveReveal: Bool = false,
        persistentHiddenCards: Bool = true,
        motherlodeRounds: Bool = true,
        hiddenPolicy: HiddenPolicy = .standard,
        deckSize: Int = MiningDeck.standardSize,
        roundCount: Int? = nil
    ) {
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
    public static let familyCap = 2
    public static let draftPoolSize = 12

    /// The drafted setup deals two packs and passes them back and forth: you
    /// look at a pack, take one card, and hand the rest to your opponent.
    ///
    /// The size follows from the hand: two packs of six is twelve cards, each
    /// pack is drafted down to nothing over six passes, and each player ends
    /// with six. It also produces the information structure the game wants for
    /// free -- see `GameState.draftPacks`.
    public static let draftPackSize = handSize
}
