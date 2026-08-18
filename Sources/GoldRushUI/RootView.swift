#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine
import GoldRushAgents
import GoldRushUICore

/// Routes to whichever screen the game is currently asking for.
public struct RootView: View {
    @Bindable public var model: GameViewModel
    @State private var showTableau = false

    public init(model: GameViewModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            Theme.dirt.ignoresSafeArea()

            switch model.screen {
            case .handoff(let player):
                HandoffView(player: player) { model.completeHandoff() }
                    .transition(.opacity)
            case .scoring:
                ScoringView(model: model)
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

            Button {
                showTableau = true
            } label: {
                Label("My claim (\(model.view.collectionCounts.total))", systemImage: "square.stack.3d.up.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
            .padding(.bottom, 6)
        }
        .sheet(isPresented: $showTableau) {
            TableauView(view: model.view)
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
            Text("Draft a scoring card")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            Text("You hold \(model.view.hand.count) of \(GameConfig.handSize)")
                .font(.system(size: 11))
                .foregroundStyle(Theme.parchment.opacity(0.65))
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
    @State private var model: GameViewModel?
    @State private var difficulty = InferenceAgent.Fidelity.full

    public init() {}

    public var body: some View {
        if let model {
            RootView(model: model)
        } else {
            menu
        }
    }

    @ViewBuilder
    var menu: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.gold)
            Text("GOLD RUSH")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(Theme.goldBright)
            Text("Split the claim. Let them choose.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.parchment.opacity(0.7))
            Spacer()

            Button { startPassAndPlay() } label: {
                menuLabel("Pass and play", "Two players, one device", filled: true)
            }
            Button { startSolo() } label: {
                menuLabel("Play the prospector", "Single player vs the AI", filled: false)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.dirt)
    }

    @ViewBuilder
    func menuLabel(_ title: String, _ subtitle: String, filled: Bool) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 16, weight: .semibold))
            Text(subtitle).font(.system(size: 11)).opacity(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(filled ? Theme.gold : Theme.dirtLight, in: RoundedRectangle(cornerRadius: 13))
        .foregroundStyle(filled ? Theme.dirt : Theme.parchment)
    }

    func startPassAndPlay() {
        let seed = UInt64.random(in: 0..<UInt64.max)
        let state = GameState.newGame(seed: seed)
        model = GameViewModel(state: state, transport: LocalTransport(state: state))
    }

    func startSolo() {
        let seed = UInt64.random(in: 0..<UInt64.max)
        let state = GameState.newGame(seed: seed)
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
        model = GameViewModel(state: state, transport: transport)
    }
}
#endif
