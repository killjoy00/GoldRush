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
    public var name: String { "inference-\(fidelity)" }

    public init(fidelity: Fidelity = .full) {
        self.fidelity = fidelity
    }

    public func selectReveal(
        _ view: PlayerView, count: Int, rng: inout SeededRNG
    ) -> [ScoringCardID] {
        // Revealing is a real decision, not decoration: a public card is one the
        // opponent can split around, so it should be a card whose value does not
        // depend on catching them by surprise.
        //
        // Keep secret: opponent-relative riders (they can be denied once known)
        // and cards with sharp thresholds (a known threshold is easy to starve).
        // Reveal: flat per-card rates, which are hard to play around and which
        // encourage the opponent to hand over piles this agent wants anyway.
        let ranked = view.hand.sorted { lhs, rhs in
            let l = concealmentValue(lhs)
            let r = concealmentValue(rhs)
            if l != r { return l < r }
            return lhs.index < rhs.index
        }
        return Array(ranked.prefix(count))
    }

    /// How much is gained by keeping this card secret. Higher means hide it.
    public func concealmentValue(_ id: ScoringCardID) -> Int {
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
        let model = OpponentModel(view: view)
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

        // Choose the cut that leaves the opponent closest to indifferent, and
        // break near-ties toward the split that keeps this agent the most.
        //
        // The opponent takes whichever pile they prefer, so what this agent
        // actually receives is the one they reject. Maximising the value of the
        // pile they are LIKELY TO LEAVE is the real objective; equalising to
        // them is the constraint that stops them taking a windfall.
        var bestCut = (a: [ids[0]], b: Array(ids.dropFirst()))
        var bestScore = -Double.infinity
        for cut in SplitEnumerator.cuts(of: ids) {
            let oppA = oppValue(cut.a), oppB = oppValue(cut.b)
            let gap = abs(oppA - oppB)
            // What this agent expects to keep: whichever pile the opponent
            // declines under its model of them.
            let kept = oppA >= oppB ? ownValue(cut.b) : ownValue(cut.a)
            // Penalise the gap so an obviously lopsided pile is not offered, but
            // let a genuinely better residual pay for a small imbalance.
            let score = Double(kept) - 1.5 * Double(gap)
            if score > bestScore {
                bestScore = score
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
        legal.min { concealmentValue($0) < concealmentValue($1) } ?? legal[0]
    }
}
