#if canImport(GameKit) && canImport(UIKit) && canImport(SwiftUI)
import GameKit
import SwiftUI
import UIKit
import GoldRushEngine

/// Presents Game Center's own matchmaking screen.
///
/// Apple's controller is used rather than a custom one because it already
/// handles the things that are tedious and easy to get wrong: invites, auto-match
/// against a stranger, resuming matches where it is your turn, and declining.
public struct GameCenterMatchmakerView: UIViewControllerRepresentable {
    public let onMatch: (GKTurnBasedMatch) -> Void
    public let onCancel: () -> Void

    public init(
        onMatch: @escaping (GKTurnBasedMatch) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onMatch = onMatch
        self.onCancel = onCancel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onMatch: onMatch, onCancel: onCancel)
    }

    public func makeUIViewController(context: Context) -> GKTurnBasedMatchmakerViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.defaultNumberOfPlayers = 2

        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.turnBasedMatchmakerDelegate = context.coordinator
        // Two-player only, so there is never a reason to start with a bot seat.
        controller.showExistingMatches = true
        return controller
    }

    public func updateUIViewController(
        _ controller: GKTurnBasedMatchmakerViewController, context: Context
    ) {}

    public final class Coordinator: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
        let onMatch: (GKTurnBasedMatch) -> Void
        let onCancel: () -> Void

        init(onMatch: @escaping (GKTurnBasedMatch) -> Void, onCancel: @escaping () -> Void) {
            self.onMatch = onMatch
            self.onCancel = onCancel
        }

        public func turnBasedMatchmakerViewControllerWasCancelled(
            _ viewController: GKTurnBasedMatchmakerViewController
        ) {
            onCancel()
        }

        public func turnBasedMatchmakerViewController(
            _ viewController: GKTurnBasedMatchmakerViewController,
            didFailWithError error: any Error
        ) {
            onCancel()
        }
    }
}

/// Listens for turn events so a game already on screen updates when the
/// opponent moves, instead of only refreshing when the player reopens it.
@MainActor
public final class GameCenterTurnListener: NSObject, GKLocalPlayerListener {
    public var onTurnEvent: ((GKTurnBasedMatch, Bool) -> Void)?
    public var onMatchEnded: ((GKTurnBasedMatch) -> Void)?

    public static let shared = GameCenterTurnListener()

    private var registered = false

    public func start() {
        guard !registered, GKLocalPlayer.local.isAuthenticated else { return }
        GKLocalPlayer.local.register(self)
        registered = true
    }

    nonisolated public func player(
        _ player: GKPlayer,
        receivedTurnEventFor match: GKTurnBasedMatch,
        didBecomeActive: Bool
    ) {
        Task { @MainActor in
            self.onTurnEvent?(match, didBecomeActive)
        }
    }

    nonisolated public func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        Task { @MainActor in
            self.onMatchEnded?(match)
        }
    }
}
#endif
