#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine
import GoldRushUICore

/// End-of-game breakdown, itemised per scoring card.
public struct ScoringView: View {
    @Bindable public var model: GameViewModel

    public init(model: GameViewModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let winner = model.winner {
                    VStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.goldBright)
                        Text("\(winner.displayName) wins")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.goldBright)
                        Text("\(model.total(for: .p1)) — \(model.total(for: .p2))")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.parchment)
                    }
                    .padding(.top, 20)
                }

                ForEach(PlayerID.allCases, id: \.rawValue) { player in
                    playerBreakdown(player)
                }
            }
            .padding(16)
        }
        .background(Theme.dirt)
    }

    @ViewBuilder
    func playerBreakdown(_ player: PlayerID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(player.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.parchment)
                Spacer()
                Text("\(model.total(for: player))")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldBright)
            }

            ForEach(model.scoreLines(for: player)) { line in
                ScoringCardView(id: line.id, points: line.points)
                    .overlay(alignment: .topTrailing) {
                        if !line.wasPublic {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.sluice)
                                .padding(6)
                        }
                    }
            }

            let card = model.state.scorecard(for: player)
            VStack(alignment: .leading, spacing: 3) {
                Text("HOW THE SETS RESOLVED")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.gold.opacity(0.75))
                Text("Ore+Shovel sets: \(card.board.oreShovelSets)   ·   Gravel+Pan sets: \(card.board.gravelPanSets)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.parchment.opacity(0.7))
                if card.board.counts.packMule > 0 {
                    Text("Pack Mules: \(card.allocation.toShovel) filled a Shovel slot, \(card.allocation.toPan) filled a Pan slot")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.parchment.opacity(0.7))
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.dirtLight.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(12)
        .background(Theme.dirtLight.opacity(0.35), in: RoundedRectangle(cornerRadius: 13))
    }
}
#endif
