#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// What a player has collected, grouped by type.
public struct TableauView: View {
    public let view: PlayerView

    public init(view: PlayerView) {
        self.view = view
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CountsStripView(counts: view.collectionCounts,
                                title: "YOUR CLAIM — \(view.collectionCounts.total) CARDS",
                                emphasis: true)

                ForEach(MiningType.allCases, id: \.rawValue) { type in
                    let n = view.collectionCounts[type]
                    if n > 0 {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Image(systemName: Theme.safeSymbol(for: type))
                                    .foregroundStyle(Theme.tint(for: type))
                                Text(type.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.parchment)
                                Text("×\(n)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.goldBright)
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 6)], spacing: 6) {
                                ForEach(0..<n, id: \.self) { _ in
                                    MiningCardView(type: type, size: .chip)
                                }
                            }
                        }
                    }
                }

                Divider().overlay(Theme.gold.opacity(0.3))

                VStack(alignment: .leading, spacing: 6) {
                    Text("OPPONENT'S CLAIM — \(view.opponentCollection.count) CARDS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.gold.opacity(0.8))
                    CountsStripView(counts: view.opponentKnownCounts, title: "IDENTIFIED BY YOU")
                    if view.opponentHiddenCount > 0 {
                        Text("\(view.opponentHiddenCount) card\(view.opponentHiddenCount == 1 ? "" : "s") you never saw")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.sluice)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR SCORING CARDS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.gold.opacity(0.8))
                    ForEach(view.hand, id: \.index) { id in
                        ScoringCardView(id: id, dimmed: !view.myRevealed.contains(id))
                    }
                    Text("Dimmed cards are secret. All six score.")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.parchment.opacity(0.5))
                }
            }
            .padding(16)
        }
        .background(Theme.background)
    }
}
#endif
