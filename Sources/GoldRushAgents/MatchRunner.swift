import GoldRushEngine

public struct MatchResult: Sendable {
    public let winner: PlayerID
    public let scores: PlayerPair<Int>
    public let scorecards: PlayerPair<Scorecard>
    public let finalState: GameState
    /// Which scoring cards each player held, for per-card attribution.
    public let hands: PlayerPair<[ScoringCardID]>
    /// How many cards each player finished without ever identifying.
    public let unseenAtEnd: PlayerPair<Int>

    public var margin: Int { scores.p1 - scores.p2 }
}

/// Drives a complete game between two agents.
///
/// The runner is the only place that touches `GameState` directly. Agents see
/// `PlayerView` and nothing else, so a bug here cannot leak information into a
/// strategy -- the projection is applied before an agent is ever consulted.
public enum MatchRunner {

    public static func play(
        config: GameConfig = .standard,
        seed: UInt64,
        p1: any GameAgent,
        p2: any GameAgent
    ) -> MatchResult {
        var state = GameState.newGame(config: config, seed: seed)
        // A stream distinct from the deal, so agent randomness cannot correlate
        // with the shuffle it is reacting to.
        var rng = SeededRNG.derive(base: seed, index: 0x5A17)

        func agent(_ player: PlayerID) -> any GameAgent {
            player == .p1 ? p1 : p2
        }

        var guardRail = 0
        while !state.isFinished {
            guardRail += 1
            precondition(guardRail < 500, "game failed to terminate")
            guard let actor = state.actingPlayer else { break }

            let view = state.view(for: actor)
            let acting = agent(actor)

            switch state.phase {
            case .draft:
                let legal = view.draftPool.filter { candidate in
                    view.hand.count { $0.family == candidate.family } < GameConfig.familyCap
                }
                guard !legal.isEmpty else {
                    preconditionFailure("draft reached a state with no legal pick")
                }
                let pick = acting.draftPick(view, legal: legal, rng: &rng)
                state = state.apply(.draftPick(pick))

            case .revealSelection:
                let picks = acting.selectReveal(view, count: config.initialRevealCount, rng: &rng)
                state = state.apply(.selectRevealedScoringCards(picks))

            case .additionalReveal:
                let legal = view.hand.filter { !view.myRevealed.contains($0) }
                let pick = acting.revealAdditional(view, legal: legal, rng: &rng)
                state = state.apply(.revealAdditional(pick))

            case .split:
                let decision = acting.split(view, rng: &rng)
                let action = Action.split(
                    pileA: decision.pileA, pileB: decision.pileB, faceDown: decision.faceDown
                )
                // An agent that proposes an illegal split would otherwise no-op
                // and spin forever. Fail loudly instead: that is a strategy bug.
                precondition(state.isLegal(action), "\(acting.name) proposed an illegal split")
                state = state.apply(action)

            case .choose:
                let pile = acting.choose(view, rng: &rng)
                state = state.apply(.choose(pile: pile))

            case .finished:
                break
            }
        }

        let cards = PlayerPair(
            p1: state.scorecard(for: .p1),
            p2: state.scorecard(for: .p2)
        )
        return MatchResult(
            winner: state.winner(),
            scores: PlayerPair(p1: cards.p1.total, p2: cards.p2.total),
            scorecards: cards,
            finalState: state,
            hands: state.hands,
            unseenAtEnd: PlayerPair(
                p1: state.view(for: .p1).unseenTotal,
                p2: state.view(for: .p2).unseenTotal
            )
        )
    }
}

/// Builds agents by name, so the CLI can wire them without a switch in six places.
public enum AgentFactory {
    public static let names = [
        "naive", "random", "greedy", "balanced", "maximin",
        "inference", "inference-basic", "inference-placement", "inference-naive-model",
    ]

    public static func make(_ name: String) -> (any GameAgent)? {
        switch name {
        case "naive": NaiveAgent()
        case "balanced": BalancedAgent(sizeSlack: 1)
        case "maximin": BalancedAgent(sizeSlack: 99)
        case "random": RandomAgent()
        case "greedy": GreedyAgent()
        case "inference", "inference-full": InferenceAgent(fidelity: .full)
        case "inference-basic": InferenceAgent(fidelity: .basic)
        case "inference-placement": InferenceAgent(fidelity: .placement)
        // Ablation: the pre-splitLog opponent model. See
        // OpponentModel.init(naiveFrom:) and docs/SIM_FINDINGS.md §12.
        case "inference-naive-model": InferenceAgent(useNaiveOpponentModel: true)
        default: nil
        }
    }
}
