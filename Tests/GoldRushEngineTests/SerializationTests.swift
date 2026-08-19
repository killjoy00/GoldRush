import Foundation
import Testing
@testable import GoldRushEngine

/// Remote play carries the whole game between two phones as a blob of bytes.
///
/// These are the guarantees that makes safe: a state encoded on one device and
/// decoded on the other must be the same game, must keep playing identically,
/// and must fit in the transport. Nothing here needs GameKit -- the properties
/// are about `GameState` itself, so they are checked on every platform rather
/// than only when someone runs the app.
@Suite("Serialization for remote play")
struct SerializationTests {

    /// GameKit's per-match payload ceiling. The real limit is 64 KB; staying an
    /// order of magnitude under it means a rules change that grows the state
    /// cannot quietly push a shipped game over the edge.
    static let matchDataLimit = 64 * 1024
    static let comfortableBudget = 16 * 1024

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        // Fixed key order, so the same state always produces the same bytes --
        // which is what lets a client detect "nothing actually changed".
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    @Test("A fresh game round-trips unchanged", arguments: (0..<20).map { UInt64(9000 &+ $0) })
    func freshGameRoundTrips(seed: UInt64) throws {
        let state = GameState.newGame(seed: seed)
        let data = try Self.encoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        #expect(restored == state)
    }

    @Test("A game round-trips unchanged at every phase it can be handed over in",
          arguments: (0..<10).map { UInt64(9100 &+ $0) })
    func roundTripsAtEveryHandoverPoint(seed: UInt64) throws {
        var state = GameState.newGame(seed: seed)
        var rng = SeededRNG(seed: seed &+ 7)
        var checked = 0

        while !state.isFinished {
            // Encode before every single action, since a turn can be handed to
            // the other device at any of these points.
            let data = try Self.encoder().encode(state)
            let restored = try JSONDecoder().decode(GameState.self, from: data)
            #expect(restored == state, "state differed after a round trip in phase \(state.phase)")
            #expect(data.count < Self.comfortableBudget)
            checked += 1

            guard let actor = state.actingPlayer else { break }
            switch state.phase {
            case .revealSelection:
                var hand = state.hands[actor]
                rng.shuffle(&hand)
                state = state.apply(.selectRevealedScoringCards(
                    Array(hand.prefix(state.config.initialRevealCount))))
            case .split:
                let split = PlaythroughHarness.randomLegalSplit(
                    draw: state.currentDraw,
                    faceDownCount: state.config.faceDownCount(round: state.round),
                    rng: &rng)
                state = state.apply(.split(
                    pileA: split.pileA, pileB: split.pileB, faceDown: split.faceDown))
            case .choose:
                state = state.apply(.choose(pile: rng.next(upperBound: 2) == 0 ? .a : .b))
            case .draft, .additionalReveal, .finished:
                break
            }
        }
        #expect(checked > 8, "expected to exercise every round")
    }

    @Test("A decoded game keeps playing identically to the original",
          arguments: (0..<15).map { UInt64(9200 &+ $0) })
    func decodedGameContinuesIdentically(seed: UInt64) throws {
        // This is the property remote play actually depends on: the opponent's
        // device resumes from bytes, and must reach the same result as if the
        // game had never left the first device.
        var original = GameState.newGame(seed: seed)
        original = original.apply(.selectRevealedScoringCards(Array(original.hands.p1.prefix(3))))
        original = original.apply(.selectRevealedScoringCards(Array(original.hands.p2.prefix(3))))

        let data = try Self.encoder().encode(original)
        var restored = try JSONDecoder().decode(GameState.self, from: data)

        var rngA = SeededRNG(seed: seed &+ 11)
        var rngB = SeededRNG(seed: seed &+ 11)

        func step(_ state: GameState, _ rng: inout SeededRNG) -> GameState {
            guard let actor = state.actingPlayer else { return state }
            switch state.phase {
            case .split:
                let split = PlaythroughHarness.randomLegalSplit(
                    draw: state.currentDraw,
                    faceDownCount: state.config.faceDownCount(round: state.round),
                    rng: &rng)
                return state.apply(.split(
                    pileA: split.pileA, pileB: split.pileB, faceDown: split.faceDown))
            case .choose:
                return state.apply(.choose(pile: rng.next(upperBound: 2) == 0 ? .a : .b))
            case .additionalReveal:
                let legal = state.hands[actor].filter { !state.revealed[actor].contains($0) }
                return state.apply(.revealAdditional(legal[rng.next(upperBound: legal.count)]))
            default:
                return state
            }
        }

        while !original.isFinished {
            original = step(original, &rngA)
            restored = step(restored, &rngB)
            #expect(restored == original)
        }
        #expect(restored.scorecard(for: .p1).total == original.scorecard(for: .p1).total)
        #expect(restored.scorecard(for: .p2).total == original.scorecard(for: .p2).total)
        #expect(restored.winner() == original.winner())
    }

    @Test("A finished game stays well inside the transport budget",
          arguments: (0..<20).map { UInt64(9300 &+ $0) })
    func finishedGameFitsInMatchData(seed: UInt64) throws {
        let result = PlaythroughHarness.play(seed: seed)
        let data = try Self.encoder().encode(result.finalState)
        #expect(data.count < Self.comfortableBudget,
                "end-of-game state was \(data.count) bytes")
        #expect(data.count < Self.matchDataLimit / 2)
    }

    @Test("Encoding is stable, so an unchanged state produces identical bytes")
    func encodingIsStable() throws {
        let state = GameState.newGame(seed: 4242)
        let first = try Self.encoder().encode(state)
        let second = try Self.encoder().encode(state)
        #expect(first == second)
    }

    @Test("Corrupt or truncated match data is rejected rather than half-loaded")
    func corruptDataIsRejected() throws {
        let state = GameState.newGame(seed: 77)
        let data = try Self.encoder().encode(state)

        // A truncated payload -- the shape of an interrupted transfer.
        let truncated = data.prefix(data.count / 2)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GameState.self, from: Data(truncated))
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GameState.self, from: Data("not a game".utf8))
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GameState.self, from: Data())
        }
    }
}
