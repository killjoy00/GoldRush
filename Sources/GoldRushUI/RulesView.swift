#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// The instruction book, ordered for a first game: core decision first, edge
/// cases and reference material later. Every statement here mirrors an engine
/// rule rather than an AI preference.
public struct RulesView: View {
    public let onDismiss: (() -> Void)?

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                goal
                setup
                round
                formats
                scoring
                information
                motherlode
                winning
                reference
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 34)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .top) { titleBar }
    }

    @ViewBuilder
    var titleBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("HOW TO PLAY")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldBright)
                Text("Gold Rush · Split the Claim")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.parchment.opacity(0.5))
            }
            Spacer()
            if let onDismiss {
                Button("Done", action: onDismiss)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Theme.dirtDeep.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.gold.opacity(0.18)).frame(height: 1)
        }
    }

    @ViewBuilder
    var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Split the claim. Let them choose.")
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            Text("When you split, make two piles knowing your opponent gets first choice. Your job is to make both piles acceptable to you — because you keep whichever one they leave behind.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.parchment.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(
            LinearGradient(colors: [Theme.dirtLight.opacity(0.7), Theme.dirtDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 15)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(Theme.gold.opacity(0.28), lineWidth: 1)
        }
    }

    @ViewBuilder
    var goal: some View {
        ruleSection("1 · YOUR GOAL", symbol: "flag.checkered") {
            Text("Collect mining cards that pay your six scoring cards. After all 60 cards in play have been claimed, every scoring card pays out. Highest score wins.")
            callout("The important twist", "The same mining card can be excellent for you and nearly worthless to your opponent. Your scoring cards are what make a fair split difficult.")
        }
    }

    @ViewBuilder
    var setup: some View {
        ruleSection("2 · GET SIX SCORING CARDS", symbol: "rectangle.stack.fill") {
            Text("Choose one setup before the game:")
            miniHeader("DEALT")
            Text("Each player receives six scoring cards at random. Three are public and three stay secret.")

            miniHeader("DRAFTED")
            Text("Each player opens a separate pack of eight. The draft goes:")
            draftRail
            numbered(1, "From 8: keep 1, discard 1 face up, pass the other 6.")
            numbered(2, "From 6, 5, 4 and 3: keep 1 and pass the rest.")
            numbered(3, "From the final 2: keep 1 and discard 1 face up.")
            Text("You finish with six cards. Your opening keep is the one card from that pack your opponent never gets to see.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    var draftRail: some View {
        HStack(spacing: 5) {
            ForEach([8, 6, 5, 4, 3, 2], id: \.self) { count in
                Text("\(count)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(count == 8 || count == 2 ? Theme.dirt : Theme.parchment)
                    .frame(width: 29, height: 29)
                    .background(count == 8 || count == 2 ? Theme.gold : Theme.dirtLight,
                                in: Circle())
                if count != 2 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.gold.opacity(0.45))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    var round: some View {
        ruleSection("3 · PLAY A ROUND", symbol: "arrow.triangle.2.circlepath") {
            numbered(1, "Draw your cards privately: 7 in a normal round.")
            numbered(2, "Divide every drawn card between two non-empty piles. The piles do not have to be the same size.")
            numbered(3, "Turn 1 card face down anywhere in the two piles. You know what it is; your opponent must choose without seeing it.")
            numbered(4, "Your opponent takes one pile. You keep the other.")
            numbered(5, "A buried card is revealed to the player who ends up taking it. If your opponent leaves a buried card with you, they never learn what it was.")
            callout("The splitter's test", "Would you be happy getting either pile? If not, your opponent probably has an easy choice.")
        }
    }

    @ViewBuilder
    var formats: some View {
        ruleSection("4 · TOGETHER OR TAKE TURNS", symbol: "person.2.fill") {
            formatRow("Together", "Both players draw and make a split at the same time, then each chooses from the opponent's split. 4 rounds.")
            formatRow("Take Turns", "One player splits and the other chooses, then the roles alternate. 8 rounds.")
            Text("Both formats put the same 60 mining cards into play and give each player four splits and four choices.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    var scoring: some View {
        ruleSection("5 · WHAT SCORES", symbol: "star.fill") {
            Text("Your six scoring cards tell you exactly what is worth points. Some reward one mining type, some reward thresholds or majorities, and some reward sets.")
            miniHeader("SETS")
            HStack(spacing: 10) {
                setTile(.goldOre, .shovel, label: "Ore + Shovel")
                setTile(.gravel, .pan, label: "Gravel + Pan")
            }
            Text("A Pack Mule can fill the Shovel slot of one Ore set or the Pan slot of one Gravel set. The app automatically allocates your Mules where they score the most.")
            Text("A Pack Mule also counts as a Tool for scoring cards that reward Tools.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    var information: some View {
        ruleSection("6 · WHAT STAYS HIDDEN", symbol: "eye.slash.fill") {
            bullet("Dealt setup: three of each player's scoring cards are public; three are secret.")
            bullet("Drafted setup: your opening keep stays secret. Every later kept card passed through your opponent's hands, and both burns are face up.")
            bullet("While choosing a pile, face-down mining cards are unknown.")
            bullet("If you take a pile, you learn its buried cards. A buried card you decline remains unknown to you for the rest of the game — including in the Claim Journal.")
            Text("The Unseen counter combines cards that were never dealt with opponent cards you never identified.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    var motherlode: some View {
        ruleSection("7 · THE MOTHERLODE", symbol: "sparkles") {
            Text("The final 18 mining cards are bigger decisions.")
            bullet("Together: in round 4, each player draws 9 and buries 2.")
            bullet("Take Turns: rounds 7 and 8 each use a 9-card draw with 2 buried cards.")
            Text("The rules are otherwise unchanged: any two non-empty piles are legal, and the chooser still takes first pick.")
        }
    }

    @ViewBuilder
    var winning: some View {
        ruleSection("8 · WINNING", symbol: "crown.fill") {
            Text("After the final claim, the app chooses the best legal Pack Mule allocation and scores all six scoring cards for each player.")
            miniHeader("TIEBREAKS")
            numbered(1, "Most Gold Nuggets.")
            numbered(2, "Fewest Fool's Gold.")
            numbered(3, "If still tied, Player 2 wins the final tiebreak.")
        }
    }

    @ViewBuilder
    var reference: some View {
        ruleSection("REFERENCE · SCORING FAMILIES", symbol: "books.vertical.fill") {
            ForEach(ScoringFamily.allCases, id: \.rawValue) { family in
                HStack(alignment: .top, spacing: 8) {
                    Text(family.letter)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.dirt)
                        .frame(width: 25, height: 25)
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(family.displayName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.parchment)
                        Text("Rewards \(family.rewardSummary).")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.parchment.opacity(0.62))
                    }
                }
            }
            Text("Use Cards on the main menu to browse the full 48-card scoring deck.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .padding(.top, 3)
        }
    }

    @ViewBuilder
    func ruleSection<Content: View>(
        _ title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Theme.goldBright)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.parchment.opacity(0.72))
        }
        .padding(13)
        .background(Theme.dirtLight.opacity(0.34), in: RoundedRectangle(cornerRadius: 13))
    }

    @ViewBuilder
    func numbered(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.dirt)
                .frame(width: 21, height: 21)
                .background(Theme.gold, in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.gold.opacity(0.75)).frame(width: 5, height: 5).padding(.top, 6)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    func miniHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.9)
            .foregroundStyle(Theme.gold.opacity(0.78))
            .padding(.top, 2)
    }

    @ViewBuilder
    func callout(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(Theme.gold)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.parchment.opacity(0.7))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dirtDeep.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    func formatRow(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.parchment)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.parchment.opacity(0.62))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dirtDeep.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    func setTile(_ a: MiningType, _ b: MiningType, label: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                MiningCardView(type: a, size: .chip)
                Text("+")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.gold)
                MiningCardView(type: b, size: .chip)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.parchment.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Theme.dirtDeep.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
    }
}
#endif
