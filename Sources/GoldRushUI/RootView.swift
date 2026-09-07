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
        // The board is centred inside a cap rather than filling the display.
        // A 13-inch iPad is wider than any of these screens wants to be, and
        // stretching them just moves the two piles further apart.
        .frame(maxWidth: Widths.board)
        .frame(maxWidth: .infinity)
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
    @State private var showRemoveAds = false
    @State private var difficulty = InferenceAgent.Fidelity.full
    @AppStorage("goldrush.scoringDraft") private var useDraft = false
    @AppStorage("goldrush.simultaneousSplit") private var splitTogether = true
    #if canImport(GameKit)
    @State private var showMatchmaker = false
    @State private var onlineError: String?
    @State private var showOnlineError = false
    #endif
    #if DEBUG
    /// Guards the screenshot setup so leaving a game back to the menu does not
    /// silently start another one.
    @State private var screenshotApplied = false
    #endif

    public init() {}

    public var body: some View {
        if let active = model {
            RootView(model: active,
                     onExit: { self.exitToMenu() },
                     onRematch: rematchAction)
                .id(ObjectIdentifier(active))
        } else {
            #if DEBUG
            menu.task { await applyScreenshotStateIfNeeded() }
            #else
            menu
            #endif
        }
    }

    #if DEBUG
    /// Puts the app on the screen a capture run asked for.
    ///
    /// Attached to the menu rather than driven by synthesised taps: the states
    /// worth photographing are all reachable by setting what a tap would have
    /// set, and that survives any amount of layout churn. Runs once -- the
    /// menu reappears when a game is left, and re-entering the screenshot
    /// state then would restart a game underneath whoever is looking.
    @MainActor
    func applyScreenshotStateIfNeeded() async {
        guard ScreenshotMode.isActive, !screenshotApplied else { return }
        screenshotApplied = true

        switch ScreenshotMode.screen {
        case .home:
            break
        case .rules:
            showRules = true
        case .compendium:
            showCompendium = true
        case .removeAds:
            #if canImport(StoreKit)
            showRemoveAds = true
            #endif
        case .draft:
            // A drafted game opens directly into the draft, so this needs no
            // scripting beyond choosing the mode.
            useDraft = true
            startSolo(seed: ScreenshotMode.seed)
        case .split:
            // Splitting is the game's central act, and it is one committed
            // reveal away from a new dealt game. Picking the first three cards
            // is the same action the player would take; nothing is fabricated,
            // the deal is simply a fixed one.
            useDraft = false
            startSolo(seed: ScreenshotMode.seed)
            guard let model else { break }
            for id in model.view.hand.prefix(model.view.config.initialRevealCount) {
                model.toggleReveal(id)
            }
            await model.confirmReveal()
            // A fresh split puts every card in pile A with nothing turned
            // down, which is the one arrangement the validator rejects. The
            // first capture run therefore photographed three red errors and a
            // dead confirm button -- a picture of the app refusing to work.
            // The split is arranged here the way a player would arrange it,
            // through the same builder the UI drives, so the frame shows the
            // mechanic mid-decision rather than a fabricated state.
            if let builder = model.splitBuilder {
                for id in builder.draw.map(\.id).suffix(3) {
                    builder.move(id, to: .b)
                }
                // Face down in the pile the opponent is being offered: that is
                // the interesting case, and the one the screen exists to show.
                if let hidden = builder.pileB.last {
                    builder.toggleFaceDown(hidden)
                }
            }
        }
    }
    #endif

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
            // Wide enough for the brandmark and the controls to sit beside each
            // other. Checked against the actual width rather than the size class
            // because this is a question about geometry, and an iPad in
            // landscape has room for two columns while the same iPad in a narrow
            // Split View does not.
            let wide = proxy.size.width >= 780
            ScrollView {
                Group {
                    if wide {
                        // Both columns take their natural width and the pair
                        // is centred. Letting the brandmark expand pushed the
                        // logo and the buttons to opposite edges of the screen,
                        // which read as two unrelated things rather than one
                        // menu. `Widths.menu` is only an upper bound.
                        HStack(alignment: .center, spacing: 56) {
                            brandmark(compact: false)
                            menuControls(compact: false)
                                .frame(width: 360)
                        }
                        .frame(maxWidth: Widths.menu)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: compact ? 10 : 18) {
                            Spacer(minLength: compact ? 4 : 12)
                            brandmark(compact: compact)
                            Spacer(minLength: compact ? 2 : 8)
                            menuControls(compact: compact)
                            Spacer(minLength: compact ? 4 : 12)
                        }
                    }
                }
                .padding(.horizontal, compact ? 18 : 24)
                .padding(.vertical, compact ? 12 : 24)
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) { adFooter }
        .sheet(isPresented: $showRules) {
            RulesView { showRules = false }
        }
        .sheet(isPresented: $showCareer) {
            CareerStatsView()
        }
        .sheet(isPresented: $showCompendium) {
            ScoringCardCompendiumView()
        }
        #if canImport(StoreKit)
        .sheet(isPresented: $showRemoveAds) {
            RemoveAdsView { showRemoveAds = false }
        }
        // Started here rather than in the sheet so the entitlement is known
        // before the banner is laid out. A player who already paid should
        // never see it flash up on launch.
        .task { await RemoveAdsStore.shared.start() }
        #endif
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

    /// The logo, the wordmark and the tagline.
    ///
    /// Extracted so the stacked and side-by-side menus render the same thing
    /// rather than two copies that drift apart the first time either is edited.
    @ViewBuilder
    func brandmark(compact: Bool) -> some View {
        VStack(spacing: compact ? 3 : 5) {
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
            .padding(.bottom, compact ? 6 : 10)

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
    }

    /// The setup pickers, the three ways to play, and the utility row.
    @ViewBuilder
    func menuControls(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 18) {
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
            .opacity(onlineLooksAvailable ? 1 : 0.5)
            #endif

            HStack(spacing: 20) {
                menuUtility("How to play", "book.closed.fill") { showRules = true }
                menuUtility("Career", "chart.bar.fill") { showCareer = true }
                menuUtility("Cards", "rectangle.stack.fill") { showCompendium = true }
            }
            .padding(.top, 2)
        }
    }

    /// The banner, and the way to be rid of it.
    ///
    /// Both are gated on an ad actually being installed. A build with no ad
    /// slot filled -- Linux, a preview, the screenshot runs -- has nothing to
    /// remove, so offering to sell that would be selling nothing.
    @ViewBuilder
    var adFooter: some View {
        #if canImport(StoreKit)
        if AdSlot.banner != nil, !RemoveAdsStore.shared.isPurchased {
            VStack(spacing: 0) {
                Button { showRemoveAds = true } label: {
                    Text("Remove ads")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.parchment.opacity(0.5))
                        .padding(.vertical, 5)
                }
                AdSlot.bannerView
            }
        }
        #else
        AdSlot.bannerView
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
    /// Whether the online button should *look* live.
    ///
    /// Deliberately separate from `.disabled`, which stays tied to the real
    /// sign-in state: in a capture the button reads as available but still
    /// cannot open a matchmaker nobody is there to dismiss.
    var onlineLooksAvailable: Bool {
        #if DEBUG
        if ScreenshotMode.isActive { return true }
        #endif
        return GameCenterAuth.shared.isSignedIn
    }

    var onlineSubtitle: String {
        #if DEBUG
        // A capture simulator has no Game Center account, and the handler that
        // would resolve the status is deliberately never installed -- so the
        // status sits at `.unknown` forever and the button photographs greyed
        // out under "Connecting to Game Center...", which reads as broken.
        // The mode is described instead. That is true of the button whoever is
        // signed in, where claiming an account would be inventing one.
        if ScreenshotMode.isActive { return "Turn-based, on two devices" }
        #endif
        // Explicit `return`: the guard above makes this body multi-statement
        // in Debug, so the switch can no longer be an implicit return.
        return switch GameCenterAuth.shared.status {
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

    /// The seed is a parameter so a screenshot run can deal the same hand
    /// every time. Two captures of the same screen that differ for no reason
    /// would make the workflow's duplicate check meaningless.
    func startSolo(seed: UInt64 = UInt64.random(in: 0..<UInt64.max)) {
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
