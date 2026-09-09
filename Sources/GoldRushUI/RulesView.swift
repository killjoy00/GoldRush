#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// The instruction book, ordered for a first game: core decision first, edge
/// cases and reference material later. Every statement here mirrors an engine
/// rule rather than an AI preference.
public struct RulesView: View {
    public let onDismiss: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    var wide: Bool { sizeClass == .regular }

    /// Everything here was typeset for a phone. Left alone on a 13-inch iPad
    /// it is a wall of 12-point text, so every size goes through `pt`.
    var scale: CGFloat { wide ? 1.3 : 1 }

    func pt(_ base: CGFloat) -> CGFloat { base * scale }

    /// The column the prose is allowed to fill.
    ///
    /// Scaled by the same factor as the type, so the measure -- characters per
    /// line, which is what actually governs readability -- stays where it was
    /// tuned on a phone. Filling an iPad's width instead gives lines of about
    /// 160 characters, which is roughly twice what anyone can track.
    var columnWidth: CGFloat { wide ? Widths.readable * scale : .infinity }

    /// The sections, in reading order, so the index and the page cannot drift
    /// apart: both are built from this list.
    enum Section: String, CaseIterable, Hashable {
        case goal, setup, round, formats, scoring, information, motherlode, winning, reference

        var label: String {
            switch self {
            case .goal: "Goal"
            case .setup: "Setup"
            case .round: "A round"
            case .formats: "Formats"
            case .scoring: "Scoring"
            case .information: "Hidden"
            case .motherlode: "Motherlode"
            case .winning: "Winning"
            case .reference: "Families"
            }
        }
    }

