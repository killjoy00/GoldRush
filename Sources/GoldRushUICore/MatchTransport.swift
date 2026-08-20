import GoldRushEngine

/// Where a player's decisions come from.
///
/// The seam that keeps local, AI and remote play interchangeable. Adding GameKit
/// means adding a conformance, not touching the screens: a view never asks
/// "are we online?", it asks the transport whose turn it is and submits actions
/// through it.
/// Every transport drives the UI and is only ever touched from the view model,
/// which is itself main-actor bound. Saying so on the protocol rather than
/// leaving each conformer to bolt on `@unchecked Sendable` means the compiler
/// checks the threading instead of taking our word for it -- and it is what
/// lets a `@MainActor` type like the Game Center transport conform at all.
@MainActor
public protocol MatchTransport: AnyObject {
    /// Seats controlled by the person holding this device. Two for
    /// pass-and-play, one for AI and remote play.
    var localPlayers: [PlayerID] { get }

    /// Submits an action. The transport is responsible for getting it into the
    /// shared state, however that state is shared.
    func submit(_ action: Action) async throws

    /// Called once, right after the view model has wired itself to this
    /// transport. Most transports have nothing to do here -- the human acts
    /// first, or a remote opponent acts on their own device. `AgentTransport`
    /// overrides it: the opening move of a drafted game does not always
    /// belong to the human (the snake order can open on either seat), and
    /// without this the agent would never be prompted, since it otherwise
    /// only moves in response to a local submission.
    func start() async

    /// Called when the local player should be asked to act.
    var onStateChange: ((GameState) -> Void)? { get set }
}

public extension MatchTransport {
    func controlsLocally(_ player: PlayerID) -> Bool {
        localPlayers.contains(player)
    }

    func start() async {}
}

/// Both seats on one device, with a hand-off curtain between turns.
@MainActor
public final class LocalTransport: MatchTransport {
    public let localPlayers: [PlayerID] = [.p1, .p2]
    public var onStateChange: ((GameState) -> Void)?
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
@MainActor
public final class AgentTransport: MatchTransport {
    public let localPlayers: [PlayerID]
    public var onStateChange: ((GameState) -> Void)?

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

    /// Lets the agent open the game if the opening move is theirs -- true for
    /// a drafted setup whenever the snake order starts on the agent's seat.
    public func start() async {
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
