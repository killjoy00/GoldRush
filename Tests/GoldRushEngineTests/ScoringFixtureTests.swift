import Testing
@testable import GoldRushEngine

/// Hand-verified fixtures from the game specification. These are the contract:
/// if a retune of the catalog breaks them, the retune is wrong, not the test.
@Suite("Scoring fixtures")
struct ScoringFixtureTests {

    // MARK: - Fixture 1: the PackMule optimiser

    /// 6 Gold Nugget, 4 Fool's Gold, 5 Gold Ore, 3 Shovel, 5 Gravel, 3 Pan,
    /// 3 Quartz, 2 Pack Mule = 31 cards.
    static let fixture1Counts = MiningCounts(
        goldNugget: 6, foolsGold: 4, goldOre: 5, shovel: 3,
        gravel: 5, pan: 3, quartz: 3, packMule: 2
    )

    /// A frozen snapshot of the original spec's six card definitions, used
    /// instead of the live `ScoringCardCatalog`.
    ///
    /// This fixture's whole purpose is to hand-verify the PackMule optimiser and
    /// the effect evaluator -- not to check today's catalog balance. The
    /// catalog is expected to be re-tuned by the simulator over the life of
    /// this project (P6's Fool's Gold penalty already has been), and if this
    /// fixture read the live catalog, every retune would silently change what
    /// "97" means and the hand-verification would need to be redone by hand
    /// each time. Scoring against a frozen snapshot means a retune can change
    /// what P6 pays in-game without ever touching what this test asserts.
    static let fixture1Cards: [ScoringCard] = [
        ScoringCard(ScoringCardID(.strike, 1), "Rich Vein", "3 per Gold Nugget",
                    [.perType(.goldNugget, points: 3)]),
        ScoringCard(ScoringCardID(.dig, 1), "Pay Streak", "4 per Ore+Shovel set",
                    [.perSet(.oreShovel, points: 4)]),
        ScoringCard(ScoringCardID(.sluice, 1), "Wash Plant",
                    "4 per Gravel+Pan set; -1 per unmatched Gravel",
                    [.perSet(.gravelPan, points: 4), .perUnmatched(.gravel, points: -1)]),
        ScoringCard(ScoringCardID(.vein, 4), "Prism", "Nth Quartz scores 2xN",
                    [.perNthLinear(.quartz, multiplier: 2)]),
        ScoringCard(ScoringCardID(.outfit, 1), "Full Outfit", "2 per Tool",
                    [.perTool(points: 2)]),
        ScoringCard(ScoringCardID(.prospect, 6), "Volume Play",
                    "1 per mining card in collection; -3 per Fool's Gold",
                    [.perTotalMiningCards(points: 1), .perType(.foolsGold, points: -3)]),
    ]

    @Test("Fixture 1 collection totals 31 cards")
    func fixture1Size() {
        #expect(Self.fixture1Counts.total == 31)
    }

    @Test("Fixture 1 scores 97 with both mules allocated as Pan")
    func fixture1Total() {
        let result = Scoring.scoreSolo(counts: Self.fixture1Counts, cards: Self.fixture1Cards)
        #expect(result.total == 97)
        #expect(result.allocation == MuleAllocation(toShovel: 0, toPan: 2))
    }

    @Test("Fixture 1 itemises to the hand-verified breakdown")
    func fixture1Breakdown() {
        let result = Scoring.scoreSolo(counts: Self.fixture1Counts, cards: Self.fixture1Cards)
        var byCard: [String: Int] = [:]
        for card in result.cards { byCard[card.id.code] = card.points }

        #expect(byCard["S1"] == 18)  // 3 x 6 nuggets
        #expect(byCard["D1"] == 12)  // 3 sets x 4
        #expect(byCard["L1"] == 20)  // 5 sets x 4, zero unmatched gravel
        #expect(byCard["V4"] == 12)  // 2 + 4 + 6
        #expect(byCard["O1"] == 16)  // 8 tools x 2
        #expect(byCard["P6"] == 19)  // 31 cards - 3 x 4 fool's gold

        // Both mules serving Pan is what makes L1 pay 5 sets with no leftovers.
        #expect(result.board.gravelPanSets == 5)
        #expect(result.board.unmatched.gravel == 0)
        #expect(result.board.oreShovelSets == 3)
        #expect(result.board.toolCount == 8)
    }

