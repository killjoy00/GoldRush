import GoldRushEngine

/// Plays the opponent, not just the cards.
///
/// The insight it acts on: in I-cut-you-choose, the splitter's job is not to
/// make piles equal to itself but equal to the CHOOSER. A split that is even by
/// your own sheet hands the opponent a free pick whenever their sheet differs
/// from yours. So this agent equalises by its model of the opponent while
/// maximising what it keeps, and it places face-down cards where they are most
/// likely to make the opponent misjudge.
///
/// Everything it knows about the opponent comes from `PlayerView`: their three
/// public scoring cards and the part of their collection it has actually
/// observed. Their secret cards stay secret.
public struct InferenceAgent: GameAgent {
    /// How much of the reasoning to switch on. Backs the app's difficulty tiers.
    public enum Fidelity: Int, Sendable, CaseIterable {
        /// Equalise to the opponent, but do not reason about placement.
        case basic = 0
        /// Also place face-down cards to maximise expected misvaluation.
        case placement = 1
        /// Also model what the opponent will do with the split when choosing.
        case full = 2
    }

    public let fidelity: Fidelity
    /// Ablation only: see `OpponentModel.init(naiveFrom:)`.
    let useNaiveOpponentModel: Bool
    public var name: String {
        useNaiveOpponentModel ? "inference-naive-model" : "inference-\(fidelity)"
    }

    public init(fidelity: Fidelity = .full, useNaiveOpponentModel: Bool = false) {
        self.fidelity = fidelity
        self.useNaiveOpponentModel = useNaiveOpponentModel
    }

    func opponentModel(_ view: PlayerView) -> OpponentModel {
        useNaiveOpponentModel ? OpponentModel(naiveFrom: view) : OpponentModel(view: view)
    }

    public func selectReveal(
        _ view: PlayerView, count: Int, rng: inout SeededRNG
    ) -> [ScoringCardID] {
        // Reveal the cards that are hardest for an opponent to play around --
        // which, counter-intuitively, are the sharp ones.
        //
        // The intuitive policy is the opposite: hide your majority riders and
        // thresholds so they cannot be denied. The simulator measured all three
        // policies over 50,000 games each and found that intuition backwards, by
        // a wide margin (docs/SIM_FINDINGS.md §2):
        //
        //     reveal the sharp cards  56.8%
        //     reveal at random        ~50%
        //     hide the sharp cards    43.6%
        //
        // The reason is structural. In I-cut-you-choose the splitter must divide
        // the draw so the CHOOSER is indifferent. A splitter who cannot read you
        // guesses, and a guess is safe for them -- concealment lowers the
        // standard their split has to meet. Advertising a convex card instead
        // forces genuinely hard divisions, and every one they misjudge pays you.
        let ranked = view.hand.sorted { lhs, rhs in
            let l = disclosureValue(lhs)
            let r = disclosureValue(rhs)
            if l != r { return l > r }
            return lhs.index < rhs.index
        }
        return Array(ranked.prefix(count))
    }

    /// How much is gained by making this card public. Higher means reveal it.
    ///
    /// Scores how sharply a card's payout bends: riders and thresholds are the
    /// cards an opponent must work hardest to split around, and are therefore
    /// the ones worth showing them.
    public func disclosureValue(_ id: ScoringCardID) -> Int {
        var score = 0
        for effect in ScoringCardCatalog[id].effects {
            switch effect {
            case .bonusIfStrictlyMore, .bonusPerTypeStrictlyMore:
                score += 3  // denial is easy once known
            case .bonusIfAtLeast, .tieredByCount:
                score += 2  // a known threshold invites starving
            case .perTypeBeyond, .perNthScaling, .perNthLinear:
                score += 1  // convex in one type, so worth disguising
            default:
                break
            }
        }
        return score
    }

