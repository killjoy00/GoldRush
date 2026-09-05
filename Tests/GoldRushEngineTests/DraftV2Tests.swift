import Foundation
import Testing
@testable import GoldRushEngine
@testable import GoldRushAgents

@Suite("Eight-card scoring draft")
struct DraftV2Tests {
    @Test("New drafts open two distinct packs of eight")
    func opensEight() {
        let state = GameState.newGame(config: GameConfig(scoringDraft: true), seed: 0xD8A7)
        #expect(state.phase == .draft)
        #expect(state.draftPacks.p1.count == 8)
        #expect(state.draftPacks.p2.count == 8)
        #expect(Set(state.draftPacks.p1).isDisjoint(with: Set(state.draftPacks.p2)))
        #expect(Set(state.draftPacks.p1 + state.draftPacks.p2).count == 16)
    }

    @Test("Opening burn stays sealed until both players commit")
    func openingBurnIsSimultaneous() throws {
        var state = GameState.newGame(config: GameConfig(scoringDraft: true), seed: 0xB0A7)
        let p1 = state.draftPacks.p1
        state = state.apply(.draftOpen(keep: p1[0], discard: p1[1]))

        #expect(state.phase == .draft)
        #expect(state.actingPlayer == .p2)
        #expect(state.draftDiscarded.p1 == nil)
        #expect(state.draftDiscarded.p2 == nil)
        #expect(state.view(for: .p2).draftDiscarded.p1 == nil)

        let p2 = state.draftPacks.p2
        let p2Discard = p2[1]
        state = state.apply(.draftOpen(keep: p2[0], discard: p2Discard))

        #expect(state.draftDiscarded.p1 == p1[1])
        #expect(state.draftDiscarded.p2 == p2Discard)
        #expect(state.view(for: .p1).draftDiscarded.p2 == p2Discard)
        #expect(state.draftPacks.p1.count == 6)
        #expect(state.draftPacks.p2.count == 6)
    }

    @Test("Draft follows 8-6-5-4-3-2 and finishes with six kept cards")
    func exactDraftFlow() throws {
        var state = GameState.newGame(config: GameConfig(scoringDraft: true), seed: 0x86_5432)
        let openingP1 = state.draftPacks.p1[0]
        let openingP2 = state.draftPacks.p2[0]

        func submitPair(_ action: (GameState, PlayerID) -> Action) {
            let first = state.actingPlayer!
            state = state.apply(action(state, first))
            let second = state.actingPlayer!
            state = state.apply(action(state, second))
        }

        submitPair { current, actor in
            let pack = current.draftPacks[actor]
            return .draftOpen(keep: pack[0], discard: pack[1])
        }
        #expect(state.hands.p1.count == 1 && state.hands.p2.count == 1)
        #expect(state.draftPacks.p1.count == 6 && state.draftPacks.p2.count == 6)

        for (packCount, handCount) in [(6, 2), (5, 3), (4, 4), (3, 5)] {
            #expect(state.draftPacks.p1.count == packCount)
            #expect(state.draftPacks.p2.count == packCount)
            submitPair { current, actor in .draftPick(current.draftPacks[actor][0]) }
            #expect(state.hands.p1.count == handCount && state.hands.p2.count == handCount)
            #expect(state.draftPacks.p1.count == packCount - 1)
            #expect(state.draftPacks.p2.count == packCount - 1)
        }

        #expect(state.draftPacks.p1.count == 2 && state.draftPacks.p2.count == 2)
        submitPair { current, actor in
            let pack = current.draftPacks[actor]
            return .draftClose(keep: pack[0], discard: pack[1])
        }

        #expect(state.phase == .split)
        #expect(state.hands.p1.count == GameConfig.handSize)
        #expect(state.hands.p2.count == GameConfig.handSize)
        #expect(state.draftPacks.p1.isEmpty && state.draftPacks.p2.isEmpty)
        #expect(state.hands.p1.contains(openingP1))
        #expect(state.hands.p2.contains(openingP2))
        #expect(state.draftFirstPick.p1 == openingP1)
        #expect(state.draftFirstPick.p2 == openingP2)
        #expect(state.revealed.p1.count == 5 && state.revealed.p2.count == 5)
        #expect(!state.revealed.p1.contains(openingP1))
        #expect(!state.revealed.p2.contains(openingP2))

        let burns = try #require(state.draftDiscards)
        #expect(burns.p1.count == 2 && burns.p2.count == 2)
        let accounted = state.hands.p1 + state.hands.p2 + burns.p1 + burns.p2
        #expect(accounted.count == GameConfig.draftOpeningPoolSize)
        #expect(Set(accounted).count == GameConfig.draftOpeningPoolSize)
    }

