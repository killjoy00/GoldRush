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

/// `AgentTransport` used to run the agent forward only in reaction to a
/// human `submit()`, so nothing ever prompted the agent when the opening move
/// was not the human's: it was not the human's turn, and the human had not
/// submitted anything for the transport to react to. Reported as drafting vs.
/// the AI hanging immediately.
///
/// The `start()` hook fixes it in general rather than for that one setup, and
/// this suite pins the general property -- which is why it seats the human
/// second rather than relying on any particular phase opening on p2.
@MainActor
@Suite("Agent transport")
struct AgentTransportTests {

    /// Always drafts whatever is first in the pool. Real strategy is
    /// GoldRushAgents' concern; this only checks whether the agent gets
    /// asked to act at all.
    nonisolated static func draftsFirstLegalCard(_ view: PlayerView, _ phase: Phase, _ rng: inout SeededRNG) -> Action? {
        guard phase == .draft, let pick = view.draftPool.first else { return nil }
        return .draftPick(pick)
    }

    @Test("The agent opens a game whose first move is not the human's")
    func agentOpensWhenItActsFirst() async {
        // Seat the human second so the opening move belongs to the agent. The
        // original bug was the drafted setup opening on a seat the human did
        // not hold; the pack draft happens to open on p1 now, so this
        // constructs the general case rather than depending on that detail.
        let config = GameConfig(scoringDraft: true)
        let state = GameState.newGame(config: config, seed: 900)
        #expect(state.actingPlayer == .p1)

        let transport = AgentTransport(state: state, humanSeat: .p2, seed: 1, decide: Self.draftsFirstLegalCard)
        let model = GameViewModel(state: state, transport: transport)

        // The kickoff runs on a Task scheduled from init; give it a turn.
        await Task.yield()
        await Task.yield()

        // The agent drafted its opening pick with no human action at all, and
        // play has come round to the human.
        #expect(model.isLocalTurn)
        #expect(model.state.hands.p1.count == 1)
        #expect(model.state.hands.p2.isEmpty)
    }
}
