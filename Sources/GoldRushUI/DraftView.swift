#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine
import GoldRushUICore

/// The modern scoring-card draft.
///
/// Opening and closing decisions have two roles, so they get an explicit
/// KEEP/BURN selector rather than making the player infer what a tap means.
public struct DraftView: View {
    @Bindable public var model: GameViewModel
    @State private var keep: ScoringCardID?
    @State private var discard: ScoringCardID?

    public init(model: GameViewModel) {
        self.model = model
    }

    var pack: [ScoringCardID] { model.view.draftPool }
    var pairedDecision: Bool {
        pack.count == GameConfig.draftOpeningPackSize || pack.count == 2
    }
    var hasPublicBurns: Bool {
        !model.view.draftDiscards.p1.isEmpty || !model.view.draftDiscards.p2.isEmpty
    }

    public var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.goldBright)
                Text(detail)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.parchment.opacity(0.65))
                    .padding(.horizontal, 28)
            }

            if hasPublicBurns { publicBurns }

            if pairedDecision {
                HStack(spacing: 14) {
                    selectionChip("KEEP", id: keep, systemImage: "hand.thumbsup.fill")
                    selectionChip("BURN", id: discard, systemImage: "flame.fill")
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(pack, id: \.index) { id in
                        if pairedDecision {
                            pairedCard(id)
                        } else {
                            Button {
                                Task { await model.draftPick(id) }
                            } label: {
                                ScoringCardView(id: id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, pairedDecision ? 6 : 20)
            }

            if pairedDecision {
                Button {
                    guard let keep, let discard, keep != discard else { return }
                    Task {
                        if pack.count == GameConfig.draftOpeningPackSize {
                            await model.draftOpen(keep: keep, discard: discard)
                        } else {
                            await model.draftClose(keep: keep, discard: discard)
                        }
                    }
                } label: {
                    Text(pack.count == GameConfig.draftOpeningPackSize ? "Keep, burn & pass six" : "Keep one & burn one")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(canConfirm ? Theme.gold : Theme.dirtLight,
                                    in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(canConfirm ? Theme.dirt : Theme.parchment.opacity(0.4))
                }
                .disabled(!canConfirm)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
        .onChange(of: pack) { _, _ in
            keep = nil
            discard = nil
        }
    }

    @ViewBuilder
    var publicBurns: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FACE-UP BURNS")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(Theme.gold.opacity(0.8))
            ForEach(PlayerID.allCases, id: \.rawValue) { player in
                let burns = model.view.draftDiscards[player]
                if !burns.isEmpty {
                    HStack(spacing: 5) {
                        Text(player == model.view.player ? "You:" : "\(player.displayName):")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.parchment.opacity(0.6))
                        ForEach(burns, id: \.index) { id in
                            Text("\(id.code) · \(ScoringCardCatalog[id].name)")
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(Theme.parchment.opacity(0.82))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Theme.dirtDeep.opacity(0.65), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dirtLight.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }

    var canConfirm: Bool {
        guard let keep, let discard else { return false }
        return keep != discard
    }

    var title: String {
        switch pack.count {
        case GameConfig.draftOpeningPackSize: "Open your pack of eight"
        case 6: "Take one, pass five"
        case 5: "Take one, pass four"
        case 4: "Take one, pass three"
        case 3: "Take one, pass two"
        case 2: "Last two cards"
        default: "Draft a scoring card"
        }
    }

    var detail: String {
        switch pack.count {
        case GameConfig.draftOpeningPackSize:
            "Keep one card as your secret opener. Burn one face up. Your opponent gets the other six."
        case 2:
            "Keep one and burn the other face up. You finish with six scoring cards."
        default:
            "Keep one card and pass the rest. You have \(model.view.hand.count) of \(GameConfig.handSize)."
        }
    }

    @ViewBuilder
    func pairedCard(_ id: ScoringCardID) -> some View {
        VStack(spacing: 6) {
            ScoringCardView(id: id, selected: keep == id || discard == id)
            HStack(spacing: 8) {
                roleButton("Keep", systemImage: "hand.thumbsup.fill", selected: keep == id) {
                    keep = keep == id ? nil : id
                    if discard == id { discard = nil }
                }
                roleButton("Burn", systemImage: "flame.fill", selected: discard == id) {
                    discard = discard == id ? nil : id
                    if keep == id { keep = nil }
                }
            }
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    func roleButton(
        _ title: String,
        systemImage: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(selected ? Theme.gold : Theme.dirtLight.opacity(0.7),
                            in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(selected ? Theme.dirt : Theme.parchment.opacity(0.75))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func selectionChip(_ label: String, id: ScoringCardID?, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(label)
            Text(id?.code ?? "—")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(Theme.parchment.opacity(id == nil ? 0.45 : 0.9))
    }
}
#endif
