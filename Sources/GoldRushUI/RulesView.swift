#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// The instruction book, reachable from the menu before a game starts.
///
/// Written to be read cold: someone handed the phone who has never seen the
/// game should be able to play a round from this alone. It leans on the real
/// card art rather than describing it in words, and takes its family blurbs
/// and deck counts from the engine, so a retune cannot leave the rules
/// describing a game the app no longer plays.
public struct RulesView: View {
    public let onDismiss: (() -> Void)?

    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                premise
                firstGame
                theRound
                theDeck
                sets
                scoringCards
                whatYouCannotSee
                lastRounds
                winning
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 34)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .top) { titleBar }
    }

    // MARK: - Chrome

    @ViewBuilder
    var titleBar: some View {
        HStack {
            Text("How to Play")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            Spacer()
            if let onDismiss {
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            ZStack(alignment: .bottom) {
                Theme.dirtDeep.opacity(0.96)
                Rectangle()
                    .fill(Theme.gold.opacity(0.22))
                    .frame(height: 1)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    var premise: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Split the claim.\nLet them choose.")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(Theme.goldBright)
                .fixedSize(horizontal: false, vertical: true)
            Text("""
                 You know this one. Two children, one slice of cake: whoever \
                 cuts it, the other picks first. Suddenly the cutter is very \
                 careful.

                 That is the whole game. You divide a handful of cards into \
                 two piles, and your opponent takes whichever they want. Cut \
                 it evenly and they have no good choice. Cut it greedily and \
                 they will simply take the better half and leave you the \
                 scraps.
                 """)
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Theme.parchment.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            calloutBox("If you only remember one thing",
                       "Cut so that you would be happy with either pile. "
                       + "Because you might get either one.")
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    var theRound: some View {
        section("A round, step by step") {
            VStack(alignment: .leading, spacing: 11) {
                step(1, "You privately draw **7 cards**. Your opponent cannot see them.")
                step(2, "You deal them into **two piles**. Each needs at least one card, and the app keeps them within one card of each other.")
                step(3, "You turn **one card face down**, in whichever pile you like. Your opponent will have to choose without knowing what it is.")
                step(4, "Your opponent takes a pile. **You keep the other one.**")
                step(5, "Whoever ends up holding a face-down card gets to look at it. The other player never does.")

                divider
                Text("Who splits when")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.gold.opacity(0.9))
                bullet("**Together** (the default) — you both split your own pile at the same time, then you each choose from the other's. **4 rounds.** Nobody waits.")
                bullet("**Take turns** — one of you splits while the other waits, then you swap. **8 rounds.**")
                Text("Either way you split four times and choose four times, and the same 60 cards come out. Pick it on the home screen.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.parchment.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The three things a new player actually needs, before any detail.
    @ViewBuilder
    var firstGame: some View {
        section("If this is your first game") {
            VStack(alignment: .leading, spacing: 10) {
                bullet("**You are collecting mining cards.** They are worth nothing by themselves — your scoring cards decide what counts.")
                bullet("**Look at your scoring cards before you split.** They are the only thing that tells you which pile is actually better.")
                bullet("**Sets beat singles.** An Ore with a Shovel is worth far more than two loose Ore. Never split a pair across both piles if you can help it.")
                Text("Play a round against the prospector and it will make sense faster than reading will.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.parchment.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    var theDeck: some View {
        section("The claim") {
            VStack(alignment: .leading, spacing: 10) {
                Text("72 cards. 60 of them get dealt over the eight rounds — so a dozen never come out at all.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.parchment.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 7) {
                    ForEach(MiningType.allCases, id: \.rawValue) { type in
                        deckRow(type)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    func deckRow(_ type: MiningType) -> some View {
        HStack(spacing: 11) {
            MiningCardView(type: type, size: .chip)
            VStack(alignment: .leading, spacing: 1) {
                Text(type.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.parchment)
                Text(deckNote(type))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.parchment.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Text("\(MiningDeck.standardCounts[type])")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.gold)
        }
    }

    func deckNote(_ type: MiningType) -> String {
        switch type {
        case .goldNugget: "The staple. Plenty of cards pay for these."
        case .foolsGold: "Worthless, and several cards punish holding it."
        case .goldOre: "Pairs with a Shovel."
        case .shovel: "Pairs with Gold Ore. Counts as a Tool."
        case .gravel: "Pairs with a Pan."
        case .pan: "Pairs with Gravel. Counts as a Tool."
        case .quartz: "Scarce. Some cards pay more for each one you add."
        case .packMule: "Wild — fills a Shovel or a Pan slot. Counts as a Tool."
        }
    }

    @ViewBuilder
    var sets: some View {
        section("Sets") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Two pairs match up one-for-one. A set is worth far more than its halves.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.parchment.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    pairing(.goldOre, .shovel)
                    pairing(.gravel, .pan)
                }
                .frame(maxWidth: .infinity)

                HStack(alignment: .top, spacing: 11) {
                    MiningCardView(type: .packMule, size: .chip)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("The Pack Mule")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.parchment)
                        Text("""
                             Each Mule stands in for **one** Shovel **or** one Pan — \
                             its choice, whichever earns you more. It won't satisfy a \
                             card that pays per Shovel or per Pan, but it always \
                             counts as one Tool.

                             The app works out the best arrangement for you at scoring.
                             """)
                            .font(.system(size: 12))
                            .lineSpacing(2)
                            .foregroundStyle(Theme.parchment.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    func pairing(_ a: MiningType, _ b: MiningType) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                MiningCardView(type: a, size: .chip)
                Text("+")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.gold)
                MiningCardView(type: b, size: .chip)
            }
            Text("\(a.shortName) + \(b.shortName)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.parchment.opacity(0.7))
        }
    }

    @ViewBuilder
    var scoringCards: some View {
        section("Scoring cards") {
            VStack(alignment: .leading, spacing: 11) {
                Text("""
                     Cards are only worth what your scoring cards say they are. \
                     You hold **six**, and **all six** count at the end — but only \
                     **three** are turned face up at the start. The other three stay \
                     secret all game.
                     """)
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .foregroundStyle(Theme.parchment.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    ForEach(ScoringFamily.allCases, id: \.rawValue) { family in
                        HStack(spacing: 10) {
                            Text(family.letter)
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.dirt)
                                .frame(width: 24, height: 24)
                                .background(Theme.gold, in: RoundedRectangle(cornerRadius: 6))
                            Text(family.displayName.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .tracking(0.7)
                                .foregroundStyle(Theme.parchment)
                                .frame(width: 72, alignment: .leading)
                            Text(family.rewardSummary)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.parchment.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }

                Text("""
                     Showing a card tells your opponent what to deny you — but it \
                     also forces them to cut piles that suit you. Hiding one keeps \
                     the surprise and lets them cut carelessly. Both are real \
                     choices; neither is obviously right.
                     """)
                    .font(.system(size: 12))
                    .lineSpacing(2)
                    .foregroundStyle(Theme.parchment.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)

                divider
                Text("Two ways to get them")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.gold.opacity(0.9))
                bullet("**Dealt** — six at random each, never more than two from one family.")
                bullet("**Drafted** — you get a pack of six, keep one, and pass the rest to your opponent. Back and forth until you both hold six. No luck of the deal — but note your opponent watches you take five of your six, so only your **very first pick** stays secret.")
                Text("Pick either one on the home screen before you start.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.parchment.opacity(0.55))
            }
        }
    }

    @ViewBuilder
    var whatYouCannotSee: some View {
        section("What you never learn") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 11) {
                    MiningCardView(type: nil, faceDown: true, size: .chip)
                    Text("""
                         If your opponent buries a card and you pass on that pile, \
                         that card is gone for good — you will never be told what it \
                         was. Not at scoring, not ever.
                         """)
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .foregroundStyle(Theme.parchment.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("""
                     Twelve cards are never dealt either. So neither player ever sees \
                     the whole picture — the tracker on the board counts what you have \
                     not seen, and that is genuinely all anyone knows.
                     """)
                    .font(.system(size: 12))
                    .lineSpacing(2)
                    .foregroundStyle(Theme.parchment.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    var lastRounds: some View {
        section("The last two rounds") {
            Text("""
                 The final round is bigger: **9 cards** instead of 7, and \
                 **two** turned face down instead of one. Twice the cards \
                 hidden, twice the guessing. Games are usually won or lost \
                 here, so keep something in reserve for it.
                 """)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(Theme.parchment.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    var winning: some View {
        section("Winning") {
            VStack(alignment: .leading, spacing: 9) {
                Text("After eight rounds every scoring card pays out, secret ones included. Highest total takes the claim.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.parchment.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                divider
                bullet("A card that pays for having **more** than your opponent pays nothing on a tie. You need strictly more.")
                bullet("Level on points? Most Gold Nugget wins. Still level? Fewest Fool's Gold. Still level after that, Player 2 takes it.")
            }
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.gold.opacity(0.85))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.dirtLight.opacity(0.38), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.gold.opacity(0.12), lineWidth: 1)
        }
    }

    /// A single sentence worth more than the paragraph around it.
    @ViewBuilder
    func calloutBox(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.dirt.opacity(0.7))
            Text(body)
                .font(.system(size: 13, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(Theme.dirt)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gold, in: RoundedRectangle(cornerRadius: 11))
    }

    @ViewBuilder
    func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.dirt)
                .frame(width: 21, height: 21)
                .background(Theme.gold, in: Circle())
            Text(.init(text))
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(Theme.parchment.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.gold.opacity(0.75))
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(.init(text))
                .font(.system(size: 12.5))
                .lineSpacing(2)
                .foregroundStyle(Theme.parchment.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    var divider: some View {
        Rectangle()
            .fill(Theme.gold.opacity(0.15))
            .frame(height: 1)
            .padding(.vertical, 1)
    }
}
#endif
