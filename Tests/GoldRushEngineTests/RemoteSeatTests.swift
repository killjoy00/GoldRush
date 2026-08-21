import Testing
@testable import GoldRushEngine
@testable import GoldRushUICore

/// A transport that controls a single seat, the way a remote match does.
/// Records what it was asked to submit so a test can tell whether the view
/// model tried to act for the wrong player.
@MainActor
final class SingleSeatTransport: MatchTransport {
    let localPlayers: [PlayerID]
    var onStateChange: ((GameState) -> Void)?
    private(set) var submitted: [Action] = []

    init(seat: PlayerID) { self.localPlayers = [seat] }

    func submit(_ action: Action) async throws { submitted.append(action) }
}

/// Remote play removes the hand-off curtain, so the only thing keeping one
/// player from seeing the other's board is that the view model refuses to
/// select a seat this device does not control.
///
/// Pass-and-play never exercised this: there, every seat is local. These tests
/// exist because wiring up Game Center turned "both seats are local" from an
/// assumption into a bug.
@Suite("Remote seat isolation")
@MainActor
struct RemoteSeatTests {

    static func startedGame(seed: UInt64) -> GameState {
        var state = GameState.newGame(seed: seed)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))
        return state
    }

    @Test("A remote player only ever views their own seat, whoever is acting",
          arguments: (0..<25).map { UInt64(7700 &+ $0) })
    func viewingPlayerNeverFollowsTheOpponent(seed: UInt64) async {
        // P2's device. Round 1 is P1's split, so it opens on the opponent's turn.
        let state = Self.startedGame(seed: seed)
        #expect(state.config.splitter(round: state.round) == .p1)

        let model = GameViewModel(state: state, transport: SingleSeatTransport(seat: .p2))

        #expect(model.viewingPlayer == .p2, "must not show P1's board on P1's turn")
        #expect(model.view.player == .p2)
        #expect(!model.isLocalTurn)
        // No split builder for a split this device is not making.
        #expect(model.splitBuilder == nil)
    }

    @Test("A remote player cannot act on the opponent's turn",
          arguments: (0..<20).map { UInt64(7800 &+ $0) })
    func cannotActOutOfTurn(seed: UInt64) async {
        let state = Self.startedGame(seed: seed)
        let transport = SingleSeatTransport(seat: .p2)
        let model = GameViewModel(state: state, transport: transport)

        // It is P1's turn to split; P2's device tries anyway.
        let draw = state.currentDraw
        await model.confirmSplit()
        await model.choose(.a)

        #expect(transport.submitted.isEmpty, "submitted an action for a seat it does not control")
        #expect(model.state == state, "state advanced without a legal local action")
        #expect(draw == model.state.currentDraw)
    }

    @Test("Adopting the opponent's move keeps the view on our own seat",
          arguments: (0..<20).map { UInt64(7900 &+ $0) })
    func adoptingRemoteStateKeepsOurSeat(seed: UInt64) async {
        var state = Self.startedGame(seed: seed)
        let model = GameViewModel(state: state, transport: SingleSeatTransport(seat: .p2))

        // P1 splits on their own device; the result arrives here.
        var rng = SeededRNG(seed: seed)
        let split = PlaythroughHarness.randomLegalSplit(
            draw: state.currentDraw[state.actingPlayer ?? .p1],
            faceDownCount: state.config.faceDownCount(round: state.round),
            rng: &rng)
        state = state.apply(.split(
            pileA: split.pileA, pileB: split.pileB, faceDown: split.faceDown))

        model.adopt(state)

        // Now it is P2's turn to choose -- this device may act, and still views P2.
        #expect(model.viewingPlayer == .p2)
        #expect(model.isLocalTurn)
        #expect(model.screen == .choose)

        // The piles it sees must still hide the face-down cards.
        let piles = try! #require(model.view.piles)
        let hidden = (piles.a + piles.b).filter(\.isHidden).map(\.id)
        #expect(Set(hidden) == Set(split.faceDown))
    }

    @Test("A whole remote game never shows either device the wrong seat",
          arguments: (0..<15).map { UInt64(8000 &+ $0) })
    func fullRemoteGameKeepsSeatsSeparate(seed: UInt64) async {
        var state = Self.startedGame(seed: seed)
        let p1 = GameViewModel(state: state, transport: SingleSeatTransport(seat: .p1))
        let p2 = GameViewModel(state: state, transport: SingleSeatTransport(seat: .p2))
        var rng = SeededRNG(seed: seed &+ 3)

        var guardRail = 0
        while !state.isFinished, guardRail < 200 {
            guardRail += 1
            // Both devices always see themselves, all game long.
            #expect(p1.viewingPlayer == .p1)
            #expect(p2.viewingPlayer == .p2)
            #expect(p1.view.player == .p1)
            #expect(p2.view.player == .p2)
            // Exactly one device may act at a time.
            #expect(p1.isLocalTurn != p2.isLocalTurn)

            switch state.phase {
            case .split:
                let split = PlaythroughHarness.randomLegalSplit(
                    draw: state.currentDraw[state.actingPlayer ?? .p1],
                    faceDownCount: state.config.faceDownCount(round: state.round),
                    rng: &rng)
                state = state.apply(.split(
                    pileA: split.pileA, pileB: split.pileB, faceDown: split.faceDown))
            case .choose:
                state = state.apply(.choose(pile: rng.next(upperBound: 2) == 0 ? .a : .b))
            default:
                guard let actor = state.actingPlayer else { return }
                let legal = state.hands[actor].filter { !state.revealed[actor].contains($0) }
                guard !legal.isEmpty else { return }
                state = state.apply(.revealAdditional(legal[0]))
            }
            p1.adopt(state)
            p2.adopt(state)
        }
        #expect(state.isFinished)
    }
}
