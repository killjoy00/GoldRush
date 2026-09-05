/// One historical split as a player is allowed to remember it.
///
/// This deliberately uses `VisibleCard` instead of mining-card identities plus
/// a visibility flag. A buried card the player never learned remains structurally
/// unavailable to the UI, exactly as it does in the live `PlayerView`.
public struct ClaimJournalSplit: Sendable, Equatable {
    public let splitter: PlayerID
    public let pileA: [VisibleCard]
    public let pileB: [VisibleCard]
    public let taken: PileID
    public let mine: Bool

    public init(
        splitter: PlayerID,
        pileA: [VisibleCard],
        pileB: [VisibleCard],
        taken: PileID,
        mine: Bool
    ) {
        self.splitter = splitter
        self.pileA = pileA
        self.pileB = pileB
        self.taken = taken
        self.mine = mine
    }

    public var kept: PileID { taken.other }
    public func cards(_ pile: PileID) -> [VisibleCard] { pile == .a ? pileA : pileB }
}

public struct ClaimJournalRound: Sendable, Equatable, Identifiable {
    public let round: Int
    public let splits: [ClaimJournalSplit]

    public init(round: Int, splits: [ClaimJournalSplit]) {
        self.round = round
        self.splits = splits
    }

    public var id: Int { round }
}

extension GameState {
    /// Every completed round, projected through one player's actual knowledge.
    ///
    /// Rules are identical to the immediate round recap:
    /// - you know your own split in full because you drew it;
    /// - when choosing, you know every face-up card in both piles;
    /// - you also learn buried cards in the pile you take;
    /// - buried cards in the pile you decline stay hidden forever.
    public func claimJournal(for player: PlayerID) -> [ClaimJournalRound] {
        (roundHistory ?? []).map { outcome in
            var projected: [ClaimJournalSplit] = []
            for splitter in [PlayerID.p1, .p2] {
                guard let split = outcome.splits[splitter],
                      let taken = outcome.taken[splitter.opponent] else { continue }

                let isMine = splitter == player
                let iChose = splitter.opponent == player

                func cards(_ ids: [CardID], pile: PileID) -> [VisibleCard] {
                    ids.map { id in
                        let claimed = iChose && pile == taken
                        if isMine || claimed || !split.faceDown.contains(id) {
                            return .known(id, type(id))
                        }
                        return .hidden(id)
                    }
                }

                projected.append(ClaimJournalSplit(
                    splitter: splitter,
                    pileA: cards(split.pileA, pile: .a),
                    pileB: cards(split.pileB, pile: .b),
                    taken: taken,
                    mine: isMine
                ))
            }
            return ClaimJournalRound(round: outcome.round, splits: projected)
        }
    }
}
