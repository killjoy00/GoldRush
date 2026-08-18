#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// The pass-and-play curtain.
///
/// Without this the hidden-information design collapses on a shared device --
/// the next player would simply see what the last one was holding. It blocks
/// the board until the named player confirms they are the one looking.
public struct HandoffView: View {
    public let player: PlayerID
    public let onContinue: () -> Void

    public init(player: PlayerID, onContinue: @escaping () -> Void) {
        self.player = player
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.gold)
            Text("Pass the device to")
                .font(.system(size: 16))
                .foregroundStyle(Theme.parchment.opacity(0.75))
            Text(player.displayName)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            Text("Everything on screen is private to this player.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.parchment.opacity(0.6))
                .padding(.horizontal, 40)
            Spacer()
            Button(action: onContinue) {
                Text("I'm \(player.displayName) — show my board")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 13))
                    .foregroundStyle(Theme.dirt)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.dirt)
    }
}
#endif
