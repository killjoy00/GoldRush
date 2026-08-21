import Foundation
@testable import GoldRushEngine

/// Drives complete games with random-but-legal choices, recording the facts a
/// property test needs to check afterwards.
///
/// The recorder deliberately tracks hidden cards from OUTSIDE the engine, so the
/// assertions about what a player may know are independent of the engine's own
/// bookkeeping rather than a restatement of it.
struct PlaythroughHarness {
    struct RoundRecord {
        let round: Int
        let splitter: PlayerID
        let chooser: PlayerID
        let drawn: [CardID]
        let pileA: [CardID]
        let pileB: [CardID]
        let faceDown: [CardID]
        let takenPile: PileID
        /// Face-down cards that went to the splitter, so the chooser never saw them.
        let hiddenFromChooser: [CardID]
    }

    struct Result {
        let finalState: GameState
        let rounds: [RoundRecord]
        let actions: [Action]
    }

    static func randomLegalSplit(
        draw: [CardID],
        faceDownCount: Int,
        rng: inout SeededRNG
    ) -> (pileA: [CardID], pileB: [CardID], faceDown: [CardID]) {
        var shuffled = draw
        rng.shuffle(&shuffled)
        // Both piles need at least one card.
        let cut = 1 + rng.next(upperBound: max(1, shuffled.count - 1))
        let pileA = Array(shuffled[..<cut])
        let pileB = Array(shuffled[cut...])

        var candidates = draw
        rng.shuffle(&candidates)
        let faceDown = Array(candidates.prefix(faceDownCount))
        return (pileA, pileB, faceDown)
    }

    static func play(config: GameConfig = .standard, seed: UInt64) -> Result {
        var state = GameState.newGame(config: config, seed: seed)
        var rng = SeededRNG(seed: seed &+ 0xABCD_EF01)
        var rounds: [RoundRecord] = []
        var actions: [Action] = []

        var guardRail = 0
        while !state.isFinished {
            guardRail += 1
            precondition(guardRail < 500, "game failed to terminate")

            guard let actor = state.actingPlayer else { break }

            switch state.phase {
            case .draft:
                let legal = state.draftPacks[actor].filter { candidate in
                    state.hands[actor].count { $0.family == candidate.family } < GameConfig.familyCap
                }
                let pick = legal[rng.next(upperBound: legal.count)]
                let action = Action.draftPick(pick)
                actions.append(action)
                state = state.apply(action)

            case .revealSelection:
                var hand = state.hands[actor]
                rng.shuffle(&hand)
                let action = Action.selectRevealedScoringCards(
                    Array(hand.prefix(config.initialRevealCount))
                )
                actions.append(action)
                state = state.apply(action)

            case .additionalReveal:
                let remaining = state.hands[actor].filter { !state.revealed[actor].contains($0) }
                let action = Action.revealAdditional(remaining[rng.next(upperBound: remaining.count)])
                actions.append(action)
                state = state.apply(action)

            case .split:
                let draw = state.currentDraw[actor]
                let split = randomLegalSplit(
                    draw: draw,
                    faceDownCount: config.faceDownCount(round: state.round),
                    rng: &rng
                )
                let action = Action.split(
                    pileA: split.pileA, pileB: split.pileB, faceDown: split.faceDown
                )
                actions.append(action)
                state = state.apply(action)

            case .choose:
                // You always choose from the split your opponent made, whether
                // splitting alternates or happens simultaneously.
                let chooser = actor
                let splitter = actor.opponent
                guard let pending = state.pendingSplits[splitter] else { break }
                let round = state.round
                let taken: PileID = rng.next(upperBound: 2) == 0 ? .a : .b
                let drawnThisRound = pending.pileA + pending.pileB
                let leftBehind = pending.pile(taken.other)
                let hiddenFromChooser = leftBehind.filter { pending.faceDown.contains($0) }

                rounds.append(RoundRecord(
                    round: round,
                    splitter: splitter,
                    chooser: chooser,
                    drawn: drawnThisRound,
                    pileA: pending.pileA,
                    pileB: pending.pileB,
                    faceDown: pending.faceDown.cards,
                    takenPile: taken,
                    hiddenFromChooser: hiddenFromChooser
                ))

                let action = Action.choose(pile: taken)
                actions.append(action)
                state = state.apply(action)

            case .finished:
                break
            }
        }

        return Result(finalState: state, rounds: rounds, actions: actions)
    }
}
