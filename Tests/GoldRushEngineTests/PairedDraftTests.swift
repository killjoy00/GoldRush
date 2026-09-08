import Foundation
import Testing
@testable import GoldRushEngine
@testable import GoldRushAgents

/// The seven-card paired draft: take one, then two, then two, then keep one
/// and burn one.
@Suite("Paired seven-card draft")
struct PairedDraftTests {
    private var config: GameConfig {
        GameConfig(scoringDraft: true, draftShape: .sevenPaired)
    }

    /// The shape is only worth measuring if it actually terminates with a legal
    /// hand, which is the thing a draft change is most likely to break.
    @Test("A full paired draft leaves both players with six cards")
    func paired_draft_completes() async throws {
        var state = GameState.newGame(config: config, seed: 0xDEAD_BEEF)
        var rng = SeededRNG(seed: 99)
        let agent = GreedyAgent()

        var guardrail = 0
        while state.phase == .draft {
            guardrail += 1
            #expect(guardrail < 40, "the draft did not terminate")
            guard let player = state.actingPlayer else { break }
            let view = state.view(for: player)
            guard let action = agent.draftAction(view, rng: &rng) else { break }
            state = state.apply(action)
        }

        #expect(state.hands.p1.count == GameConfig.handSize)
        #expect(state.hands.p2.count == GameConfig.handSize)
        // One burn each, against two in the eight-card shape.
        #expect(state.draftDiscards?.p1.count == 1)
        #expect(state.draftDiscards?.p2.count == 1)
    }

    /// Fourteen cards leave the pool, not sixteen, and none is dealt twice.
    @Test("A paired draft consumes fourteen distinct scoring cards")
    func paired_draft_uses_fourteen_cards() async throws {
        var state = GameState.newGame(config: config, seed: 7)
        var rng = SeededRNG(seed: 7)
        let agent = GreedyAgent()

        var steps = 0
        while state.phase == .draft {
            steps += 1
            #expect(steps < 40, "the draft did not terminate")
            guard let player = state.actingPlayer else { break }
            let view = state.view(for: player)
            guard let action = agent.draftAction(view, rng: &rng) else { break }
            state = state.apply(action)
        }

        var seen: [ScoringCardID] = []
        seen += state.hands.p1
        seen += state.hands.p2
        seen += state.draftDiscards?.p1 ?? []
        seen += state.draftDiscards?.p2 ?? []
        #expect(seen.count == 14)
        #expect(Set(seen.map(\.index)).count == 14)
    }

    /// The opening pick is the one card the opponent never sees -- the property
    /// the eight-card shape is built around, and one a shape change could
    /// quietly lose.
    @Test("Only the opening pick stays off the reveal list")
    func paired_draft_hides_only_the_opening_pick() async throws {
        var state = GameState.newGame(config: config, seed: 4242)
        var rng = SeededRNG(seed: 4242)
        let agent = GreedyAgent()

        var steps = 0
        while state.phase == .draft {
            steps += 1
            #expect(steps < 40, "the draft did not terminate")
            guard let player = state.actingPlayer else { break }
            let view = state.view(for: player)
            guard let action = agent.draftAction(view, rng: &rng) else { break }
            state = state.apply(action)
        }

        for player in [PlayerID.p1, .p2] {
            let hand = state.hands[player]
            let revealed = state.revealed[player]
            #expect(revealed.count == hand.count - 1)
            let secret = hand.filter { !revealed.contains($0) }
            #expect(secret.count == 1)
        }
    }

    /// A config written before the option existed still decodes.
    @Test("Config without a draftShape key decodes as the shipped shape")
    func config_migrates_from_older_match_data() throws {
        let json = """
        {"scoringDraft":true,"simultaneousSplit":false,"progressiveReveal":false,
         "persistentHiddenCards":true,"motherlodeRounds":true,
         "hiddenPolicy":{"standard":{}},"deckSize":72,"roundCount":8}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GameConfig.self, from: json)
        #expect(decoded.draftShape == .eightSingles)
    }
}
