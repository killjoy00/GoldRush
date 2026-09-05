#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// A match-long history of every resolved claim, with the same hidden-card
/// boundary the player had when the round happened.
public struct ClaimJournalView: View {
    public let rounds: [ClaimJournalRound]
    @Environment(\.dismiss) private var dismiss

    public init(rounds: [ClaimJournalRound]) {
        self.rounds = rounds
    }

    public var body: some View {
        NavigationStack {
            Group {
                if rounds.isEmpty {
                    ContentUnavailableView(
                        "No claims yet",
                        systemImage: "book.closed",
                        description: Text("Completed rounds will appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(rounds.reversed()) { round in
                                roundCard(round)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Claim Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    func roundCard(_ round: ClaimJournalRound) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ROUND \(round.round)")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.gold.opacity(0.85))

            ForEach(Array(round.splits.enumerated()), id: \.offset) { _, split in
                VStack(alignment: .leading, spacing: 7) {
                    Text(split.mine ? "You split" : "\(split.splitter.displayName) split")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.parchment.opacity(0.85))
                    pileRow(split, pile: split.taken, taken: true)
                    pileRow(split, pile: split.kept, taken: false)
                }
                if split.splitter != round.splits.last?.splitter {
                    Divider().overlay(Theme.gold.opacity(0.12))
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dirtLight.opacity(0.38), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.gold.opacity(0.12), lineWidth: 1)
        }
    }

    @ViewBuilder
    func pileRow(_ split: ClaimJournalSplit, pile: PileID, taken: Bool) -> some View {
        let cards = split.cards(pile)
        let owner = taken ? split.splitter.opponent : split.splitter
        let wentToMe = split.mine ? owner == split.splitter : owner == split.splitter.opponent
        let verb = taken ? "took" : "kept"
        let label = wentToMe ? "You \(verb)" : "\(owner.displayName) \(verb)"

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(wentToMe ? Theme.gold : Theme.parchment.opacity(0.35))
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 12, weight: wentToMe ? .semibold : .regular))
                    .foregroundStyle(wentToMe ? Theme.goldBright : Theme.parchment.opacity(0.6))
                Text("· \(cards.count) card\(cards.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.parchment.opacity(0.4))
            }
            FlowRow(spacing: 4) {
                ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                    MiningCardView(type: card.type, faceDown: card.type == nil, size: .chip)
                }
            }
            .opacity(wentToMe ? 1 : 0.62)
        }
    }
}
#endif
