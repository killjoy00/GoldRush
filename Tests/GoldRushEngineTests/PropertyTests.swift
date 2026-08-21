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

        let draw = state.currentDraw[state.actingPlayer ?? .p1]
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
        let draw = state.currentDraw[state.actingPlayer ?? .p1]

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
            draw: state.currentDraw[state.actingPlayer ?? .p1],
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

        // The splitter, having drawn them, sees its own division in full --
        // through `myPiles`, since `piles` is what you choose FROM and a
        // splitter is not choosing from its own work.
        let splitterView = state.view(for: state.config.splitter(round: state.round))
        let splitterPiles = try! #require(splitterView.myPiles)
        #expect((splitterPiles.a + splitterPiles.b).allSatisfy { !$0.isHidden })
        // And it is not handed a choice it does not have.
        #expect(splitterView.piles == nil)
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

    @Test("The pack draft gives each player six cards under the family cap",
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
        // Both packs are drafted to nothing; nothing is left over.
        #expect(state.draftPacks.p1.isEmpty)
        #expect(state.draftPacks.p2.isEmpty)
    }

    /// The whole reason the pack draft replaced the shared pool: it hands each
    /// player exactly one permanent unknown without a reveal phase existing.
    @Test("A drafted game leaves each player one secret card and no reveal phase",
          arguments: seeds.prefix(20))
    func draftHidesOnlyTheOpeningPick(seed: UInt64) {
        let config = GameConfig(scoringDraft: true)
        let result = PlaythroughHarness.play(config: config, seed: seed)
        let state = result.finalState

        for player in PlayerID.allCases {
            let first = try! #require(state.draftFirstPick[player])
            // Five of six public, and the one held back is the opening pick.
            #expect(state.revealed[player].count == GameConfig.handSize - 1)
            #expect(!state.revealed[player].contains(first))
            #expect(Set(state.revealed[player]) == Set(state.hands[player]).subtracting([first]))
            // The opponent's view agrees: they see five, not six.
            let theirView = state.view(for: player.opponent)
            #expect(theirView.opponentRevealed.count == GameConfig.handSize - 1)
            #expect(!theirView.opponentRevealed.contains(first))
        }
        // A drafted game never enters reveal selection at all.
        #expect(!result.actions.contains { action in
            if case .selectRevealedScoringCards = action { return true }
            return false
        })
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

    // MARK: - Simultaneous splitting

    /// The simultaneous variant has to be the same game with the waiting taken
    /// out, not a different one. These pin the arithmetic that makes that true.
    @Test("Both players splitting each round deals the same 60 cards over 4 rounds")
    func simultaneousDealsTheSameCards() {
        let config = GameConfig(simultaneousSplit: true)
        #expect(config.roundCount == 4)
        #expect(config.totalDrawn == 60)
        #expect(config.totalDrawn == GameConfig().totalDrawn)

        // Three ordinary rounds then one Motherlode, mirroring 6-then-2.
        #expect(!config.isMotherlode(round: 1))
        #expect(!config.isMotherlode(round: 3))
        #expect(config.isMotherlode(round: 4))
        // And each player still splits four times and chooses four times.
        var splits = PlayerPair(repeating: 0)
        var chooses = PlayerPair(repeating: 0)
        for round in 1...config.roundCount {
            for p in config.splitters(round: round) { splits[p] += 1 }
            for p in config.choosers(round: round) { chooses[p] += 1 }
        }
        #expect(splits.p1 == 4 && splits.p2 == 4)
        #expect(chooses.p1 == 4 && chooses.p2 == 4)
    }

    @Test("A simultaneous game plays through and conserves every card",
          arguments: seeds.prefix(20))
    func simultaneousPlaythrough(seed: UInt64) {
        let config = GameConfig(simultaneousSplit: true)
        let result = PlaythroughHarness.play(config: config, seed: seed)
        let state = result.finalState

        #expect(state.isFinished)
        #expect(state.drawn == 60)
        // Every drawn card ended up with exactly one player.
        let held = state.collections.p1 + state.collections.p2
        #expect(held.count == 60)
        #expect(Set(held).count == 60)
    }

    /// The whole risk of splitting at the same time: if one player can see the
    /// other's division before committing their own, simultaneity is a cheat
    /// rather than a convenience.
    @Test("Neither player can see the other's draw or split before committing",
          arguments: seeds.prefix(20))
    func simultaneousSplitsStaySealed(seed: UInt64) {
        let config = GameConfig(simultaneousSplit: true)
        var state = GameState.newGame(config: config, seed: seed)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))
        #expect(state.phase == .split)

        // While splitting, each player sees their own draw and nothing else.
        for player in PlayerID.allCases {
            let view = state.view(for: player)
            #expect(view.currentDraw.count == 7)
            #expect(Set(view.currentDraw.map(\.id)) == Set(state.currentDraw[player]))
            #expect(view.piles == nil)
            #expect(view.myPiles == nil)
        }
        // The two draws are disjoint -- nobody is splitting the same cards.
        #expect(Set(state.currentDraw.p1).isDisjoint(with: Set(state.currentDraw.p2)))

        // p1 commits first. p2 must still see nothing of it.
        let first = state.actingPlayer!
        let draw = state.currentDraw[first]
        state = state.apply(.split(pileA: [draw[0]], pileB: Array(draw.dropFirst()),
                                   faceDown: [draw[0]]))
        #expect(state.phase == .split)          // still waiting on the other
        let waitingView = state.view(for: first.opponent)
        #expect(waitingView.piles == nil)
        #expect(waitingView.myPiles == nil)
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

