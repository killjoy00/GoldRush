#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine
import GoldRushUICore

/// What the round just did: how each pile was divided, and who took which.
///
/// The game gave you no way to answer "what did they take?" -- the piles were
/// destroyed the moment the round advanced. That matters most when both
/// players split at once, because then two divisions resolve together and
/// neither player watched the other happen.
///
/// A card stays hidden here exactly as long as it stays hidden anywhere else:
/// if your opponent buried a card and you passed on that pile, this screen
/// will not tell you what it was either.
public struct RoundRecapView: View {
    @Bindable public var model: GameViewModel
    public let onContinue: () -> Void

    public init(model: GameViewModel, onContinue: @escaping () -> Void) {
        self.model = model
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(model.recapSplits.enumerated()), id: \.offset) { _, split in
                        splitCard(split)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            continueButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    @ViewBuilder
    var header: some View {
        VStack(spacing: 3) {
            Text("ROUND \(model.recapRound)")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.gold.opacity(0.85))
            Text(model.recapSplits.count > 1 ? "Both claims divided" : "The claim divided")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.goldBright)
        }
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    func splitCard(_ split: PlayerView.ResolvedSplit) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(split.mine ? "You split" : "\(split.splitter.displayName) split")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Theme.parchment.opacity(0.85))

            // Taken first: the answer to the question this screen exists for.
            pileRow(split, .taken)
            pileRow(split, .kept)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dirtLight.opacity(0.38), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.gold.opacity(0.12), lineWidth: 1)
        }
    }

    enum Outcome { case taken, kept }

    @ViewBuilder
    func pileRow(_ split: PlayerView.ResolvedSplit, _ outcome: Outcome) -> some View {
        // Two piles, two owners: the chooser takes one, the splitter keeps the
        // other. Whether that lands on "you" depends only on which side of this
        // split you were on.
        let cards = split.cards(outcome == .taken ? split.taken : split.kept)
        let chooser = split.splitter.opponent
        let owner = outcome == .taken ? chooser : split.splitter
        let wentToMe = split.mine ? owner == split.splitter : owner == chooser
        let verb = outcome == .taken ? "took" : "kept"
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
            // Wraps rather than scrolls: a pile is at most nine cards, and a
            // recap you have to scroll sideways is a recap nobody reads.
            FlowRow(spacing: 4) {
                ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                    MiningCardView(type: card.type, faceDown: card.type == nil, size: .chip)
                }
            }
            .opacity(wentToMe ? 1 : 0.62)
        }
    }

    @ViewBuilder
    var continueButton: some View {
        Button(action: onContinue) {
            Text("Next round")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.gold, in: RoundedRectangle(cornerRadius: 13))
                .foregroundStyle(Theme.dirt)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .padding(.top, 4)
    }
}

/// Lays children left to right, wrapping onto a new line when they run out of
/// width. SwiftUI has no stock equivalent that works inside a ScrollView.
struct FlowRow: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
#endif
