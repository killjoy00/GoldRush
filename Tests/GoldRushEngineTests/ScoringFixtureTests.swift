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

    static let fixture1Hand: [ScoringCardID] = [
        ScoringCardID(.strike, 1),   // S1 Rich Vein
        ScoringCardID(.dig, 1),      // D1 Pay Streak
        ScoringCardID(.sluice, 1),   // L1 Wash Plant
        ScoringCardID(.vein, 4),     // V4 Prism
        ScoringCardID(.outfit, 1),   // O1 Full Outfit
        ScoringCardID(.prospect, 6), // P6 Volume Play
    ]

    @Test("Fixture 1 collection totals 31 cards")
    func fixture1Size() {
        #expect(Self.fixture1Counts.total == 31)
    }

    @Test("Fixture 1 scores 97 with both mules allocated as Pan")
    func fixture1Total() {
        let result = Scoring.scoreSolo(counts: Self.fixture1Counts, hand: Self.fixture1Hand)
        #expect(result.total == 97)
        #expect(result.allocation == MuleAllocation(toShovel: 0, toPan: 2))
    }

    @Test("Fixture 1 itemises to the hand-verified breakdown")
    func fixture1Breakdown() {
        let result = Scoring.scoreSolo(counts: Self.fixture1Counts, hand: Self.fixture1Hand)
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
            counts: Self.fixture1Counts, hand: Self.fixture1Hand,
            allocation: MuleAllocation(toShovel: 0, toPan: 2)
        ).total
        let bothShovel = Scoring.score(
            counts: Self.fixture1Counts, hand: Self.fixture1Hand,
            allocation: MuleAllocation(toShovel: 2, toPan: 0)
        ).total
        let oneEach = Scoring.score(
            counts: Self.fixture1Counts, hand: Self.fixture1Hand,
            allocation: MuleAllocation(toShovel: 1, toPan: 1)
        ).total

        #expect(bothPan == 97)
        #expect(bothShovel == 95)
        #expect(oneEach == 96)

        let best = Scoring.scoreSolo(counts: Self.fixture1Counts, hand: Self.fixture1Hand).total
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
        let best = Scoring.scoreSolo(counts: Self.fixture1Counts, hand: Self.fixture1Hand).total
        for candidate in MuleAllocation.candidates(mules: Self.fixture1Counts.packMule) {
            let value = Scoring.score(
                counts: Self.fixture1Counts, hand: Self.fixture1Hand, allocation: candidate
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

    @Test("Scoring deck is 36 cards, 6 families of 6, no duplicate identities")
    func scoringDeckShape() {
        #expect(ScoringCardCatalog.all.count == 36)
        for family in ScoringFamily.allCases {
            let members = ScoringCardCatalog.all.filter { $0.family == family }
            #expect(members.count == 6)
            #expect(Set(members.map(\.id.ordinal)) == Set(1...6))
        }
        #expect(Set(ScoringCardCatalog.all.map(\.id.index)).count == 36)
        // The index table must line up with the identity it claims to store.
        for index in 0..<36 {
            #expect(ScoringCardCatalog.byIndex[index].id.index == index)
        }
    }
}