    @Test("Fixture 1 optimiser beats both-as-Shovel and one-each")
    func fixture1OptimiserBeatsAlternatives() {
        let bothPan = Scoring.score(
            counts: Self.fixture1Counts, cards: Self.fixture1Cards,
            allocation: MuleAllocation(toShovel: 0, toPan: 2)
        ).total
        let bothShovel = Scoring.score(
            counts: Self.fixture1Counts, cards: Self.fixture1Cards,
            allocation: MuleAllocation(toShovel: 2, toPan: 0)
        ).total
        let oneEach = Scoring.score(
            counts: Self.fixture1Counts, cards: Self.fixture1Cards,
            allocation: MuleAllocation(toShovel: 1, toPan: 1)
        ).total

        #expect(bothPan == 97)
        #expect(bothShovel == 95)
        #expect(oneEach == 96)

        let best = Scoring.scoreSolo(counts: Self.fixture1Counts, cards: Self.fixture1Cards).total
        #expect(best > bothShovel)
        #expect(best > oneEach)
        #expect(best == bothPan)
    }

    @Test("Fixture 1 optimiser considers every allocation, not a greedy guess")
    func fixture1SearchIsExhaustive() {
        // 2 mules -> (0,0) (0,1) (0,2) (1,0) (1,1) (2,0) = 6 candidates.
        #expect(MuleAllocation.candidates(mules: 2).count == 6)
        #expect(MuleAllocation.candidates(mules: 4).count == 15)

        // No candidate may beat the one the optimiser chose.
        let best = Scoring.scoreSolo(counts: Self.fixture1Counts, cards: Self.fixture1Cards).total
        for candidate in MuleAllocation.candidates(mules: Self.fixture1Counts.packMule) {
            let value = Scoring.score(
                counts: Self.fixture1Counts, cards: Self.fixture1Cards, allocation: candidate
            ).total
            #expect(value <= best)
        }
    }

    // MARK: - Fixture 2: majority riders

    @Test("Fixture 2: S2 pays the rider on a strict Gold Nugget majority")
    func fixture2SureThing() {
        let a = MiningCounts(goldNugget: 7, quartz: 2)
        let b = MiningCounts(goldNugget: 5, quartz: 4)
        let s2 = ScoringCardID(.strike, 2)

        let result = Scoring.score(
            counts: a, hand: [s2], opponentCounts: b, opponentHand: [s2]
        )
        #expect(result.total == 21)  // 2 x 7 = 14, +7 for strictly more
    }

    @Test("Fixture 2: V5 withholds the rider when behind")
    func fixture2VeinRivalry() {
        let a = MiningCounts(goldNugget: 7, quartz: 2)
        let b = MiningCounts(goldNugget: 5, quartz: 4)
        let v5 = ScoringCardID(.vein, 5)

        let result = Scoring.score(
            counts: a, hand: [v5], opponentCounts: b, opponentHand: [v5]
        )
        #expect(result.total == 6)  // 3 x 2 = 6, no bonus: 2 < 4
    }

    @Test("Fixture 2: a tie pays neither player -- strictly more is required")
    func fixture2Tie() {
        let tied = MiningCounts(goldNugget: 5)
        let s2 = ScoringCardID(.strike, 2)

        let a = Scoring.score(counts: tied, hand: [s2], opponentCounts: tied, opponentHand: [s2])
        let b = Scoring.score(counts: tied, hand: [s2], opponentCounts: tied, opponentHand: [s2])
        #expect(a.total == 10)  // 2 x 5, no rider
        #expect(b.total == 10)
    }

    // MARK: - Fixture 3: the effects added for the second wave of cards

    /// `bonusIfAtMost`, `bonusIfExceeds` and `bonusPerTypeWithinMargin` arrived
    /// with S7-P8 and are the only effects no earlier fixture exercises. Each
    /// is checked on both sides of its boundary, because an off-by-one in a
    /// threshold is exactly the sort of thing that scores plausibly forever.
    @Test("O8 pays its bonus at 7 Tools and withholds it at 8")
    func atMostBoundary() {
        let o8 = ScoringCardID(.outfit, 8)
        // 4 Shovel + 3 Pan = 7 Tools: 2 each, plus the 8-point bonus.
        let sevenTools = MiningCounts(shovel: 4, pan: 3)
        #expect(Scoring.scoreSolo(counts: sevenTools, hand: [o8]).total == 22)
        // One more Tool loses the bonus outright, so 8 Tools scores less than 7.
        let eightTools = MiningCounts(shovel: 4, pan: 4)
        #expect(Scoring.scoreSolo(counts: eightTools, hand: [o8]).total == 16)
    }

