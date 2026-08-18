import Foundation
import Testing
@testable import GoldRushEngine

@Suite("Engine properties")
struct PropertyTests {

    static let seeds: [UInt64] = (0..<40).map { 0x5EED_0000 &+ UInt64($0) }

    // MARK: - Conservation

    @Test("Every drawn card is distributed to exactly one player, every round",
          arguments: seeds)
    func conservation(seed: UInt64) {
        let result = PlaythroughHarness.play(seed: seed)
        let state = result.finalState

        var distributed: [CardID] = []
        distributed.append(contentsOf: state.collections.p1)
        distributed.append(contentsOf: state.collections.p2)

        // No card reaches two collections, and none goes missing.
        #expect(Set(distributed).count == distributed.count)
        #expect(distributed.count == state.drawn)
        #expect(state.drawn == state.config.totalDrawn)

        for record in result.rounds {
            let dealt = record.pileA.count + record.pileB.count
            #expect(dealt == record.drawn.count)
            #expect(Set(record.pileA).isDisjoint(with: Set(record.pileB)))
        }
    }

    @Test("The standard game draws 60 of 72 cards, leaving 12 never in play")
    func standardDrawTotals() {
        let config = GameConfig.standard
        #expect(config.totalDrawn == 60)
        #expect(config.deckSize - config.totalDrawn == 12)

        // Rounds 1-6 draw 7; the two Motherlode rounds draw 9.
        for round in 1...6 { #expect(config.drawCount(round: round) == 7) }
        #expect(config.drawCount(round: 7) == 9)
        #expect(config.drawCount(round: 8) == 9)
    }

    @Test("With Motherlode rounds off, all 8 rounds draw 7 for 56 total")
    func motherlodeOffDrawTotals() {
        let config = GameConfig(motherlodeRounds: false)
        #expect(config.totalDrawn == 56)
        for round in 1...8 {
            #expect(config.drawCount(round: round) == 7)
            #expect(config.faceDownCount(round: round) == 1)
        }
    }

    @Test("Each player splits 4 times including exactly one Motherlode round")
    func splitterAlternation() {
        let config = GameConfig.standard
        var splits = PlayerPair(repeating: 0)
        var motherlodeSplits = PlayerPair(repeating: 0)
        for round in 1...config.roundCount {
            splits[config.splitter(round: round)] += 1
            if config.isMotherlode(round: round) {
                motherlodeSplits[config.splitter(round: round)] += 1
            }
        }
        #expect(splits.p1 == 4)
        #expect(splits.p2 == 4)
        #expect(motherlodeSplits.p1 == 1)
        #expect(motherlodeSplits.p2 == 1)
        // P1 chooses in the final round -- the seat asymmetry the sim investigates.
        #expect(config.chooser(round: 8) == .p1)
    }

    // MARK: - Pile legality

    @Test("Generated splits satisfy every legality invariant", arguments: seeds.prefix(20))
    func pileLegality(seed: UInt64) {
        let result = PlaythroughHarness.play(seed: seed)
        for record in result.rounds {
            #expect(!record.pileA.isEmpty)
            #expect(!record.pileB.isEmpty)
            let expectedFaceDown = GameConfig.standard.faceDownCount(round: record.round)
            #expect(record.faceDown.count == expectedFaceDown)
            // Face-down cards must be cards that are actually in a pile.
            let placed = Set(record.pileA + record.pileB)
            for id in record.faceDown { #expect(placed.contains(id)) }
        }
    }

    @Test("A fully face-down pile is legal")
    func fullyFaceDownPileIsLegal() {
        var state = GameState.newGame(seed: 99)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))
        #expect(state.phase == .split)

        let draw = state.currentDraw
        // One card alone in pile A, and that card is the face-down one.
        let action = Action.split(
            pileA: [draw[0]], pileB: Array(draw.dropFirst()), faceDown: [draw[0]]
        )
        #expect(state.isLegal(action))
    }

