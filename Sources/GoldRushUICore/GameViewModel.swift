import Observation
import GoldRushEngine

/// What the screen should currently be showing.
public enum Screen: Sendable, Equatable {
    case draft
    case revealSelection
    case additionalReveal
    /// Pass-and-play only: hide the board while the device changes hands.
    case handoff(to: PlayerID)
    case split
    case choose
    case scoring
}

/// Drives the whole game for the UI.
///
/// Deliberately holds `GameState` privately and exposes only `PlayerView`.
/// A SwiftUI view cannot reach the global truth even if it wants to, which is
/// the same guarantee the agents get -- and the reason the on-screen unseen
/// tracker is honest rather than merely intended to be.
@Observable
@MainActor
public final class GameViewModel {
    public private(set) var state: GameState
    public private(set) var screen: Screen
    /// Whose eyes the device currently belongs to.
    public private(set) var viewingPlayer: PlayerID
    public private(set) var splitBuilder: SplitBuilder?
    /// Reveal picks being assembled on the reveal screen.
    public private(set) var revealSelection: [ScoringCardID] = []

    private let transport: any MatchTransport
    private let usesHandoff: Bool
    private var awaitingHandoff = false

    public init(state: GameState, transport: any MatchTransport) {
        self.state = state
        self.transport = transport
        self.usesHandoff = transport.localPlayers.count > 1
        self.viewingPlayer = state.actingPlayer ?? .p1
        self.screen = Self.screen(for: state, viewing: state.actingPlayer ?? .p1)
        if state.phase == .split, let actor = state.actingPlayer {
            self.splitBuilder = SplitBuilder(view: state.view(for: actor))
        }
    }

    /// The only window onto the game the UI is given.
    public var view: PlayerView {
        state.view(for: viewingPlayer)
    }

    public var opponentView: PlayerView {
        state.view(for: viewingPlayer.opponent)
    }

    public var round: Int { state.round }
    public var isFinished: Bool { state.isFinished }

    static func screen(for state: GameState, viewing: PlayerID) -> Screen {
        switch state.phase {
        case .draft: .draft
        case .revealSelection: .revealSelection
        case .additionalReveal: .additionalReveal
        case .split: .split
        case .choose: .choose
        case .finished: .scoring
        }
    }

    // MARK: - Reveal selection

    public func toggleReveal(_ id: ScoringCardID) {
        guard state.phase == .revealSelection else { return }
        if let index = revealSelection.firstIndex(of: id) {
            revealSelection.remove(at: index)
        } else if revealSelection.count < state.config.initialRevealCount {
            revealSelection.append(id)
        }
    }

    public var revealSelectionComplete: Bool {
        revealSelection.count == state.config.initialRevealCount
    }

    public func confirmReveal() async {
        guard revealSelectionComplete else { return }
        await submit(.selectRevealedScoringCards(revealSelection))
        revealSelection = []
    }

    // MARK: - Split

    /// Splits are not undoable, so this is the single gate. It re-checks the
    /// engine's own legality rather than trusting the builder's UI state.
    public func confirmSplit() async {
        guard let action = splitBuilder?.action, state.isLegal(action) else { return }
        await submit(action)
    }

    // MARK: - Choose

    public func choose(_ pile: PileID) async {
        await submit(.choose(pile: pile))
    }

    // MARK: - Draft

    public func draftPick(_ id: ScoringCardID) async {
        await submit(.draftPick(id))
    }

    public func revealAdditional(_ id: ScoringCardID) async {
        await submit(.revealAdditional(id))
    }

    public var draftLegalPicks: [ScoringCardID] {
        let hand = view.hand
        return view.draftPool.filter { candidate in
            hand.count { $0.family == candidate.family } < GameConfig.familyCap
        }
    }

    // MARK: - Hand-off

    /// Pass-and-play hides the board between turns. Without this the whole
    /// hidden-information design collapses: the next player would simply see
    /// what the last one was holding.
    public func completeHandoff() {
        awaitingHandoff = false
        refresh()
    }

    private func submit(_ action: Action) async {
        try? await transport.submit(action)
        state = state.apply(action)

        if let next = state.actingPlayer, next != viewingPlayer,
           usesHandoff, !state.isFinished {
            awaitingHandoff = true
            screen = .handoff(to: next)
            viewingPlayer = next
            splitBuilder = nil
            return
        }
        if let next = state.actingPlayer { viewingPlayer = next }
        refresh()
    }

    private func refresh() {
        guard !awaitingHandoff else { return }
        screen = Self.screen(for: state, viewing: viewingPlayer)
        if state.phase == .split, state.actingPlayer == viewingPlayer {
            splitBuilder = SplitBuilder(view: state.view(for: viewingPlayer))
        } else {
            splitBuilder = nil
        }
    }

    // MARK: - Scoring presentation

    public struct ScoreLine: Sendable, Equatable, Identifiable {
        public let id: ScoringCardID
        public let name: String
        public let text: String
        public let points: Int
        public let wasPublic: Bool
    }

    public func scoreLines(for player: PlayerID) -> [ScoreLine] {
        let card = state.scorecard(for: player)
        let publicCards = state.revealed[player]
        return card.cards.map { entry in
            let catalogCard = ScoringCardCatalog[entry.id]
            return ScoreLine(
                id: entry.id,
                name: catalogCard.name,
                text: catalogCard.text,
                points: entry.points,
                wasPublic: publicCards.contains(entry.id)
            )
        }
    }

    public func total(for player: PlayerID) -> Int {
        state.scorecard(for: player).total
    }

    public var winner: PlayerID? {
        state.isFinished ? state.winner() : nil
    }
}