    @Test("L7 pays its rider only once Gravel leads Pan by 3")
    func exceedsBoundary() {
        let l7 = ScoringCardID(.sluice, 7)
        // 5 Gravel vs 3 Pan is a lead of 2: 16 points, no rider.
        #expect(Scoring.scoreSolo(counts: MiningCounts(gravel: 5, pan: 3), hand: [l7]).total == 16)
        // 6 vs 3 is a lead of 3: 18 points plus the 8-point rider.
        #expect(Scoring.scoreSolo(counts: MiningCounts(gravel: 6, pan: 3), hand: [l7]).total == 26)
    }

    @Test("P8 counts a type as level only while the gap is at most 2")
    func withinMarginBoundary() {
        let p8 = ScoringCardID(.prospect, 8)
        // Gold Nugget 5 v 7 (gap 2, pays) and Quartz 4 v 4 (gap 0, pays).
        // Gold Ore 1 v 5 (gap 4), Gravel and Fool's Gold 0 v 0 (gap 0, pays).
        let mine = MiningCounts(goldNugget: 5, goldOre: 1, quartz: 4)
        let theirs = MiningCounts(goldNugget: 7, goldOre: 5, quartz: 4)
        let result = Scoring.score(counts: mine, hand: [p8], opponentCounts: theirs, opponentHand: [p8])
        #expect(result.total == 28)  // 4 types within 2, at 7 each

        // The comparison is symmetric: widening one gap past 2 costs 7.
        let further = MiningCounts(goldNugget: 8, goldOre: 5, quartz: 4)
        let narrowed = Scoring.score(counts: mine, hand: [p8], opponentCounts: further, opponentHand: [p8])
        #expect(narrowed.total == 21)
    }

    @Test("Every card in the catalog is reachable and scores without trapping")
    func everyCardScores() {
        // The catalog grew from 36 to 48 by way of a parametric card count.
        // This walks all of it, so a family left short or an id that does not
        // round-trip through its own index fails here rather than at a table
        // lookup mid-game.
        let counts = MiningCounts(
            goldNugget: 6, foolsGold: 4, goldOre: 5, shovel: 3,
            gravel: 5, pan: 3, quartz: 3, packMule: 2
        )
        for index in 0..<ScoringCardID.total {
            let id = ScoringCardID.at(index: index)
            #expect(id.index == index)
            #expect(ScoringCardCatalog[id].id == id)
            #expect(!ScoringCardCatalog[id].effects.isEmpty)
            // Both the solo and the opposed path, since comparison riders
            // only evaluate when an opponent board exists.
            _ = Scoring.scoreSolo(counts: counts, hand: [id]).total
            _ = Scoring.score(counts: counts, hand: [id], opponentCounts: counts, opponentHand: [id]).total
        }
    }

    // MARK: - Deck composition

    @Test("Mining deck is exactly 72 cards in the specified proportions")
    func deckComposition() {
        let counts = MiningDeck.standardCounts
        #expect(counts.goldNugget == 14)
        #expect(counts.foolsGold == 10)
        #expect(counts.goldOre == 10)
        #expect(counts.shovel == 8)
        #expect(counts.gravel == 10)
        #expect(counts.pan == 8)
        #expect(counts.quartz == 8)
        #expect(counts.packMule == 4)
        #expect(counts.total == 72)
        #expect(MiningDeck.standardDeck().count == 72)

        // Card IDs are unique and dense.
        let ids = MiningDeck.standardDeck().map(\.id.rawValue).sorted()
        #expect(ids == Array(0..<72).map(UInt16.init))
    }

    @Test("Scoring deck is one full catalog of families, no duplicate identities")
    func scoringDeckShape() {
        #expect(ScoringCardCatalog.all.count == ScoringCardID.total)
        for family in ScoringFamily.allCases {
            let members = ScoringCardCatalog.all.filter { $0.family == family }
            #expect(members.count == ScoringFamily.cardCount)
            #expect(Set(members.map(\.id.ordinal)) == Set(1...ScoringFamily.cardCount))
        }
        #expect(Set(ScoringCardCatalog.all.map(\.id.index)).count == ScoringCardID.total)
        // The index table must line up with the identity it claims to store.
        for index in 0..<ScoringCardID.total {
            #expect(ScoringCardCatalog.byIndex[index].id.index == index)
        }
    }
}