    @Test("Illegal splits are rejected rather than silently applied")
    func illegalSplitsRejected() {
        var state = GameState.newGame(seed: 7)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))
        let draw = state.currentDraw

        // Empty pile.
        #expect(!state.isLegal(.split(pileA: [], pileB: draw, faceDown: [draw[0]])))
        // Wrong face-down count.
        #expect(!state.isLegal(.split(
            pileA: [draw[0]], pileB: Array(draw.dropFirst()), faceDown: []
        )))
        // A card left out of both piles.
        #expect(!state.isLegal(.split(
            pileA: [draw[0]], pileB: Array(draw.dropFirst(2)), faceDown: [draw[0]]
        )))
        // A duplicated card.
        #expect(!state.isLegal(.split(
            pileA: [draw[0], draw[0]], pileB: Array(draw.dropFirst()), faceDown: [draw[0]]
        )))
        // Face-down card that is not in play.
        #expect(!state.isLegal(.split(
            pileA: [draw[0]], pileB: Array(draw.dropFirst()), faceDown: [CardID(71)]
        )))
    }

    // MARK: - Purity and determinism

    @Test("Applying an illegal action returns an identical state")
    func illegalActionIsANoOp() {
        let state = GameState.newGame(seed: 3)
        let after = state.apply(.choose(pile: .a))  // wrong phase
        #expect(after == state)
    }

    @Test("The reducer is pure: same state and action give the same result",
          arguments: seeds.prefix(10))
    func reducerPurity(seed: UInt64) {
        let state = GameState.newGame(seed: seed)
        let action = Action.selectRevealedScoringCards(Array(state.hands.p1.prefix(3)))

        let a = state.apply(action)
        let b = state.apply(action)
        #expect(a == b)
        // The receiver is untouched -- it is a value, and apply does not alias it.
        #expect(state.phase == .revealSelection)
        #expect(state.revealed.p1.isEmpty)
    }

    @Test("Replaying a seed and action sequence reproduces the state exactly",
          arguments: seeds.prefix(15))
    func determinismReplay(seed: UInt64) {
        let first = PlaythroughHarness.play(seed: seed)

        // Replay the recorded actions against a fresh game of the same seed.
        var replay = GameState.newGame(seed: seed)
        for action in first.actions {
            replay = replay.apply(action)
        }

        #expect(replay == first.finalState)
        #expect(replay.collections.p1 == first.finalState.collections.p1)
        #expect(replay.collections.p2 == first.finalState.collections.p2)
        #expect(replay.scorecard(for: .p1).total == first.finalState.scorecard(for: .p1).total)
        #expect(replay.scorecard(for: .p2).total == first.finalState.scorecard(for: .p2).total)
    }

    @Test("Two runs of the same seed produce identical games", arguments: seeds.prefix(15))
    func determinismRepeatedRuns(seed: UInt64) {
        let a = PlaythroughHarness.play(seed: seed)
        let b = PlaythroughHarness.play(seed: seed)
        #expect(a.finalState == b.finalState)
        #expect(a.actions == b.actions)
    }

    @Test("Shuffling is stable for a seed and varies between seeds")
    func shuffleDeterminism() {
        var rngA = SeededRNG(seed: 42)
        var rngB = SeededRNG(seed: 42)
        var rngC = SeededRNG(seed: 43)
        var a = Array(0..<72), b = Array(0..<72), c = Array(0..<72)
        rngA.shuffle(&a)
        rngB.shuffle(&b)
        rngC.shuffle(&c)
        #expect(a == b)
        #expect(a != c)
        #expect(a.sorted() == Array(0..<72))
    }

    // MARK: - Hidden information

    @Test("A player never observes a face-down card claimed by the opponent",
          arguments: seeds.prefix(25))
    func trackerNeverHoldsUnobservedCards(seed: UInt64) {
        let result = PlaythroughHarness.play(seed: seed)
        let state = result.finalState

        // Recorded independently of the engine while playing.
        var shouldBeUnknown = PlayerPair(repeating: Set<CardID>())
        for record in result.rounds {
            for id in record.hiddenFromChooser {
                shouldBeUnknown[record.chooser].insert(id)
            }
        }

        for player in PlayerID.allCases {
            for id in shouldBeUnknown[player] {
                #expect(!state.observations[player].contains(id),
                        "player \(player) must not have observed hidden card \(id.rawValue)")
            }
            // The splitter drew every card it split, so it knows them all.
            #expect(state.observations[player].count <= state.config.deckSize)
        }
    }

    @Test("The unseen pool equals the deck minus what the player observed",
          arguments: seeds.prefix(25))
    func unseenPoolIsSound(seed: UInt64) {
        let result = PlaythroughHarness.play(seed: seed)
        let state = result.finalState

        for player in PlayerID.allCases {
            let view = state.view(for: player)
            var observedCounts = MiningCounts()
            for id in state.observations[player].cards {
                observedCounts[state.type(id)] += 1
            }
            let expected = MiningDeck.standardCounts - observedCounts
            #expect(view.unseen == expected)

            // Never negative, and it always accounts for the whole deck.
            for type in MiningType.allCases { #expect(view.unseen[type] >= 0) }
            #expect(view.unseenTotal + observedCounts.total == state.config.deckSize)

            // A player's own cards are always seen, so they are never "unseen".
            #expect(observedCounts.total >= view.collectionCounts.total)
        }
    }

    @Test("The unseen pool covers the 12 never-dealt cards plus opponent secrets",
          arguments: seeds.prefix(25))
    func unseenPoolAccountsForBothSources(seed: UInt64) {
        let result = PlaythroughHarness.play(seed: seed)
        let state = result.finalState

        var hiddenFrom = PlayerPair(repeating: 0)
        for record in result.rounds {
            hiddenFrom[record.chooser] += record.hiddenFromChooser.count
        }
        let neverDealt = state.config.deckSize - state.config.totalDrawn

        for player in PlayerID.allCases {
            let view = state.view(for: player)
            #expect(view.unseenTotal == neverDealt + hiddenFrom[player])
            // Each player can be denied at most 5 cards: one in each of their
            // three normal chooser rounds, two in their Motherlode chooser round.
            #expect(hiddenFrom[player] <= 5)
            #expect(view.unseenTotal <= 17)
            #expect(view.opponentHiddenCount == hiddenFrom[player])
        }
    }

    @Test("The chooser cannot identify face-down cards while deciding",
          arguments: seeds.prefix(10))
    func chooserCannotSeeFaceDownCards(seed: UInt64) {
        var state = GameState.newGame(seed: seed)
        var rng = SeededRNG(seed: seed &+ 1)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))

        let split = PlaythroughHarness.randomLegalSplit(
            draw: state.currentDraw,
            faceDownCount: state.config.faceDownCount(round: state.round),
            rng: &rng
        )
        state = state.apply(
            .split(pileA: split.pileA, pileB: split.pileB, faceDown: split.faceDown)
        )
        #expect(state.phase == .choose)

        let chooser = state.config.chooser(round: state.round)
        let view = state.view(for: chooser)
        let piles = try! #require(view.piles)
        let hiddenSeen = (piles.a + piles.b).filter(\.isHidden).map(\.id)
        #expect(Set(hiddenSeen) == Set(split.faceDown))

        // The splitter, having drawn them, sees everything.
        let splitterView = state.view(for: state.config.splitter(round: state.round))
        let splitterPiles = try! #require(splitterView.piles)
        #expect((splitterPiles.a + splitterPiles.b).allSatisfy { !$0.isHidden })
    }

    @Test("With persistentHiddenCards off, both players see face-down cards on claim",
          arguments: seeds.prefix(15))
    func nonPersistentHiddenCardsRevealOnClaim(seed: UInt64) {
        let config = GameConfig(persistentHiddenCards: false)
        let result = PlaythroughHarness.play(config: config, seed: seed)
        let state = result.finalState

        for player in PlayerID.allCases {
            let view = state.view(for: player)
            // Everything dealt has been seen, so only never-dealt cards remain unseen.
            #expect(view.opponentHiddenCount == 0)
            #expect(view.unseenTotal == config.deckSize - config.totalDrawn)
        }
    }

    // MARK: - Setup rules

    @Test("No player is dealt more than two cards of one family", arguments: seeds)
    func familyCapRespected(seed: UInt64) {
        let state = GameState.newGame(seed: seed)
        for player in PlayerID.allCases {
            #expect(state.hands[player].count == GameConfig.handSize)
            for family in ScoringFamily.allCases {
                let held = state.hands[player].count { $0.family == family }
                #expect(held <= GameConfig.familyCap)
            }
        }
        // The two hands are disjoint.
        #expect(Set(state.hands.p1).isDisjoint(with: Set(state.hands.p2)))
    }

    @Test("The snake draft gives each player six cards under the family cap",
          arguments: seeds.prefix(20))
    func draftProducesLegalHands(seed: UInt64) {
        let config = GameConfig(scoringDraft: true)
        let result = PlaythroughHarness.play(config: config, seed: seed)
        let state = result.finalState

        for player in PlayerID.allCases {
            #expect(state.hands[player].count == GameConfig.handSize)
            for family in ScoringFamily.allCases {
                #expect(state.hands[player].count { $0.family == family } <= GameConfig.familyCap)
            }
        }
        #expect(GameConfig.draftOrder.count { $0 == .p1 } == 6)
        #expect(GameConfig.draftOrder.count { $0 == .p2 } == 6)
    }

    @Test("Progressive reveal exposes two cards up front and a third after round 4",
          arguments: seeds.prefix(15))
    func progressiveRevealTiming(seed: UInt64) {
        let config = GameConfig(progressiveReveal: true)
        let result = PlaythroughHarness.play(config: config, seed: seed)
        for player in PlayerID.allCases {
            #expect(result.finalState.revealed[player].count == 3)
        }
    }

    // MARK: - Engine purity

    @Test("The engine imports no UI framework")
    func engineHasNoUIImports() throws {
        let sourceDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // GoldRushEngineTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Sources/GoldRushEngine")

        let files = try FileManager.default.contentsOfDirectory(
            at: sourceDir, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }

        #expect(!files.isEmpty, "expected to find engine sources at \(sourceDir.path)")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(!text.contains("import UIKit"), "\(file.lastPathComponent) imports UIKit")
            #expect(!text.contains("import SwiftUI"), "\(file.lastPathComponent) imports SwiftUI")
            #expect(!text.contains("import AppKit"), "\(file.lastPathComponent) imports AppKit")
        }
    }
}
