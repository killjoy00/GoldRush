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

    /// The seats this device is allowed to look at. Two for pass-and-play, one
    /// for AI and remote play.
    ///
    /// Every assignment to `viewingPlayer` is filtered through this. On a shared
    /// device the curtain is what protects the hidden information; on a remote
    /// match there is no curtain, and the only thing stopping this device from
    /// rendering the opponent's board during their turn is that it is never
    /// allowed to select their seat.
    private let localSeats: [PlayerID]

    public init(state: GameState, transport: any MatchTransport) {
        self.state = state
        self.transport = transport
        self.localSeats = transport.localPlayers.isEmpty ? [.p1] : transport.localPlayers
        self.usesHandoff = transport.localPlayers.count > 1

        let seats = transport.localPlayers.isEmpty ? [PlayerID.p1] : transport.localPlayers
        let opening = Self.seat(preferring: state.actingPlayer, within: seats)
        self.viewingPlayer = opening
        self.screen = Self.screen(for: state, viewing: opening)
        if state.phase == .split, state.actingPlayer == opening {
            self.splitBuilder = SplitBuilder(view: state.view(for: opening))
        }

        // A remote opponent's move arrives asynchronously rather than as a
        // result of anything this device did, so the transport pushes it here.
        transport.onStateChange = { [weak self] updated in
            Task { @MainActor in self?.adopt(updated) }
        }
    }

    /// The seat to show: the acting player when this device controls them,
    /// otherwise this device's own seat.
    static func seat(preferring actor: PlayerID?, within seats: [PlayerID]) -> PlayerID {
        if let actor, seats.contains(actor) { return actor }
        return seats.first ?? .p1
    }

    /// Whether the person holding this device may act right now. False while a
    /// remote opponent is thinking.
    public var isLocalTurn: Bool {
        guard let actor = state.actingPlayer else { return false }
        return localSeats.contains(actor)
    }

    /// Accepts state that arrived from elsewhere -- the opponent's device.
    public func adopt(_ updated: GameState) {
        guard updated != state else { return }
        state = updated
        viewingPlayer = Self.seat(preferring: updated.actingPlayer, within: localSeats)
        refresh()
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
        // Refuse to act on behalf of a seat this device does not control. The
        // UI should already prevent it; this makes it impossible rather than
        // merely unlikely.
        guard isLocalTurn else { return }

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
        // Never follow the turn to a seat this device may not see. In a remote
        // match the opponent's turn leaves the view on our own board.
        viewingPlayer = Self.seat(preferring: state.actingPlayer, within: localSeats)
        refresh()
    }

    private func refresh() {
        guard !awaitingHandoff else { return }
        screen = Self.screen(for: state, viewing: viewingPlayer)
        if state.phase == .split, state.actingPlayer == viewingPlayer,
           localSeats.contains(viewingPlayer) {
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