/// The face-down rule, stated as the designer states it:
///
///   "The player that splits knows what the card is. The hidden info is only if
///    the splitter puts a card face down and the opponent doesn't pick that
///    card. They shouldn't ever know that card."
///
/// Encoded as a regression test in its own right, because it is the rule the
/// whole hidden-information design rests on. The other property tests sample
/// generated games; this one drives the exact scenario deterministically.
@Suite("The face-down rule")
struct FaceDownRuleTests {

    // MARK: - The round recap

    /// The recap exists so a player can see what their opponent took. It must
    /// not become a back door to the one thing the game promises to keep
    /// secret.
    @Test("The recap never reveals a face-down card the player passed on",
          arguments: PropertyTests.seeds.prefix(25))
    func recapKeepsPassedOverCardsHidden(seed: UInt64) {
        var (state, splitter, chooser, draw) = Self.openingRound(seed: seed)

        // Bury one card in pile B, then have the chooser take pile A.
        let secret = draw[3]
        state = state.apply(.split(
            pileA: draw.filter { $0 != secret }, pileB: [secret], faceDown: [secret]
        ))
        state = state.apply(.choose(pile: .a))

        let chooserView = state.view(for: chooser)
        let recap = try! #require(chooserView.lastRound.first)
        #expect(recap.splitter == splitter)
        #expect(recap.taken == .a)
        #expect(!recap.mine)
        // The buried card sat in the pile they passed on, so it stays hidden.
        let passed = recap.cards(recap.kept)
        #expect(passed.contains { $0.id == secret && $0.isHidden })
        // Everything they actually claimed is legible.
        #expect(recap.cards(recap.taken).allSatisfy { !$0.isHidden })

        // The splitter dealt the cards, so their own recap hides nothing.
        let splitterView = state.view(for: splitter)
        let ownRecap = try! #require(splitterView.lastRound.first)
        #expect(ownRecap.mine)
        #expect((ownRecap.pileA + ownRecap.pileB).allSatisfy { !$0.isHidden })
    }

    @Test("A claimed face-down card is legible in the recap that follows",
          arguments: PropertyTests.seeds.prefix(15))
    func recapShowsCardsYouClaimed(seed: UInt64) {
        var (state, _, chooser, draw) = Self.openingRound(seed: seed)
        let secret = draw[3]
        state = state.apply(.split(
            pileA: draw.filter { $0 != secret }, pileB: [secret], faceDown: [secret]
        ))
        // This time the chooser takes the pile the buried card is in.
        state = state.apply(.choose(pile: .b))

        let recap = try! #require(state.view(for: chooser).lastRound.first)
        #expect(recap.cards(.b).allSatisfy { !$0.isHidden })
    }

