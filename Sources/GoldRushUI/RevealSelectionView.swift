#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine
import GoldRushUICore

/// Choose which scoring cards to make public.
///
/// Worth knowing while playing: the simulator found this is one of the strongest
/// decisions in the game, and that hiding your majority riders is the WORSE
/// play. The screen therefore presents it as a real choice rather than a
/// formality, but does not tell the player what to pick.
public struct RevealSelectionView: View {
    @Bindable public var model: GameViewModel

    public init(model: GameViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Choose \(model.state.config.initialRevealCount) to reveal")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.goldBright)
                Text("All six cards score at the end. These \(model.state.config.initialRevealCount) become public — your opponent will split the deck knowing them.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.parchment.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.view.hand, id: \.index) { id in
                        Button {
                            model.toggleReveal(id)
                        } label: {
                            ScoringCardView(id: id, selected: model.revealSelection.contains(id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            Button {
                Task { await model.confirmReveal() }
            } label: {
                Text(model.revealSelectionComplete
                     ? "Reveal these \(model.revealSelection.count)"
                     : "Select \(model.state.config.initialRevealCount - model.revealSelection.count) more")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(model.revealSelectionComplete ? Theme.gold : Theme.dirtLight,
                                in: RoundedRectangle(cornerRadius: 13))
                    .foregroundStyle(model.revealSelectionComplete ? Theme.dirt : Theme.parchment.opacity(0.5))
            }
            .disabled(!model.revealSelectionComplete)
            .padding(16)
        }
    }
}
#endif
