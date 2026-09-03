import Testing
@testable import GoldRushEngine
@testable import GoldRushAgents

/// `OpponentModel.unseen` used to be a copy of `PlayerView.unseen` -- this
/// player's OWN uncertainty, relabelled as the opponent's. The two agree only
/// on the opening turn; every split after that, whoever drew it sees their
/// whole draw, and the two players' uncertainty about the deck diverges. This
/// is precisely the gap docs/SIM_FINDINGS.md §3 names: "both agents price an
/// unknown card identically."
///
/// `view.splitLog` -- draw sizes, buried counts, who split, which pile was
/// taken, never a card identity -- makes the opponent's seen-COUNT exactly
/// reconstructable from public information, AT THE MOMENT a player is about
/// to decide how to split -- which is the only moment `OpponentModel` is
/// actually built. (Checked at some other, later point, the invariant need
/// not hold: whichever player is mid-draw on the next round has already
/// privately seen it, and the other player has no way to know that yet --
/// which is not a bug, it is the entire mechanic.) These tests pin that the
/// count is exact at the moment that matters, in both round structures.
@Suite("Opponent information model")
struct OpponentModelTests {

    /// Hand-computed, so the numbers in the doc comment above have something
    /// concrete behind them. Checked at the one moment the model is actually
    /// used: right as each player is asked to split, before anything about
    /// that round exists yet.
    @Test("A worked example matches hand-computed totals exactly")
    func handComputedExample() {
        var state = GameState.newGame(seed: 777)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))
        try! #require(state.config.splitter(round: 1) == .p1)

        // Round 1 opens with neither player having seen anything.
        #expect(OpponentModel(view: state.view(for: .p1)).unseen.total == 72)
        #expect(state.view(for: .p2).unseen.total == 72)

        // P1 splits a draw of 7, buries one card into a 2-card pile B; P2
        // takes pile A -- the pile with no face-down card in it, so P2 sees
        // 6 of the 7.
        let draw1 = state.currentDraw.p1
        let pileB1 = [draw1[0], draw1[1]]
        let pileA1 = Array(draw1.dropFirst(2))
        state = state.apply(.split(pileA: pileA1, pileB: pileB1, faceDown: [draw1[0]]))
        state = state.apply(.choose(pile: .a))

        // Round 2: splitting alternates to P2, which begins the instant round
        // 1's choose resolves -- P2 privately sees its own round-2 draw
        // before deciding anything, same as P1 did in round 1. At exactly
        // this moment P1's true unseen is 72-7=65 (its round-1 draw only,
        // nothing about round 2 yet); P2's model of P1 should land on that
        // exactly, using only the public record of round 1.
        #expect(state.config.splitter(round: 2) == .p2)
        #expect(state.view(for: .p1).unseen.total == 72 - 7)
        #expect(OpponentModel(view: state.view(for: .p2)).unseen.total == 72 - 7)

        // What "P1's model of P2" would be is not checked here: P1 has
        // nothing left to decide until round 3 (it already chose in round
        // 1), and `OpponentModel` is only ever built at a split decision --
        // never at a choose. The general property test below covers exactly
        // that moment, in both round structures.
    }

    /// The general property: at the moment a player is about to decide how to
    /// split, its model of the opponent's unseen COUNT exactly matches what
    /// the opponent's own view reports -- across both round structures
    /// (`simultaneousSplit`) and both `persistentHiddenCards` settings, since
    /// the formula branches on both.
    @Test("The opponent's unseen count is exact at every split decision",
          arguments: [true, false].flatMap { split in
              [true, false].flatMap { persist in
                  (0..<15).map { (split, persist, UInt64(0xC0FFEE) &+ $0) }
              }
          })
    func opponentUnseenCountIsExactAtSplitTime(
        _ scenario: (simultaneousSplit: Bool, persistentHiddenCards: Bool, seed: UInt64)
    ) {
        let config = GameConfig(
            simultaneousSplit: scenario.simultaneousSplit,
            persistentHiddenCards: scenario.persistentHiddenCards
        )
        let seed = scenario.seed
        var state = GameState.newGame(config: config, seed: seed)
        var rng = SeededRNG(seed: seed &+ 1)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))

        var guardRail = 0
        while !state.isFinished {
            guardRail += 1
            #expect(guardRail < 500, "game failed to terminate")
            guard let actor = state.actingPlayer else { break }

            switch state.phase {
            case .split:
                // The moment that matters: right before this split is
                // decided, does this player's model of the opponent match
                // the opponent's own reported truth?
                let actorView = state.view(for: actor)
                let opponentTruth = state.view(for: actor.opponent).unseen.total
                #expect(OpponentModel(view: actorView).unseen.total == opponentTruth)

                let draw = state.currentDraw[actor]
                let split = PlaythroughHarness.randomLegalSplit(
                    draw: draw, faceDownCount: config.faceDownCount(round: state.round), rng: &rng
                )
                state = state.apply(.split(pileA: split.pileA, pileB: split.pileB, faceDown: split.faceDown))
            case .choose:
                state = state.apply(.choose(pile: rng.next(upperBound: 2) == 0 ? .a : .b))
            case .draft, .revealSelection, .additionalReveal, .finished:
                break
            }
        }
    }

    /// The composition is an estimate -- which specific cards the opponent
    /// saw while splitting is not public, that is the whole point -- but the
    /// apportionment must sum back to the exact count it was built from
    /// rather than drifting from independent per-type rounding.
    @Test("The composition estimate always sums to the exact count",
          arguments: [false, true], (0..<15).map { UInt64(0xC0FFEE) &+ $0 })
    func compositionSumsToTheExactTotal(simultaneousSplit: Bool, seed: UInt64) {
        let config = GameConfig(simultaneousSplit: simultaneousSplit)
        var state = GameState.newGame(config: config, seed: seed)
        var rng = SeededRNG(seed: seed &+ 1)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))

        var guardRail = 0
        while !state.isFinished {
            guardRail += 1
            #expect(guardRail < 500)
            guard let actor = state.actingPlayer else { break }
            switch state.phase {
            case .split:
                let model = OpponentModel(view: state.view(for: actor))
                let expectedTotal = state.view(for: actor.opponent).unseen.total
                #expect(model.unseen.total == expectedTotal)
                #expect(MiningType.allCases.reduce(0) { $0 + model.unseen[$1] } == model.unseen.total)

                let draw = state.currentDraw[actor]
                let split = PlaythroughHarness.randomLegalSplit(
                    draw: draw, faceDownCount: config.faceDownCount(round: state.round), rng: &rng
                )
                state = state.apply(.split(pileA: split.pileA, pileB: split.pileB, faceDown: split.faceDown))
            case .choose:
                state = state.apply(.choose(pile: rng.next(upperBound: 2) == 0 ? .a : .b))
            case .draft, .revealSelection, .additionalReveal, .finished:
                break
            }
        }
    }
}