    @Test("Splitting together produces a recap of both splits",
          arguments: PropertyTests.seeds.prefix(15))
    func recapCoversBothSplitsWhenSimultaneous(seed: UInt64) {
        let config = GameConfig(simultaneousSplit: true)
        var state = GameState.newGame(config: config, seed: seed)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))

        while state.phase == .split, let actor = state.actingPlayer {
            let draw = state.currentDraw[actor]
            state = state.apply(.split(pileA: [draw[0]], pileB: Array(draw.dropFirst()),
                                       faceDown: [draw[0]]))
        }
        while state.phase == .choose, state.actingPlayer != nil {
            state = state.apply(.choose(pile: .a))
        }

        for player in PlayerID.allCases {
            let recap = state.view(for: player).lastRound
            #expect(recap.count == 2)
            // Exactly one of the two splits is your own.
            #expect(recap.count { $0.mine } == 1)
        }
    }


    /// Sets up a game and hands back the pieces of one fully controlled round.
    static func openingRound(seed: UInt64) -> (state: GameState, splitter: PlayerID, chooser: PlayerID, draw: [CardID]) {
        var state = GameState.newGame(seed: seed)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))
        let round = state.round
        return (state, state.config.splitter(round: round), state.config.chooser(round: round), state.currentDraw[state.config.splitter(round: round)])
    }

    @Test("The chooser never learns a face-down card left in the pile it passed on",
          arguments: (0..<30).map { UInt64(0xFACE_D0 &+ $0) })
    func chooserNeverLearnsThePassedOverCard(seed: UInt64) {
        var (state, splitter, chooser, draw) = Self.openingRound(seed: seed)

        // Put one card face down, and place it in pile B.
        let secret = draw[3]
        let pileB = [draw[3], draw[4]]
        let pileA = draw.filter { !pileB.contains($0) }
        state = state.apply(.split(pileA: pileA, pileB: pileB, faceDown: [secret]))

        // The chooser takes pile A, so the secret goes to the splitter.
        state = state.apply(.choose(pile: .a))

        // The splitter drew it, so of course it knows.
        #expect(state.observations[splitter].contains(secret))

        // The chooser must never know it -- not now, and not at any later point
        // in the game, since nothing reveals it afterwards.
        #expect(!state.observations[chooser].contains(secret))

        let view = state.view(for: chooser)
        // Stronger than "not shown": the identity is absent from the projection,
        // so there is no accessor through which the UI could leak it.
        let entry = view.opponentCollection.first { $0.id == secret }
        #expect(entry != nil, "the chooser can see the opponent HOLDS a card")
        #expect(entry?.type == nil, "but not which card it is")
        #expect(view.opponentHiddenCount >= 1)

        // It stays in the chooser's unseen pool, where it belongs.
        #expect(view.unseen[state.type(secret)] >= 1)
    }

    @Test("The chooser does learn a face-down card it claims itself",
          arguments: (0..<20).map { UInt64(0xC1A1_00 &+ $0) })
    func chooserLearnsTheCardItClaims(seed: UInt64) {
        var (state, _, chooser, draw) = Self.openingRound(seed: seed)

        let secret = draw[3]
        let pileB = [draw[3], draw[4]]
        let pileA = draw.filter { !pileB.contains($0) }
        state = state.apply(.split(pileA: pileA, pileB: pileB, faceDown: [secret]))

        // This time the chooser takes the pile containing the face-down card.
        state = state.apply(.choose(pile: .b))

        #expect(state.observations[chooser].contains(secret))
        let view = state.view(for: chooser)
        #expect(view.collection.contains { $0.id == secret && $0.type != nil })
        // Nothing was hidden from them this round.
        #expect(view.opponentHiddenCount == 0)
    }

    @Test("Nothing later in the game ever reveals a passed-over card",
          arguments: (0..<15).map { UInt64(0x5EA1_ED &+ $0) })
    func secrecyPersistsToTheFinalScore(seed: UInt64) {
        let result = PlaythroughHarness.play(seed: seed)

        // Every card that was face down in a pile the chooser declined.
        var denied = PlayerPair(repeating: [CardID]())
        for record in result.rounds {
            denied[record.chooser].append(contentsOf: record.hiddenFromChooser)
        }

        for player in PlayerID.allCases {
            for card in denied[player] {
                #expect(!result.finalState.observations[player].contains(card),
                        "card \(card.rawValue) leaked to player \(player) by the end of the game")
            }
            // The count of never-identified opponent cards matches exactly what
            // the harness independently recorded as denied.
            let view = result.finalState.view(for: player)
            #expect(view.opponentHiddenCount == denied[player].count)
        }
    }
}