    public func split(_ view: PlayerView, rng: inout SeededRNG) -> SplitDecision {
        let types = typeLookup(view)
        let ids = view.currentDraw.map(\.id)
        let current = view.collectionCounts
        let hand = view.hand
        let model = opponentModel(view)
        let k = view.config.faceDownCount(round: view.round)

        func counts(_ pile: [CardID]) -> MiningCounts {
            MiningCounts.counting(pile.compactMap { types[$0] })
        }
        func ownValue(_ pile: [CardID]) -> Int {
            Valuation.marginal(adding: counts(pile), to: current, hand: hand)
        }
        func oppValue(_ pile: [CardID]) -> Int {
            model.value(adding: counts(pile))
        }

        // Maximin first, opponent model second.
        //
        // An earlier version of this maximised the pile the opponent was
        // predicted to leave behind. That lost to GreedyAgent 61/39 in both
        // seats, and the reason is instructive: the opponent model is built from
        // only three public scoring cards, so it is noisy, and betting the split
        // on it offers an exploitable pile every time the model is wrong.
        // Greedy's equalise-to-self is weak but never exploitable, and robustness
        // beat cleverness.
        //
        // So the primary objective is now the worst case: maximise
        // min(own value of A, own value of B). Whichever pile the opponent
        // takes, this agent's floor is as high as it can be made -- which is the
        // guarantee Greedy gets. The opponent model is demoted to a tie-breaker
        // among cuts that are equally good for this agent, where it steers the
        // opponent toward the pile this agent wants less. That keeps the edge
        // without ever paying for a bad read.
        var bestCut = (a: [ids[0]], b: Array(ids.dropFirst()))
        var bestFloor = -Double.infinity
        for cut in SplitEnumerator.cuts(of: ids) {
            // Near-equal size, for the reason documented on GreedyAgent: a
            // value-balanced cut can be six cards against one, and any chooser
            // who weighs volume takes the big pile every time. Maximin alone
            // measured 45.0% against a pile-counting baseline; with this it is
            // 61.7%.
            guard abs(cut.a.count - cut.b.count) <= GreedyAgent.sizeSlack else { continue }
            let ownA = Double(ownValue(cut.a)), ownB = Double(ownValue(cut.b))
            let floor = min(ownA, ownB)
            // Tie-break: nudge the opponent toward the pile costing this agent
            // less, scaled small enough that it can never override the floor.
            let oppA = Double(oppValue(cut.a)), oppB = Double(oppValue(cut.b))
            let steer = ownA <= ownB ? (oppA - oppB) : (oppB - oppA)
            let score = floor + 0.01 * steer
            if score > bestFloor {
                bestFloor = score
                bestCut = cut
            }
        }

        guard fidelity != .basic, k > 0 else {
            let byOwnValue = ids.sorted { ownValue([$0]) < ownValue([$1]) }
            return SplitDecision(
                pileA: bestCut.a, pileB: bestCut.b, faceDown: Array(byOwnValue.prefix(k))
            )
        }

        // Placement: turn face down the cards whose concealment most distorts
        // the opponent's read of the piles. A hidden card is priced by the
        // opponent at the average of THEIR unseen pool, so the exploitable cards
        // are the ones whose true value to them is furthest from that average.
        let poolAverage = averageCardValue(model: model)
        let candidates = SplitEnumerator.faceDownChoices(from: ids, count: k)
        var bestFaceDown = candidates.first ?? []
        var bestDistortion = -Double.infinity
        for candidate in candidates {
            var distortion = 0.0
            for id in candidate {
                let trueValue = Double(oppValue([id]))
                // Hiding a card the opponent would have valued highly makes them
                // underrate that pile; hiding junk makes them overrate it. Both
                // are useful, so the magnitude is what counts.
                distortion += abs(trueValue - poolAverage)
            }
            if distortion > bestDistortion {
                bestDistortion = distortion
                bestFaceDown = candidate
            }
        }

        return SplitDecision(pileA: bestCut.a, pileB: bestCut.b, faceDown: bestFaceDown)
    }

    /// What the opponent thinks an unknown card is worth on average.
    func averageCardValue(model: OpponentModel) -> Double {
        let pool = model.unseen.total
        guard pool > 0 else { return 0 }
        var sum = 0.0
        for type in MiningType.allCases where model.unseen[type] > 0 {
            var one = MiningCounts()
            one[type] = 1
            sum += Double(model.value(adding: one)) * Double(model.unseen[type]) / Double(pool)
        }
        return sum
    }

    public func choose(_ view: PlayerView, rng: inout SeededRNG) -> PileID {
        guard let piles = view.piles else { return .a }

        let a = Valuation.expectedMarginal(
            cards: piles.a, current: view.collectionCounts, hand: view.hand, unseen: view.unseen
        )
        let b = Valuation.expectedMarginal(
            cards: piles.b, current: view.collectionCounts, hand: view.hand, unseen: view.unseen
        )

        guard fidelity == .full else { return a >= b ? .a : .b }

        // The splitter had incentives, and the split is evidence about them.
        // A rational splitter hides cards it wants the opponent to misprice, and
        // it keeps the pile it prefers. So a pile carrying more face-down cards
        // is more likely to have been engineered -- discount it slightly.
        //
        // This is a correction, not a reversal: the expected values above still
        // decide, and the adjustment only breaks near-ties.
        let hiddenA = piles.a.count(where: \.isHidden)
        let hiddenB = piles.b.count(where: \.isHidden)
        let suspicion = 0.15
        let adjustedA = a - Double(hiddenA) * suspicion * abs(a)
        let adjustedB = b - Double(hiddenB) * suspicion * abs(b)
        return adjustedA >= adjustedB ? .a : .b
    }

    public func draftPick(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        var reference = MiningCounts()
        for entry in MiningDeck.standardComposition {
            reference[entry.type] = entry.count * 30 / MiningDeck.standardSize
        }
        var best = legal[0]
        var bestValue = Int.min
        for candidate in legal {
            // Prefer cards that compound with what is already held, which is what
            // makes a drafted hand more than six independently good cards.
            let value = Valuation.selfValue(counts: reference, hand: view.hand + [candidate])
            if value > bestValue {
                bestValue = value
                best = candidate
            }
        }
        return best
    }

    public func revealAdditional(
        _ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG
    ) -> ScoringCardID {
        legal.max { disclosureValue($0) < disclosureValue($1) } ?? legal[0]
    }
}
