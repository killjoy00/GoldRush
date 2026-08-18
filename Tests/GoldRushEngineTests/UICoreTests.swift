import Testing
@testable import GoldRushEngine
@testable import GoldRushUICore

/// The split screen's rules live in `SplitBuilder` rather than in a SwiftUI
/// view, so they can be tested here. On this project the app target is built
/// only by CI, which makes every line kept out of a `View` a line that actually
/// gets verified.
@Suite("Split builder")
struct SplitBuilderTests {

    static func sampleDraw(_ n: Int) -> [(id: CardID, type: MiningType)] {
        (0..<n).map { (CardID(UInt16($0)), MiningType.allCases[$0 % MiningType.allCases.count]) }
    }

    @Test("A fresh builder starts with everything in one pile and is illegal")
    func startsIllegal() {
        let builder = SplitBuilder(draw: Self.sampleDraw(7), requiredFaceDown: 1)
        #expect(builder.pileA.count == 7)
        #expect(builder.pileB.isEmpty)
        #expect(!builder.isLegal)
        #expect(builder.action == nil)
        // Both reasons are reported at once, so the screen can guide rather than
        // reveal problems one at a time.
        #expect(builder.problems.contains(.pileEmpty(.b)))
        #expect(builder.problems.contains(.wrongFaceDownCount(required: 1, placed: 0)))
    }

    @Test("Moving a card and facing one down makes the split legal")
    func becomesLegal() {
        let draw = Self.sampleDraw(7)
        let builder = SplitBuilder(draw: draw, requiredFaceDown: 1)
        builder.move(draw[0].id, to: .b)
        #expect(!builder.isLegal)
        builder.toggleFaceDown(draw[3].id)
        #expect(builder.isLegal)

        let action = try! #require(builder.action)
        guard case .split(let a, let b, let faceDown) = action else {
            Issue.record("expected a split action")
            return
        }
        #expect(a.count == 6)
        #expect(b == [draw[0].id])
        #expect(faceDown == [draw[3].id])
    }

    @Test("A card lives in exactly one pile no matter how often it is moved")
    func movesAreExclusive() {
        let draw = Self.sampleDraw(7)
        let builder = SplitBuilder(draw: draw, requiredFaceDown: 1)
        builder.move(draw[0].id, to: .b)
        builder.move(draw[0].id, to: .b)
        builder.move(draw[1].id, to: .b)
        builder.move(draw[0].id, to: .a)

        #expect(builder.pileA.count { $0 == draw[0].id } == 1)
        #expect(!builder.pileB.contains(draw[0].id))
        #expect(builder.pileA.count + builder.pileB.count == 7)
        #expect(Set(builder.pileA + builder.pileB).count == 7)
    }

    @Test("Face-down toggling is reversible and order-independent")
    func faceDownToggling() {
        let draw = Self.sampleDraw(9)
        let builder = SplitBuilder(draw: draw, requiredFaceDown: 2)
        builder.toggleFaceDown(draw[4].id)
        builder.toggleFaceDown(draw[2].id)
        #expect(builder.faceDownCount == 2)
        // Always ascending, never dependent on insertion order or hashing.
        #expect(builder.faceDown == [draw[2].id, draw[4].id])

        builder.toggleFaceDown(draw[4].id)
        #expect(builder.faceDownCount == 1)
        #expect(builder.faceDown == [draw[2].id])
    }

    @Test("Too many face-down cards is reported, not silently accepted")
    func tooManyFaceDown() {
        let draw = Self.sampleDraw(7)
        let builder = SplitBuilder(draw: draw, requiredFaceDown: 1)
        builder.move(draw[0].id, to: .b)
        builder.toggleFaceDown(draw[1].id)
        builder.toggleFaceDown(draw[2].id)
        #expect(!builder.isLegal)
        #expect(builder.problems.contains(.wrongFaceDownCount(required: 1, placed: 2)))
        #expect(builder.action == nil)
    }

    @Test("A fully face-down pile is buildable, since the rules allow it")
    func fullyFaceDownPile() {
        let draw = Self.sampleDraw(7)
        let builder = SplitBuilder(draw: draw, requiredFaceDown: 1)
        builder.move(draw[0].id, to: .b)
        builder.toggleFaceDown(draw[0].id)
        #expect(builder.isLegal)
        #expect(builder.faceDownCount(in: .b) == 1)
        #expect(builder.visibleCounts(.b).total == 0)
    }

    @Test("Unknown cards are ignored rather than corrupting the split")
    func unknownCardsIgnored() {
        let draw = Self.sampleDraw(7)
        let builder = SplitBuilder(draw: draw, requiredFaceDown: 1)
        builder.move(CardID(999), to: .b)
        builder.toggleFaceDown(CardID(999))
        #expect(builder.pileB.isEmpty)
        #expect(builder.faceDownCount == 0)
    }

    @Test("Reset restores the opening arrangement")
    func reset() {
        let draw = Self.sampleDraw(7)
        let builder = SplitBuilder(draw: draw, requiredFaceDown: 1)
        builder.move(draw[0].id, to: .b)
        builder.toggleFaceDown(draw[1].id)
        builder.reset()
        #expect(builder.pileA.count == 7)
        #expect(builder.pileB.isEmpty)
        #expect(builder.faceDownCount == 0)
    }

    @Test("Visible counts exclude face-down cards, matching what an opponent sees")
    func visibleCountsHideFaceDownCards() {
        let draw: [(id: CardID, type: MiningType)] = [
            (CardID(0), .goldNugget), (CardID(1), .goldNugget), (CardID(2), .quartz),
        ]
        let builder = SplitBuilder(draw: draw, requiredFaceDown: 1)
        builder.move(CardID(2), to: .b)
        builder.toggleFaceDown(CardID(0))

        #expect(builder.visibleCounts(.a).goldNugget == 1)
        #expect(builder.visibleCounts(.a).total == 1)
        #expect(builder.faceDownCount(in: .a) == 1)
        #expect(builder.visibleCounts(.b).quartz == 1)
    }

    @Test("A builder made from a live game matches that round's requirements")
    func builtFromLiveGame() {
        var state = GameState.newGame(seed: 4242)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))
        #expect(state.phase == .split)

        let splitter = state.config.splitter(round: state.round)
        let builder = SplitBuilder(view: state.view(for: splitter))
        #expect(builder.draw.count == 7)
        #expect(builder.requiredFaceDown == 1)

        builder.move(builder.draw[0].id, to: .b)
        builder.toggleFaceDown(builder.draw[1].id)
        let action = try! #require(builder.action)
        // The engine must agree the builder produced something legal.
        #expect(state.isLegal(action))
    }
}
