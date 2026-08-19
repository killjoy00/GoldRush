#if canImport(GameKit) && canImport(SwiftUI)
import Foundation
import GameKit
import GoldRushEngine
import GoldRushUICore

/// Signing in to Game Center.
///
/// Authentication has to happen before any matchmaking UI is presented, and it
/// can also fail benignly (the player declines, or has no network), so the
/// result is surfaced as state rather than thrown.
@MainActor
@Observable
public final class GameCenterAuth {
    public enum Status: Equatable {
        case unknown
        case signedIn(displayName: String)
        case signedOut
        case failed(String)
    }

    public private(set) var status: Status = .unknown
    public static let shared = GameCenterAuth()

    private init() {}

    public var isSignedIn: Bool {
        if case .signedIn = status { return true }
        return false
    }

    /// Starts authentication. Safe to call more than once.
    ///
    /// The handler may be invoked repeatedly over the app's lifetime -- Game
    /// Center calls it again if the player signs in or out later -- so it
    /// updates state rather than completing once.
    public func authenticate(present: @escaping (Any) -> Void) {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    // Game Center wants to show its own sign-in screen.
                    present(viewController)
                    return
                }
                if let error {
                    self.status = .failed(error.localizedDescription)
                    return
                }
                self.status = GKLocalPlayer.local.isAuthenticated
                    ? .signedIn(displayName: GKLocalPlayer.local.displayName)
                    : .signedOut
            }
        }
    }
}

/// Carries a game between two devices through Game Center.
///
/// The whole `GameState` is encoded into the match's `matchData` on every turn,
/// which is what makes the two devices agree: neither replays actions, they
/// both just load the same state. The serialization tests pin the properties
/// that relies on -- a decoded game equals the original and continues
/// identically -- and the state is ~3 KB against a 64 KB ceiling.
///
/// KNOWN LIMITATION, stated here because it is a real property of the design
/// rather than an oversight: `matchData` is readable by BOTH clients. A player
/// willing to inspect it could read the face-down cards they were not shown,
/// and indeed the whole undrawn deck. Hiding that genuinely requires either a
/// server or a commitment scheme (publish hashes of the hidden cards, reveal
/// the salts at scoring), and Gold Rush deliberately has no server. For two
/// friends playing on their own phones this is not a threat worth the
/// complexity; the hidden-information rules are still enforced by the app for
/// anyone not deliberately attacking it.
@MainActor
public final class GameCenterTransport: MatchTransport {

    public enum Failure: LocalizedError {
        case notAuthenticated
        case noLocalSeat
        case matchDataUnreadable
        case notYourTurn

        public var errorDescription: String? {
            switch self {
            case .notAuthenticated: "Sign in to Game Center to play online."
            case .noLocalSeat: "You do not appear to be a player in this match."
            case .matchDataUnreadable: "This match's saved state could not be read."
            case .notYourTurn: "It is not your turn yet."
            }
        }
    }

    public private(set) var match: GKTurnBasedMatch
    public private(set) var state: GameState
    public private(set) var localSeat: PlayerID
    public var onStateChange: ((GameState) -> Void)?

    public var localPlayers: [PlayerID] { [localSeat] }

    /// How long a player has to take their turn before forfeiting it.
    ///
    /// Stated explicitly rather than using `GKTurnTimeoutDefault`, for two
    /// reasons: that symbol is a mutable global which Swift 6 will not let a
    /// concurrent context read, and how long a friend gets to think is a design
    /// decision worth making deliberately rather than inheriting. A week suits
    /// a game people pick up between other things.
    public static let turnTimeout: TimeInterval = 7 * 24 * 60 * 60

    /// Whether Game Center currently considers this device the active one.
    public var isLocalTurn: Bool {
        match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public init(match: GKTurnBasedMatch, config: GameConfig = .standard) throws {
        guard GKLocalPlayer.local.isAuthenticated else { throw Failure.notAuthenticated }

        // Seat by participant order. GameKit presents the same ordering to both
        // devices, so this assignment agrees without needing to be stored.
        guard let index = match.participants.firstIndex(where: {
            $0.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID
        }) else { throw Failure.noLocalSeat }

        self.match = match
        self.localSeat = index == 0 ? .p1 : .p2

        if let data = match.matchData, !data.isEmpty {
            do {
                self.state = try JSONDecoder().decode(GameState.self, from: data)
            } catch {
                throw Failure.matchDataUnreadable
            }
        } else {
            // First turn of a new match: whoever acts first establishes the deal.
            // The seed is part of the state from then on, so both devices deal
            // identically for the rest of the game.
            self.state = GameState.newGame(config: config, seed: UInt64.random(in: 0..<UInt64.max))
        }
    }

    // MARK: - MatchTransport

    public func submit(_ action: Action) async throws {
        guard isLocalTurn else { throw Failure.notYourTurn }
        guard state.isLegal(action) else { return }

        let next = state.apply(action)
        guard next != state else { return }
        state = next
        onStateChange?(next)

        let data = try Self.makeEncoder().encode(next)

        if next.isFinished {
            try await endMatch(with: data)
        } else if let actor = next.actingPlayer, actor == localSeat {
            // Still this player's move -- P2 chooses a pile and then immediately
            // splits the next round, so the turn must be saved without being
            // passed on.
            try await match.saveCurrentTurn(withMatch: data)
        } else {
            let others = match.participants.filter {
                $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID
            }
            try await match.endTurn(
                withNextParticipants: others,
                turnTimeout: Self.turnTimeout,
                match: data
            )
        }
    }

    /// Reloads after the opponent has moved.
    public func refresh() async throws {
        let reloaded = try await GKTurnBasedMatch.load(withID: match.matchID)
        match = reloaded
        if let data = reloaded.matchData, !data.isEmpty {
            let decoded = try JSONDecoder().decode(GameState.self, from: data)
            state = decoded
            onStateChange?(decoded)
        }
    }

    private func endMatch(with data: Data) async throws {
        let winner = state.winner()
        for participant in match.participants {
            let seat: PlayerID = match.participants.firstIndex(of: participant) == 0 ? .p1 : .p2
            participant.matchOutcome = (seat == winner) ? .won : .lost
        }
        try await match.endMatchInTurn(withMatch: data)
    }
}
#endif