    @Test("Seven-card saved draft without v2 keys can finish")
    func legacySavedDraftResumes() throws {
        let modern = GameState.newGame(config: GameConfig(scoringDraft: true), seed: 0x01D7)
        let encoded = try JSONEncoder().encode(modern)
        var root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        // Recreate the shape written by the previous app: two seven-card packs
        // and none of the optional fields introduced with Draft V2/Claim Journal.
        var packs = try #require(root["draftPacks"] as? [String: Any])
        for seat in ["p1", "p2"] {
            var pack = try #require(packs[seat] as? [Any])
            #expect(pack.count == 8)
            pack.removeLast()
            packs[seat] = pack
        }
        root["draftPacks"] = packs
        root.removeValue(forKey: "draftLegacyMode")
        root.removeValue(forKey: "draftDiscards")
        root.removeValue(forKey: "draftPendingDiscard")
        root.removeValue(forKey: "roundHistory")

        let oldData = try JSONSerialization.data(withJSONObject: root)
        var state = try JSONDecoder().decode(GameState.self, from: oldData)
        #expect(state.phase == .draft)
        #expect(state.draftPacks.p1.count == 7 && state.draftPacks.p2.count == 7)

        for _ in 0..<7 {
            let p1Card = try #require(state.draftPacks.p1.first)
            state = state.apply(.draftPick(p1Card))
            let p2Card = try #require(state.draftPacks.p2.first)
            state = state.apply(.draftPick(p2Card))
        }

        #expect(state.phase == .draftDiscard)
        #expect(state.hands.p1.count == 7 && state.hands.p2.count == 7)
        #expect(state.draftPacks.p1.isEmpty && state.draftPacks.p2.isEmpty)
    }
}

@Suite("Draft valuation")
struct DraftValuationTests {
    @Test("Reference ensemble contains 30 cards and preserves deck expectation")
    func fullSizeReferenceProfiles() {
        let profiles = GreedyAgent().draftReferenceProfiles()
        #expect(profiles.count == 6)
        #expect(profiles.allSatisfy { $0.total == 30 })

        for entry in MiningDeck.standardComposition {
            let observed = profiles.reduce(0) { $0 + $1[entry.type] }
            // Compare in integer space: average profile count equals
            // entry.count * 30 / 72 exactly across the six-board ensemble.
            #expect(observed * MiningDeck.standardSize == entry.count * 30 * profiles.count)
        }
    }
}

@Suite("Claim Journal")
struct ClaimJournalTests {
    @Test("Journal keeps a declined buried card hidden")
    func preservesHiddenInformation() throws {
        var state = GameState.newGame(seed: 0xC1A1)
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p1.prefix(3))))
        state = state.apply(.selectRevealedScoringCards(Array(state.hands.p2.prefix(3))))
        #expect(state.phase == .split)

        let splitter = try #require(state.actingPlayer)
        #expect(splitter == .p1)
        let draw = state.currentDraw[splitter]
        let buried = draw[0]
        state = state.apply(.split(
            pileA: [buried],
            pileB: Array(draw.dropFirst()),
            faceDown: [buried]
        ))
        state = state.apply(.choose(pile: .b))

        let p2Journal = state.claimJournal(for: .p2)
        #expect(p2Journal.count == 1)
        let split = try #require(p2Journal[0].splits.first)
        #expect(split.splitter == .p1)
        #expect(split.taken == .b)
        let declined = split.cards(.a)
        #expect(declined.count == 1)
        #expect(declined[0].id == buried)
        #expect(declined[0].isHidden)

        // The splitter drew the card and therefore remembers it in full.
        let p1Split = try #require(state.claimJournal(for: .p1)[0].splits.first)
        #expect(p1Split.cards(.a)[0].type == state.type(buried))
    }
}
