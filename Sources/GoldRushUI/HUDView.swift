#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// Always-on status bar.
///
/// The unseen pool here is computed from THIS player's `PlayerView`, never from
/// global truth. It counts everything they have not identified: the cards never
/// dealt, plus any card the opponent claimed face down. Both are genuinely
/// unknown, so they are shown as one number.
public struct HUDView: View {
    public let view: PlayerView
    public let showOpponentCards: Bool

    public init(view: PlayerView, showOpponentCards: Bool = true) {
        self.view = view
        self.showOpponentCards = showOpponentCards
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Round \(view.round) of \(view.config.roundCount)",
                      systemImage: "flag.checkered")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.parchment)
                if view.config.isMotherlode(round: view.round) {
                    Text("MOTHERLODE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Theme.dirt)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.goldBright, in: Capsule())
                }
                Spacer()
                Text(view.player.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.goldBright)
            }

            CountsStripView(counts: view.unseen,
                            title: "UNSEEN BY YOU — \(view.unseenTotal) CARDS",
                            emphasis: true)

            if view.opponentHiddenCount > 0 {
                Text("\(view.opponentHiddenCount) of those are hidden in your opponent's claims")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.parchment.opacity(0.55))
            }

            if showOpponentCards, !view.opponentRevealed.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("OPPONENT'S PUBLIC CARDS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.gold.opacity(0.8))
                    ForEach(view.opponentRevealed, id: \.index) { id in
                        HStack(spacing: 5) {
                            Text(id.code)
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Theme.gold)
                            Text(ScoringCardCatalog[id].text)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.parchment.opacity(0.72))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dirtLight.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
