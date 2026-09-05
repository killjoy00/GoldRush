#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine
import GoldRushAgents
import GoldRushUICore
#if canImport(GameKit)
import GameKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Routes to whichever screen the game is currently asking for.
public struct RootView: View {
    @Bindable public var model: GameViewModel
    public let onExit: (() -> Void)?
    public let onRematch: (() -> Void)?
    @State private var showTableau = false
    @State private var showJournal = false
    @State private var confirmLeave = false

    public init(model: GameViewModel,
                onExit: (() -> Void)? = nil,
                onRematch: (() -> Void)? = nil) {
        self.model = model
        self.onExit = onExit
        self.onRematch = onRematch
    }

    public var body: some View {
        ZStack {
            Theme.background

            switch model.screen {
            case .handoff(let player):
                HandoffView(player: player) { model.completeHandoff() }
                    .transition(.opacity)
            case .roundRecap:
                RoundRecapView(model: model) { model.acknowledgeRecap() }
                    .transition(.opacity)
            case .scoring:
                ScoringView(model: model, onExit: onExit, onRematch: onRematch)
            default:
                board
            }
        }
        .animation(.easeInOut(duration: 0.22), value: model.screen)
        .alert("Move not sent", isPresented: Binding(
            get: { model.submissionError != nil },
            set: { if !$0 { model.clearSubmissionError() } }
        )) {
            Button("OK", role: .cancel) { model.clearSubmissionError() }
        } message: {
            Text(model.submissionError ?? "Your move could not be saved. Please try again.")
        }
    }

