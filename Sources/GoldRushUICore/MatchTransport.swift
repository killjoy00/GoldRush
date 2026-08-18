import GoldRushEngine

/// Where a player's decisions come from.
///
/// The seam that keeps local, AI and remote play interchangeable. Adding GameKit
/// means adding a conformance, not touching the screens: a view never asks
/// "are we online?", it asks the transport whose turn it is and submits actions
/// through it.
public protocol MatchTransport: AnyObject, Sendable {
    /// Seats controlled by the person holding this device. Two for
    /// pass-and-play, one for AI and remote play.
    var localPlayers: [PlayerID] { get }

    /// Submits an action. The transport is responsible for getting it into the
    /// shared state, however that state is shared.
    func submit(_ action: Action) async throws

    /// Called when the local player should be asked to act.
    var onStateChange: (@Sendable (GameState) -> Void)? { get set }
}

public extension MatchTransport {
    func controlsLocally(_ player: PlayerID) -> Bool {
        localPlayers.contains(player)
    }
}

/// Both seats on one device, with a hand-off curtain between turns.
public final class LocalTransport: MatchTransport, @unchecked Sendable {
    public let localPlayers: [PlayerID] = [.p1, .p2]
    public var onStateChange: (@Sendable (GameState) -> Void)?
    private var state: GameState

    public init(state: GameState) {
        self.state = state
    }

    public func submit(_ action: Action) async throws {
        state = state.apply(action)
        onStateChange?(state)
    }
}

/// One human against an agent.
///
/// The agent runs the same `InferenceAgent` the simulator measured, so the
/// difficulty tiers correspond to strategies with known win rates rather than
/// to invented handicaps.
public final class AgentTransport: MatchTransport, @unchecked Sendable {
    public let localPlayers: [PlayerID]
    public var onStateChange: (@Sendable (GameState) -> Void)?

    private var state: GameState
    private let agentSeat: PlayerID
    private let decide: @Sendable (PlayerView, Phase, inout SeededRNG) -> Action?
    private var rng: SeededRNG

    public init(
        state: GameState,
        humanSeat: PlayerID,
        seed: UInt64,
        decide: @escaping @Sendable (PlayerView, Phase, inout SeededRNG) -> Action?
    ) {
        self.state = state
        self.localPlayers = [humanSeat]
        self.agentSeat = humanSeat.opponent
        self.decide = decide
        self.rng = SeededRNG(seed: seed)
    }

    public func submit(_ action: Action) async throws {
        state = state.apply(action)
        onStateChange?(state)
        await runAgentTurns()
    }

    /// Plays the agent forward until it is the human's turn again.
    public func runAgentTurns() async {
        while !state.isFinished, state.actingPlayer == agentSeat {
            let view = state.view(for: agentSeat)
            guard let action = decide(view, state.phase, &rng) else { break }
            let next = state.apply(action)
            // A no-op means the agent proposed something illegal; stop rather
            // than spin.
            guard next != state else { break }
            state = next
            onStateChange?(state)
        }
    }
}
