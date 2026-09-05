#if canImport(GameKit) && canImport(SwiftUI)
import Foundation
import GameKit
import GoldRushEngine
import GoldRushUICore

/// Signing in to Game Center.
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
    public func authenticate(present: @escaping (Any) -> Void) {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
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
/// both just load the same state.
///
/// KNOWN LIMITATION: `matchData` is readable by both clients. A determined
/// player could inspect hidden cards or the undrawn deck. Truly hiding that
/// needs a server or commitment scheme; the normal app UI still enforces every
/// hidden-information rule through `PlayerView`.
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
            self.state = GameState.newGame(config: config, seed: UInt64.random(in: 0..<UInt64.max))
        }
    }

    // MARK: - MatchTransport

    public func submit(_ action: Action) async throws {
        guard isLocalTurn else { throw Failure.notYourTurn }
        guard state.isLegal(action) else { return }

        let next = state.apply(action)
        guard next != state else { return }
        let data = try Self.makeEncoder().encode(next)

        // Persist FIRST. Publishing an optimistic state before Game Center
        // accepts it can leave this phone one move ahead of the authoritative
        // match when the network request fails.
        if next.isFinished {
            try await endMatch(with: data, finalState: next)
        } else if let actor = next.actingPlayer, actor == localSeat {
            // Still this player's move: save without handing off the turn.
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

        // Only a successful remote write becomes local truth.
        state = next
        onStateChange?(next)
    }

    /// Reloads after the opponent has moved or after the app resumes.
    public func refresh() async throws {
        let reloaded = try await GKTurnBasedMatch.load(withID: match.matchID)
        match = reloaded
        if let data = reloaded.matchData, !data.isEmpty {
            let decoded = try JSONDecoder().decode(GameState.self, from: data)
            state = decoded
            onStateChange?(decoded)
        }
    }

    private func endMatch(with data: Data, finalState: GameState) async throws {
        let winner = finalState.winner()
        for participant in match.participants {
            let seat: PlayerID = match.participants.firstIndex(of: participant) == 0 ? .p1 : .p2
            participant.matchOutcome = (seat == winner) ? .won : .lost
        }
        try await match.endMatchInTurn(withMatch: data)
    }
}
#endif