    @ViewBuilder
    var board: some View {
        VStack(spacing: 10) {
            HUDView(view: model.view)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if !model.isLocalTurn && !model.isFinished {
                waitingForOpponent
            } else {
                switch model.screen {
                case .revealSelection:
                    RevealSelectionView(model: model)
                case .additionalReveal:
                    additionalReveal
                case .split:
                    SplitView(model: model)
                case .choose:
                    ChooseView(model: model)
                case .draft:
                    DraftView(model: model)
                case .draftDiscard:
                    draftDiscard
                default:
                    Spacer()
                }
            }

            HStack(spacing: 18) {
                Button {
                    showTableau = true
                } label: {
                    Label("My claim (\(model.view.collectionCounts.total))", systemImage: "square.stack.3d.up.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }

                Button {
                    showJournal = true
                } label: {
                    Label("Journal", systemImage: "book.closed.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }

                if onExit != nil {
                    Button {
                        confirmLeave = true
                    } label: {
                        Label("Leave", systemImage: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.parchment.opacity(0.5))
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .sheet(isPresented: $showTableau) {
            TableauView(view: model.view)
        }
        .sheet(isPresented: $showJournal) {
            ClaimJournalView(rounds: model.journalRounds)
        }
        .confirmationDialog("Leave this game?",
                            isPresented: $confirmLeave,
                            titleVisibility: .visible) {
            Button("Leave game", role: .destructive) { onExit?() }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("Pass-and-play and solo games can't be picked up again. An online match stays open — you can rejoin it from the menu.")
        }
    }

    @ViewBuilder
    var waitingForOpponent: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    Spacer(minLength: 12)
                    ProgressView().tint(Theme.gold)
                    Text("Waiting for your opponent")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.parchment)
                    Text(waitingDetail)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.parchment.opacity(0.65))
                        .padding(.horizontal, 40)
                    Text("You can close the app — it's your move when they're done.")
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.parchment.opacity(0.45))
                        .padding(.horizontal, 40)
                    Spacer(minLength: 12)
                }
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
        }
    }

    var waitingDetail: String {
        switch model.screen {
        case .split: "They're dividing this round's cards into two piles."
        case .choose: "They're choosing which pile to take."
        case .revealSelection: "They're choosing which scoring cards to reveal."
        case .additionalReveal: "They're revealing another scoring card."
        case .draft: "They're making a scoring-card draft decision."
        case .draftDiscard: "They're finishing an older scoring-card draft."
        default: "It's their turn."
        }
    }

    @ViewBuilder
    var additionalReveal: some View {
        VStack(spacing: 10) {
            Text("Reveal one more card")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.view.hand.filter { !model.view.myRevealed.contains($0) }, id: \.index) { id in
                        Button {
                            Task { await model.revealAdditional(id) }
                        } label: {
                            ScoringCardView(id: id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// Compatibility UI for a match that was already in the old post-draft
    /// discard phase when this version was installed.
    @ViewBuilder
    var draftDiscard: some View {
        VStack(spacing: 10) {
            Text("Throw one away")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            Text("This is an older seven-card draft. Keep six; your discard is public.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.parchment.opacity(0.65))
                .padding(.horizontal, 28)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.view.hand, id: \.index) { id in
                        Button {
                            Task { await model.draftDiscard(id) }
                        } label: {
                            ScoringCardView(id: id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// Entry screen: pick an opponent and start.
public struct NewGameView: View {
    enum LocalStart { case passAndPlay, solo }

    @State private var model: GameViewModel?
    @State private var localStart: LocalStart?
    @State private var showRules = false
    @State private var showCareer = false
    @State private var showCompendium = false
    @State private var difficulty = InferenceAgent.Fidelity.full
    @AppStorage("goldrush.scoringDraft") private var useDraft = false
    @AppStorage("goldrush.simultaneousSplit") private var splitTogether = true
    #if canImport(GameKit)
    @State private var showMatchmaker = false
    @State private var onlineError: String?
    @State private var showOnlineError = false
    #endif

    public init() {}

    public var body: some View {
        if let active = model {
            RootView(model: active,
                     onExit: { self.exitToMenu() },
                     onRematch: rematchAction)
                .id(ObjectIdentifier(active))
        } else {
            menu
        }
    }

    func exitToMenu() {
        #if canImport(GameKit)
        GameCenterTurnListener.shared.onTurnEvent = nil
        #endif
        model = nil
        localStart = nil
    }

    var rematchAction: (() -> Void)? {
        guard localStart != nil else { return nil }
        return { self.playAgain() }
    }

    func playAgain() {
        switch localStart {
        case .passAndPlay: startPassAndPlay()
        case .solo: startSolo()
        case nil: exitToMenu()
        }
    }

    @ViewBuilder
    var menu: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 780
            ScrollView {
                VStack(spacing: compact ? 10 : 18) {
                    Spacer(minLength: compact ? 4 : 12)
                    ZStack {
                        RadialGradient(colors: [Theme.ember.opacity(0.75), .clear],
                                       center: .center, startRadius: 6,
                                       endRadius: compact ? 74 : 108)
                        ForEach([-1.0, 1.0], id: \.self) { side in
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Theme.dirtDeep)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1.5)
                                }
                                .frame(width: compact ? 39 : 56, height: compact ? 57 : 82)
                                .rotationEffect(.degrees(21 * side))
                                .offset(x: (compact ? 21 : 31) * side, y: 2)
                        }
                        MiningArt(.goldNugget)
                            .frame(width: compact ? 58 : 84, height: compact ? 58 : 84)
                            .shadow(color: Theme.ember.opacity(0.9), radius: compact ? 10 : 14)
                    }
                    .frame(width: compact ? 132 : 190, height: compact ? 86 : 124)

                    VStack(spacing: compact ? 3 : 5) {
                        Text("GOLD RUSH")
                            .font(.system(size: compact ? 30 : 42, weight: .black, design: .rounded))
                            .tracking(compact ? 2.5 : 4)
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.goldBright, Theme.gold, Theme.goldDeep],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: .black.opacity(0.55), radius: 5, y: 3)
                        HStack(spacing: 9) {
                            rule
                            Text("SPLIT THE CLAIM")
                                .font(.system(size: compact ? 9 : 10, weight: .bold))
                                .tracking(2.4)
                                .foregroundStyle(Theme.parchment.opacity(0.75))
                                .fixedSize()
                            rule
                        }
                        .frame(maxWidth: 260)
                    }
                    Spacer(minLength: compact ? 2 : 8)

                    setupPicker(compact: compact)
                        .padding(.bottom, compact ? 0 : 4)

                    Button { startPassAndPlay() } label: {
                        menuLabel("Pass and play", "Two players, one device", filled: true, compact: compact)
                    }
                    Button { startSolo() } label: {
                        menuLabel("Play the prospector", "Single player vs the AI", filled: false, compact: compact)
                    }
                    #if canImport(GameKit)
                    Button { startOnline() } label: {
                        menuLabel("Play a friend online", onlineSubtitle, filled: false, compact: compact)
                    }
                    .disabled(!GameCenterAuth.shared.isSignedIn)
                    .opacity(GameCenterAuth.shared.isSignedIn ? 1 : 0.5)
                    #endif

                    HStack(spacing: 20) {
                        menuUtility("How to play", "book.closed.fill") { showRules = true }
                        menuUtility("Career", "chart.bar.fill") { showCareer = true }
                        menuUtility("Cards", "rectangle.stack.fill") { showCompendium = true }
                    }
                    .padding(.top, 2)

                    Spacer(minLength: compact ? 4 : 12)
                }
                .padding(.horizontal, compact ? 18 : 24)
                .padding(.vertical, compact ? 12 : 24)
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) { AdSlot.bannerView }
        .sheet(isPresented: $showRules) {
            RulesView { showRules = false }
        }
        .sheet(isPresented: $showCareer) {
            CareerStatsView()
        }
        .sheet(isPresented: $showCompendium) {
            ScoringCardCompendiumView()
        }
        #if canImport(GameKit)
        .sheet(isPresented: $showMatchmaker) {
            GameCenterMatchmakerView(
                onMatch: { match in
                    showMatchmaker = false
                    beginOnlineMatch(match)
                },
                onCancel: { showMatchmaker = false }
            )
            .ignoresSafeArea()
        }
        .alert("Couldn't start the match", isPresented: $showOnlineError) {
            Button("OK", role: .cancel) { onlineError = nil }
        } message: {
            Text(onlineError ?? "")
        }
        .task {
            GameCenterAuth.shared.authenticate { controller in
                presentFromTop(controller)
            }
        }
        #endif
    }

    @ViewBuilder
    var rule: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Theme.gold.opacity(0.55)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }

    @ViewBuilder
    func menuUtility(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.parchment.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    /// How the six scoring cards are handed out. Applies to every mode below.
    @ViewBuilder
    func setupPicker(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            Text("SCORING CARDS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.gold.opacity(0.8))
            Picker("Scoring cards", selection: $useDraft) {
                Text("Dealt").tag(false)
                Text("Drafted").tag(true)
            }
            .pickerStyle(.segmented)
            Text(useDraft
                 ? "Open 8: keep one, burn one, pass 6. Keep/pass to 2, then keep one and burn one."
                 : "Six dealt at random to each player.")
                .font(.system(size: compact ? 10 : 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.parchment.opacity(0.55))
                .frame(height: compact ? 30 : 30)

            Text("SPLITTING")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.gold.opacity(0.8))
                .padding(.top, 2)
            Picker("Splitting", selection: $splitTogether) {
                Text("Together").tag(true)
                Text("Take turns").tag(false)
            }
            .pickerStyle(.segmented)
            Text(splitTogether
                 ? "Both split at once, then both choose. 4 rounds, no waiting."
                 : "One splits, the other chooses, then swap. 8 rounds.")
                .font(.system(size: compact ? 10 : 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.parchment.opacity(0.55))
                .frame(height: compact ? 26 : 28)
        }
    }

    var config: GameConfig {
        GameConfig(scoringDraft: useDraft, simultaneousSplit: splitTogether)
    }

    @ViewBuilder
    func menuLabel(_ title: String, _ subtitle: String, filled: Bool, compact: Bool = false) -> some View {
        VStack(spacing: compact ? 1 : 3) {
            Text(title).font(.system(size: compact ? 15 : 16, weight: .semibold))
            Text(subtitle).font(.system(size: compact ? 10 : 11)).opacity(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 10 : 14)
        .background(filled ? Theme.gold : Theme.dirtLight, in: RoundedRectangle(cornerRadius: 13))
        .foregroundStyle(filled ? Theme.dirt : Theme.parchment)
    }

    func startPassAndPlay() {
        let seed = UInt64.random(in: 0..<UInt64.max)
        let state = GameState.newGame(config: config, seed: seed)
        localStart = .passAndPlay
        model = GameViewModel(state: state, transport: LocalTransport(state: state))
    }

    #if canImport(GameKit)
    var onlineSubtitle: String {
        switch GameCenterAuth.shared.status {
        case .signedIn(let name): "Game Center — \(name)"
        case .signedOut: "Sign in to Game Center first"
        case .failed: "Sign in to Game Center first"
        case .unknown: "Connecting to Game Center…"
        }
    }

    func startOnline() {
        showMatchmaker = true
    }

    func beginOnlineMatch(_ match: GKTurnBasedMatch) {
        do {
            let transport = try GameCenterTransport(match: match, config: config)
            localStart = nil
            model = GameViewModel(state: transport.state, transport: transport)
            GameCenterTurnListener.shared.start()
            let matchID = match.matchID
            GameCenterTurnListener.shared.onTurnEvent = { updatedID, _ in
                guard updatedID == matchID else { return }
                Task { try? await transport.refresh() }
            }
        } catch {
            onlineError = error.localizedDescription
            showOnlineError = true
        }
    }

    func presentFromTop(_ controller: Any) {
        guard let viewController = controller as? UIViewController else { return }
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewController, animated: true)
    }
    #endif

    func startSolo() {
        let seed = UInt64.random(in: 0..<UInt64.max)
        let state = GameState.newGame(config: config, seed: seed)
        let fidelity = difficulty
        let transport = AgentTransport(state: state, humanSeat: .p1, seed: seed &+ 1) { view, phase, rng in
            let agent = InferenceAgent(fidelity: fidelity)
            switch phase {
            case .revealSelection:
                return .selectRevealedScoringCards(
                    agent.selectReveal(view, count: view.config.initialRevealCount, rng: &rng))
            case .additionalReveal:
                let legal = view.hand.filter { !view.myRevealed.contains($0) }
                guard !legal.isEmpty else { return nil }
                return .revealAdditional(agent.revealAdditional(view, legal: legal, rng: &rng))
            case .split:
                let decision = agent.split(view, rng: &rng)
                return .split(pileA: decision.pileA, pileB: decision.pileB, faceDown: decision.faceDown)
            case .choose:
                return .choose(pile: agent.choose(view, rng: &rng))
            case .draft:
                return agent.draftAction(view, rng: &rng)
            case .draftDiscard:
                guard !view.hand.isEmpty else { return nil }
                return .draftDiscard(agent.draftDiscard(view, legal: view.hand, rng: &rng))
            case .finished:
                return nil
            }
        }
        localStart = .solo
        model = GameViewModel(state: state, transport: transport)
    }
}
#endif