    public var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: pt(18)) {
                    hero
                    index(scroller)
                    goal.id(Section.goal)
                    setup.id(Section.setup)
                    round.id(Section.round)
                    formats.id(Section.formats)
                    scoring.id(Section.scoring)
                    information.id(Section.information)
                    motherlode.id(Section.motherlode)
                    winning.id(Section.winning)
                    reference.id(Section.reference)
                }
                .padding(.horizontal, pt(18))
                .padding(.top, pt(14))
                .padding(.bottom, pt(34))
                // Prose is capped and centred rather than filling the display.
                .frame(maxWidth: columnWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.background)
        .safeAreaInset(edge: .top) { titleBar }
    }

    /// Jump straight to a section.
    ///
    /// Nine sections is a reference document, not a story: the common visit is
    /// someone mid-game wanting one specific rule back, and making them scroll
    /// past everything else to find it is the main thing wrong with a long
    /// rules page.
    @ViewBuilder
    func index(_ scroller: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: pt(7)) {
            Text("JUMP TO")
                .font(.system(size: pt(9), weight: .heavy))
                .tracking(0.9)
                .foregroundStyle(Theme.gold.opacity(0.78))
            FlowRow(spacing: pt(6)) {
                ForEach(Section.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            scroller.scrollTo(section, anchor: .top)
                        }
                    } label: {
                        Text(section.label)
                            .font(.system(size: pt(11), weight: .semibold))
                            .foregroundStyle(Theme.parchment.opacity(0.85))
                            .padding(.horizontal, pt(10))
                            .padding(.vertical, pt(6))
                            .background(Theme.dirtDeep.opacity(0.65), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    var titleBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("HOW TO PLAY")
                    .font(.system(size: pt(18), weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldBright)
                Text("Gold Rush · Split the Claim")
                    .font(.system(size: pt(10), weight: .semibold))
                    .foregroundStyle(Theme.parchment.opacity(0.5))
            }
            Spacer()
            if let onDismiss {
                Button("Done", action: onDismiss)
                    .font(.system(size: pt(14), weight: .semibold))
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
                .font(.system(size: pt(23), weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            Text("When it is your turn to split, you divide your cards into two piles and your opponent picks first. So build two piles you would be happy to keep — because you get whichever one they walk away from.")
                .font(.system(size: pt(13)))
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
            Text("Collect mining cards that pay off your six scoring cards. Once all 60 cards in play have been claimed, every scoring card pays out and the higher score wins.")
            callout("The important twist", "The same card can be worth a fortune to you and almost nothing to your opponent. Your scoring cards are why an even split is rarely an equal one.")
        }
    }

    @ViewBuilder
    var setup: some View {
        ruleSection("2 · GET SIX SCORING CARDS", symbol: "rectangle.stack.fill") {
            Text("Pick one setup before the game starts:")
            miniHeader("DEALT")
            Text("You each get six scoring cards at random — three public, three secret.")

            miniHeader("DRAFTED")
            Text("You each open a separate pack of seven and pass it back and forth:")
            draftRail
            numbered(1, "From 7: take 1, pass the other 6.")
            numbered(2, "From 6: take 2, pass the other 4.")
            numbered(3, "From 4: take 2, pass the other 2.")
            numbered(4, "From the last 2: keep 1, burn the other face up.")
            Text("Your own pack comes back to you with four cards left, so you see exactly which two your opponent took.")
            Text("You end with six. Only your opening pick stays secret — everything after it passed through your opponent's hands.")
                .font(.system(size: pt(11), weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    var draftRail: some View {
        HStack(spacing: 5) {
            ForEach([7, 6, 4, 2], id: \.self) { count in
                Text("\(count)")
                    .font(.system(size: pt(12), weight: .heavy, design: .rounded))
                    .foregroundStyle(count == 7 || count == 2 ? Theme.dirt : Theme.parchment)
                    .frame(width: pt(29), height: pt(29))
                    .background(count == 7 || count == 2 ? Theme.gold : Theme.dirtLight,
                                in: Circle())
                if count != 2 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: pt(8), weight: .bold))
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
            numbered(1, "Draw your cards where your opponent cannot see them: 7 in a normal round.")
            numbered(2, "Divide the cards you drew between two piles. Neither may be empty, and they do not have to be the same size.")
            numbered(3, "Turn 1 card face down in either pile. You know what it is; your opponent has to choose without knowing.")
            numbered(4, "Your opponent takes one pile. You keep the other.")
            numbered(5, "Whoever takes a pile sees its face-down card. If your opponent leaves that pile with you, they never find out what it was.")
            callout("The splitter's test", "Would you be happy with either pile? If not, you have just made your opponent's choice an easy one.")
        }
    }

    @ViewBuilder
    var formats: some View {
        ruleSection("4 · TOGETHER OR TAKE TURNS", symbol: "person.2.fill") {
            formatRow("Together", "You both draw and split at the same time, then each of you chooses from the other's split. Four rounds.")
            formatRow("Take Turns", "One splits and the other chooses, then you swap. Eight rounds.")
            Text("Either way the same 60 mining cards come into play, and you each split four times and choose four times.")
                .font(.system(size: pt(11), weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    var scoring: some View {
        ruleSection("5 · WHAT SCORES", symbol: "star.fill") {
            Text("Your six scoring cards decide what is worth points. Some pay per mining type, some pay for reaching a threshold or holding more than your opponent, and some pay for completed sets.")
            miniHeader("SETS")
            HStack(spacing: 10) {
                setTile(.goldOre, .shovel, label: "Ore + Shovel")
                setTile(.gravel, .pan, label: "Gravel + Pan")
            }
            Text("A Pack Mule stands in for the Shovel in one Ore set, or the Pan in one Gravel set. Your Mules are always placed wherever they earn you the most.")
            Text("A Pack Mule counts as a Tool as well, for cards that pay for Tools.")
                .font(.system(size: pt(11), weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    var information: some View {
        ruleSection("6 · WHAT STAYS HIDDEN", symbol: "eye.slash.fill") {
            bullet("Dealt setup: three of your scoring cards are public and three stay secret. The same goes for your opponent.")
            bullet("Drafted setup: only your opening pick stays secret. Every later card passed through your opponent's hands, and both burns are face up.")
            bullet("While you are choosing between two piles, a face-down card is just a question mark.")
            bullet("Take a pile and you see its face-down cards. Decline it and you never find out — not at scoring, and not in the Claim Journal.")
            Text("The Unseen counter tracks everything you have not identified: cards never dealt this game, plus face-down cards you let your opponent keep.")
                .font(.system(size: pt(11), weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    @ViewBuilder
    var motherlode: some View {
        ruleSection("7 · THE MOTHERLODE", symbol: "sparkles") {
            Text("The last 18 mining cards come out in bigger handfuls.")
            bullet("Together: in round 4 you each draw 9 and turn 2 face down.")
            bullet("Take Turns: rounds 7 and 8 each draw 9 with 2 turned face down.")
            Text("Nothing else changes. Any two non-empty piles are legal, and the chooser still picks first.")
        }
    }

    @ViewBuilder
    var winning: some View {
        ruleSection("8 · WINNING", symbol: "crown.fill") {
            Text("After the last pile is claimed, each player's Mules are placed in whichever arrangement scores highest, and all six scoring cards pay out.")
            miniHeader("TIEBREAKS")
            numbered(1, "Most Gold Nuggets.")
            numbered(2, "Fewest Fool's Gold.")
            numbered(3, "Still level: Player 2 takes it.")
        }
    }

    @ViewBuilder
    var reference: some View {
        ruleSection("REFERENCE · SCORING FAMILIES", symbol: "books.vertical.fill") {
            ForEach(ScoringFamily.allCases, id: \.rawValue) { family in
                HStack(alignment: .top, spacing: 8) {
                    Text(family.letter)
                        .font(.system(size: pt(11), weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.dirt)
                        .frame(width: pt(25), height: pt(25))
                        .background(Theme.gold, in: RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(family.displayName)
                            .font(.system(size: pt(12), weight: .bold))
                            .foregroundStyle(Theme.parchment)
                        Text("Rewards \(family.rewardSummary).")
                            .font(.system(size: pt(11)))
                            .foregroundStyle(Theme.parchment.opacity(0.62))
                    }
                }
            }
            Text("Browse the full 48-card scoring deck from Cards on the main menu.")
                .font(.system(size: pt(11), weight: .semibold))
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
                    .font(.system(size: pt(12), weight: .bold))
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.system(size: pt(12), weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Theme.goldBright)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .font(.system(size: pt(12)))
            .foregroundStyle(Theme.parchment.opacity(0.72))
        }
        .padding(13)
        .background(Theme.dirtLight.opacity(0.34), in: RoundedRectangle(cornerRadius: 13))
    }

    @ViewBuilder
    func numbered(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: pt(10), weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.dirt)
                .frame(width: pt(21), height: pt(21))
                .background(Theme.gold, in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.gold.opacity(0.75))
                .frame(width: pt(5), height: pt(5))
                .padding(.top, pt(6))
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    func miniHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: pt(9), weight: .heavy))
            .tracking(0.9)
            .foregroundStyle(Theme.gold.opacity(0.78))
            .padding(.top, 2)
    }

    @ViewBuilder
    func callout(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: pt(9), weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(Theme.gold)
            Text(text)
                .font(.system(size: pt(11)))
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
                .font(.system(size: pt(12), weight: .bold))
                .foregroundStyle(Theme.parchment)
            Text(text)
                .font(.system(size: pt(11)))
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
                    .font(.system(size: pt(13), weight: .bold))
                    .foregroundStyle(Theme.gold)
                MiningCardView(type: b, size: .chip)
            }
            Text(label)
                .font(.system(size: pt(9), weight: .semibold))
                .foregroundStyle(Theme.parchment.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Theme.dirtDeep.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
    }
}
#endif
