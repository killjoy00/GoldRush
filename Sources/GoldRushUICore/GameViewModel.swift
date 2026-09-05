import Foundation
import Observation
import GoldRushEngine

/// What the screen should currently be showing.
public enum Screen: Sendable, Equatable {
    case draft
    /// Legacy seven-card saved matches only.
    case draftDiscard
    case revealSelection
    case additionalReveal
    /// Pass-and-play only: hide the board while the device changes hands.
    case handoff(to: PlayerID)
    case split
    case choose
    /// What the round just did: both splits, and which piles were taken.
    case roundRecap
    case scoring
}

/// Drives the whole game for the UI.
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
    /// A failed transport submission leaves the authoritative state untouched
    /// and puts the error here for the UI to surface instead of swallowing it.
    public private(set) var submissionError: String?

    /// The round the recap is currently showing, if it is showing one.
    private var recapForRound: Int?

    private let transport: any MatchTransport
    private let usesHandoff: Bool
    private var awaitingHandoff = false

    /// The seats this device is allowed to look at. Two for pass-and-play, one
    /// for AI and remote play.
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
            self?.adopt(updated)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.transport.start()
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

    /// Accepts state that arrived from a transport or the opponent's device.
    public func adopt(_ updated: GameState) {
        guard updated != state else { return }
        let before = state.lastRound?.round
        state = updated
        submissionError = nil
        noteRoundEnded(previously: before)
        viewingPlayer = Self.seat(preferring: updated.actingPlayer, within: localSeats)
        refresh()
    }

    /// Queues the recap when a round has resolved since the last look.
    private func noteRoundEnded(previously: Int?) {
        guard !state.isFinished, let last = state.lastRound, last.round != previously else { return }
        recapForRound = last.round
    }

    /// The only normal window onto the game the UI is given.
    public var view: PlayerView { state.view(for: viewingPlayer) }
    public var opponentView: PlayerView { state.view(for: viewingPlayer.opponent) }

    public var round: Int { state.round }
    public var isFinished: Bool { state.isFinished }

    var hasUnreadRecap: Bool {
        guard let last = state.lastRound else { return false }
        return recapForRound == last.round
    }

    public func acknowledgeRecap() {
        recapForRound = nil
        refresh()
    }

    public var recapSplits: [PlayerView.ResolvedSplit] { view.lastRound }
    public var recapRound: Int { state.lastRound?.round ?? state.round }

    /// Permanent, privacy-safe history for the Claim Journal.
    public var journalRounds: [ClaimJournalRound] {
        state.claimJournal(for: viewingPlayer)
    }

    static func screen(for state: GameState, viewing: PlayerID) -> Screen {
        switch state.phase {
        case .draft: .draft
        case .draftDiscard: .draftDiscard
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
        if submissionError == nil { revealSelection = [] }
    }

    // MARK: - Split

    public func confirmSplit() async {
        guard let action = splitBuilder?.action, state.isLegal(action) else { return }
        await submit(action)
    }

    // MARK: - Choose

    public func choose(_ pile: PileID) async {
        await submit(.choose(pile: pile))
    }

    // MARK: - Draft

    public func draftOpen(keep: ScoringCardID, discard: ScoringCardID) async {
        await submit(.draftOpen(keep: keep, discard: discard))
    }

    public func draftPick(_ id: ScoringCardID) async {
        await submit(.draftPick(id))
    }

    public func draftClose(keep: ScoringCardID, discard: ScoringCardID) async {
        await submit(.draftClose(keep: keep, discard: discard))
    }

    public func revealAdditional(_ id: ScoringCardID) async {
        await submit(.revealAdditional(id))
    }

    /// Legacy saved matches only.
    public func draftDiscard(_ id: ScoringCardID) async {
        await submit(.draftDiscard(id))
    }

    public var draftLegalPicks: [ScoringCardID] { view.draftPool }

    // MARK: - Hand-off

    public func completeHandoff() {
        awaitingHandoff = false
        refresh()
    }

    public func clearSubmissionError() {
        submissionError = nil
    }

    private func submit(_ action: Action) async {
        guard isLocalTurn else { return }

        let submittedFrom = state
        let beforeRound = state.lastRound?.round
        submissionError = nil

        do {
            try await transport.submit(action)
        } catch {
            // Crucially: do not apply the action locally. A Game Center failure
            // means the server still owns `submittedFrom`, so advancing here
            // would create a board that only this phone believes happened.
            submissionError = error.localizedDescription
            return
        }

        // Every built-in transport publishes its accepted state through
        // onStateChange. This fallback keeps the protocol honest for a custom
        // transport that persists successfully but chooses not to publish.
        // Never apply if the callback already advanced us: AgentTransport may
        // have played several AI actions before `submit` returns.
        if state == submittedFrom {
            state = submittedFrom.apply(action)
            noteRoundEnded(previously: beforeRound)
        }

        if let next = state.actingPlayer, next != viewingPlayer,
           usesHandoff, !state.isFinished {
            awaitingHandoff = true
            screen = .handoff(to: next)
            viewingPlayer = next
            splitBuilder = nil
            return
        }
        viewingPlayer = Self.seat(preferring: state.actingPlayer, within: localSeats)
        refresh()
    }

    private func refresh() {
        guard !awaitingHandoff else { return }
        if hasUnreadRecap {
            screen = .roundRecap
            splitBuilder = nil
            return
        }
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

    /// Stable identifier used to record a completed game in Career Stats once,
    /// even if the scoring screen is reopened or an online match is reloaded.
    public var finishedGameIdentifier: String? {
        guard state.isFinished else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return nil }
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
