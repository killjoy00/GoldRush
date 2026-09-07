#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine
import GoldRushUICore

/// Pick a pile.
///
/// Face-down cards render as backs, because the chooser genuinely does not know
/// them. That is not a presentation choice: `PlayerView` does not carry their
/// identity, so there is nothing here to accidentally show.
public struct ChooseView: View {
    @Bindable public var model: GameViewModel
    @State private var confirming: PileID?

    public init(model: GameViewModel) {
        self.model = model
    }

    public var body: some View {
        WideLayoutReader { wide in
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Take a pile")
                        .font(.system(size: wide ? 26 : 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.goldBright)
                    Text("Your opponent divided these. Whichever you take, they keep the other.")
                        .font(.system(size: wide ? 14 : 11))
                        .foregroundStyle(Theme.parchment.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if let piles = model.view.piles {
                    // Choosing is a comparison too, so the piles sit next to
                    // each other for the same reason they do when splitting.
                    if wide {
                        HStack(alignment: .top, spacing: 14) {
                            pileCard(.a, piles.a, fill: true)
                            pileCard(.b, piles.b, fill: true)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 16)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                pileCard(.a, piles.a)
                                pileCard(.b, piles.b)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .alert("Take pile \(confirming == .a ? "A" : "B")?", isPresented: .init(
            get: { confirming != nil },
            set: { if !$0 { confirming = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirming = nil }
            Button("Take it") {
                if let pile = confirming {
                    Task { await model.choose(pile) }
                }
                confirming = nil
            }
        } message: {
            Text("Your opponent keeps the other pile.")
        }
    }

    @ViewBuilder
    func pileCard(_ id: PileID, _ cards: [VisibleCard], fill: Bool = false) -> some View {
        let hidden = cards.count(where: \.isHidden)
        Button {
            confirming = id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PILE \(id == .a ? "A" : "B")")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Theme.gold)
                    Spacer()
                    Text("\(cards.count) card\(cards.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.parchment.opacity(0.65))
                    if hidden > 0 {
                        Label("\(hidden) hidden", systemImage: "eye.slash.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.sluice)
                    }
                }
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: fill ? 84 : 60), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(cards, id: \.id.rawValue) { card in
                        MiningCardView(type: card.type, faceDown: card.isHidden,
                                       size: fill ? .full : .compact)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity,
                   maxHeight: fill ? .infinity : nil,
                   alignment: .topLeading)
            .background(Theme.dirtLight, in: RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
