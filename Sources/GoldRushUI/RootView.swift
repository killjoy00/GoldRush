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
    /// Back to the menu. Optional because the view is perfectly usable
    /// somewhere that has nowhere to go back to; supplied by whoever presented
    /// the game, which is the only thing that knows what "back" means.
    public let onExit: (() -> Void)?
    /// Start another game set up the same way.
    public let onRematch: (() -> Void)?
    @State private var showTableau = false
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
    }

    @ViewBuilder
    var board: some View {
        VStack(spacing: 10) {
            HUDView(view: model.view)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if !model.isLocalTurn && !model.isFinished {
                // Remote play only. The board stays visible -- the opponent's
                // move is worth watching for -- but nothing is interactive,
                // and what is on screen is still only this player's own view.
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
                    draft
                default:
                    Spacer()
                }
            }

            HStack(spacing: 20) {
                Button {
                    showTableau = true
                } label: {
                    Label("My claim (\(model.view.collectionCounts.total))", systemImage: "square.stack.3d.up.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
                // Without this a match that stalls -- an opponent who never
                // takes their turn -- leaves the app with no route out of it
                // but force-quitting.
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
        // GeometryReader + ScrollView so a canvas shorter than an iPhone's --
        // iPad's compatibility mode for an iPhone-only app renders one -- can
        // scroll this instead of clipping it top and bottom.
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
        case .draft: "They're drafting a scoring card."
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

    @ViewBuilder
    var draft: some View {
        VStack(spacing: 10) {
            Text(model.view.hand.isEmpty ? "Open your pack" : "Take one card")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            // The opening pick is the one card the opponent never sees, and it
            // is worth saying so out loud: it is the only secret either player
            // gets in a drafted game, and it is gone after this tap.
            Text(model.view.hand.isEmpty
                 ? "This pick stays secret. Everything you take after it, your opponent will see."
                 : "Take one, pass the rest. You hold \(model.view.hand.count) of \(GameConfig.handSize).")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.parchment.opacity(0.65))
                .padding(.horizontal, 28)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.draftLegalPicks, id: \.index) { id in
                        Button {
                            Task { await model.draftPick(id) }
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
    /// How the running game was started, so "Play again" can start another the
    /// same way. Nil for a Game Center match, which needs matchmaking rather
    /// than a button.
    enum LocalStart { case passAndPlay, solo }

    @State private var model: GameViewModel?
    @State private var localStart: LocalStart?
    @State private var showRules = false
    @State private var difficulty = InferenceAgent.Fidelity.full
    /// Drafting is offered rather than imposed. The simulator found a 25-point
    /// win-rate spread between the best and worst scoring card to be dealt, and
    /// drafting removes that luck entirely -- but it also adds a phase to the
    /// start of every game, which is a matter of taste rather than balance.
    @AppStorage("goldrush.scoringDraft") private var useDraft = false
    /// Defaults on. Waiting through your opponent's whole turn is the single
    /// worst thing about a remote game, and splitting together halves it --
    /// four rounds of two splits deal the same 60 cards as eight rounds of
    /// one. Kept as one setting across every mode rather than "online is a
    /// different game", and it travels inside the match data, so both devices
    /// play whatever the host chose.
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
                // A rematch replaces the view model, and this makes SwiftUI
                // treat that as a new screen rather than reusing the old one's
                // state (an open tableau sheet, a half-finished dialog).
                .id(ObjectIdentifier(active))
        } else {
            menu
        }
    }

    /// Ends the running game and returns to the menu.
    func exitToMenu() {
        #if canImport(GameKit)
        // Stop turn events refreshing a match nothing is showing any more.
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
        // GeometryReader + ScrollView rather than a bare VStack: on a canvas
        // shorter than an iPhone's -- iPad's compatibility mode for an
        // iPhone-only app renders one -- the fixed VStack this used to be had
        // nowhere to put the overflow and simply clipped it top and bottom.
        // `minHeight: proxy.size.height` keeps today's vertically-centered
        // look on a normal screen (the Spacers still expand to fill it) while
        // letting a shorter one scroll instead of clip.
        GeometryReader { proxy in
            // On a short canvas the full-size hero and title simply do not
            // leave room for the buttons, and a ScrollView alone does not
            // solve that: App Review looks at the screen rather than
            // scrolling it, and reported the bottom "cut off" even once it
            // scrolled. So the chrome shrinks to make the whole menu fit.
            // 780pt keeps every current iPhone (844pt and up) on the full-size
            // layout; it catches the small ones and iPad's iPhone-compatibility
            // window, which is what App Review saw.
            let compact = proxy.size.height < 780
            ScrollView {
                VStack(spacing: compact ? 10 : 18) {
                    Spacer(minLength: compact ? 4 : 12)
                    // The app icon's composition, rebuilt in vectors: two cards fanned
                    // behind a nugget. The title screen and the home screen should be
                    // recognisably the same object.
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
                        // A hairline rule either side of the tagline, the way a claim
                        // notice would have been set.
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

                    Button { showRules = true } label: {
                        Label("How to play", systemImage: "book.closed.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.parchment.opacity(0.7))
                            .padding(.top, 2)
                    }
                    .sheet(isPresented: $showRules) {
                        RulesView { showRules = false }
                    }

                    Spacer(minLength: compact ? 4 : 12)
                }
                .padding(.horizontal, compact ? 18 : 24)
                .padding(.vertical, compact ? 12 : 24)
                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            }
        }
        .background(Theme.background)
        // Pinned to the home screen rather than How to play: this is the
        // screen every session opens on, so it is the one placement that
        // shows an ad without ever being able to land mid-decision -- nothing
        // here is a board, a split, or a choice.
        .safeAreaInset(edge: .bottom) { AdSlot.bannerView }
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
                // Game Center's sign-in screen has to be presented from UIKit,
                // so it is handed to the topmost view controller rather than
                // routed through SwiftUI.
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
                 ? "Open a pack, take one card, pass the rest. No luck of the deal."
                 : "Six dealt at random to each player.")
                .font(.system(size: compact ? 10 : 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.parchment.opacity(0.55))
                // Fixed so the layout does not jump as the caption changes
                // length. Two lines at the compact size still fit in 26.
                .frame(height: compact ? 26 : 28)

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
        // GameKit's own wording here is a sentence of internal jargon --
        // "The requested operation could not be completed because local
        // player has not been authenticated" -- and it wraps to two lines
        // inside the button. It is also the state any device that is simply
        // not signed in lands in, App Review's included, so it is the string
        // most people see rather than an edge case. The underlying message
        // stays available on GameCenterAuth.status for diagnosis.
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
            // Keep playing while the app is open: when the opponent moves,
            // Game Center pushes the event and the board reloads in place
            // rather than waiting for the player to back out and return.
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
                let legal = view.draftPool.filter { candidate in
                    view.hand.count { $0.family == candidate.family } < GameConfig.familyCap
                }
                guard !legal.isEmpty else { return nil }
                return .draftPick(agent.draftPick(view, legal: legal, rng: &rng))
            case .finished:
                return nil
            }
        }
        localStart = .solo
        model = GameViewModel(state: state, transport: transport)
    }
}
#endif
