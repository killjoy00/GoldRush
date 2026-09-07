#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine
import GoldRushUICore

/// Build the two piles.
///
/// Cards move by drag or by tap, and a tap on the eye badge turns one face down.
/// Legality is validated live and the confirm gate is a separate, deliberate
/// step: a split cannot be undone once submitted, so the screen asks for
/// confirmation rather than acting on the first tap.
public struct SplitView: View {
    @Bindable public var model: GameViewModel
    @State private var confirming = false
    @State private var dropTarget: PileID?

    public init(model: GameViewModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if let builder = model.splitBuilder {
                content(builder)
            } else {
                ProgressView().tint(Theme.gold)
            }
        }
    }

    @ViewBuilder
    func content(_ builder: SplitBuilder) -> some View {
        WideLayoutReader { wide in
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Split the \(builder.draw.count) cards")
                        .font(.system(size: wide ? 26 : 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.goldBright)
                    Text("Your opponent picks a pile; you take the other. Turn \(builder.requiredFaceDown) card\(builder.requiredFaceDown == 1 ? "" : "s") face down — only whoever claims that pile will ever see it.")
                        .font(.system(size: wide ? 14 : 11))
                        .foregroundStyle(Theme.parchment.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Side by side when there is room. The game is the comparison
                // between these two piles, so making the player scroll one past
                // the other on a screen with space for both is the wrong shape.
                // Both branches use the same `pileZone`, so the piles cannot
                // drift apart as one layout gets edited.
                if wide {
                    // The piles take the height they are given rather than
                    // sitting in a band with a thousand points of nothing
                    // underneath. They are also drop targets, so a taller zone
                    // is a more forgiving one to drag a card into.
                    HStack(alignment: .top, spacing: 14) {
                        pileZone(builder, .a, fill: true)
                        pileZone(builder, .b, fill: true)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 16)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            pileZone(builder, .a)
                            pileZone(builder, .b)
                        }
                        .padding(.horizontal, 16)
                    }
                }

                footer(builder)
            }
        }
        .alert("Confirm this split?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") { Task { await model.confirmSplit() } }
        } message: {
            Text("Splits cannot be undone. Your opponent chooses next.")
        }
    }

    @ViewBuilder
    func pileZone(_ builder: SplitBuilder, _ pile: PileID, fill: Bool = false) -> some View {
        let cards = builder.pile(pile)
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("PILE \(pile == .a ? "A" : "B")")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.gold)
                Text("\(cards.count) card\(cards.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.parchment.opacity(0.6))
                if builder.faceDownCount(in: pile) > 0 {
                    Label("\(builder.faceDownCount(in: pile))", systemImage: "eye.slash.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.sluice)
                }
                Spacer()
            }

            if cards.isEmpty {
                Text("Empty — tap or drag a card here")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger.opacity(0.9))
                    .frame(maxWidth: .infinity, minHeight: 74)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                    ForEach(cards, id: \.rawValue) { card in
                        cardTile(builder, card, in: pile)
                    }
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity,
               maxHeight: fill ? .infinity : nil,
               alignment: .topLeading)
        .background(Theme.dirtLight.opacity(dropTarget == pile ? 1.0 : 0.7),
                    in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(cards.isEmpty ? Theme.danger.opacity(0.6) : Theme.gold.opacity(0.25),
                              lineWidth: 1)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let value = UInt16(raw) else { return false }
            model.splitBuilder?.move(CardID(value), to: pile)
            return true
        } isTargeted: { targeted in
            dropTarget = targeted ? pile : nil
        }
    }

    @ViewBuilder
    func cardTile(_ builder: SplitBuilder, _ card: CardID, in pile: PileID) -> some View {
        VStack(spacing: 3) {
            MiningCardView(type: builder.type(of: card), faceDown: false,
                           selected: builder.isFaceDown(card), size: .full)
                .onTapGesture { builder.move(card, to: pile.other) }
                .draggable(String(card.rawValue))

            Button {
                builder.toggleFaceDown(card)
            } label: {
                Image(systemName: builder.isFaceDown(card) ? "eye.slash.fill" : "eye")
                    .font(.system(size: 11))
                    .foregroundStyle(builder.isFaceDown(card) ? Theme.sluice : Theme.parchment.opacity(0.4))
                    .frame(width: 30, height: 20)
                    .background(Theme.dirt.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func footer(_ builder: SplitBuilder) -> some View {
        VStack(spacing: 7) {
            ForEach(builder.problems, id: \.self) { problem in
                Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                confirming = true
            } label: {
                Text(builder.isLegal ? "Confirm split" : "Not a legal split yet")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(builder.isLegal ? Theme.gold : Theme.dirtLight,
                                in: RoundedRectangle(cornerRadius: 13))
                    .foregroundStyle(builder.isLegal ? Theme.dirt : Theme.parchment.opacity(0.5))
            }
            .disabled(!builder.isLegal)
        }
        .centredColumn()
        .padding(16)
    }
}
#endif
