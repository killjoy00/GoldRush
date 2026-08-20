import Foundation
import GoldRushEngine
import GoldRushAgents

/// One game's outcome, reduced to what the analyses need.
struct GameRecord: Sendable {
    let p1Score: Int
    let p2Score: Int
    let p1Won: Bool
    let hands: PlayerPair<[ScoringCardID]>
    /// What each individual scoring card paid its holder.
    let contributions: PlayerPair<[CardScore]>
    let unseen: PlayerPair<Int>
}

enum Sim {

    static func config(from args: Args, overrides: (inout GameConfig) -> Void = { _ in }) -> GameConfig {
        var config = GameConfig(
            scoringDraft: args.has("scoring-draft"),
            progressiveReveal: args.has("progressive-reveal"),
            persistentHiddenCards: !args.has("no-persistent-hidden"),
            motherlodeRounds: !args.has("no-motherlode"),
            hiddenPolicy: args.has("hidden-cards")
                ? .fixed(args.int("hidden-cards", default: 1))
                : .standard,
            deckSize: args.int("deck-size", default: MiningDeck.standardSize)
        )
        overrides(&config)
        return config
    }

    static func run(
        games: Int,
        config: GameConfig,
        baseSeed: UInt64,
        threads: Int,
        p1: @escaping @Sendable () -> any GameAgent,
        p2: @escaping @Sendable () -> any GameAgent
    ) -> [GameRecord] {
        parallelMap(count: games, threads: threads) { index in
            let result = MatchRunner.play(
                config: config,
                seed: SeededRNG.derive(base: baseSeed, index: index).state,
                p1: p1(),
                p2: p2()
            )
            func contributions(_ player: PlayerID) -> [CardScore] {
                result.scorecards[player].cards
            }
            return GameRecord(
                p1Score: result.scores.p1,
                p2Score: result.scores.p2,
                p1Won: result.winner == .p1,
                hands: result.hands,
                contributions: PlayerPair(p1: contributions(.p1), p2: contributions(.p2)),
                unseen: result.unseenAtEnd
            )
        }
    }

    /// Win rate of P1 with a 95% interval, so a reader can see at a glance
    /// whether a gap between two variants is signal.
    static func winRate(_ records: [GameRecord]) -> (rate: Double, ci: Double) {
        guard !records.isEmpty else { return (0, 0) }
        let wins = records.count(where: \.p1Won)
        let rate = Double(wins) / Double(records.count)
        return (rate, winRateCI(rate: rate, n: records.count))
    }

    // MARK: - balance

    static func balance(_ args: Args) {
        let games = args.int("games", default: 100_000)
        let threads = args.int("threads", default: ProcessInfo.processInfo.activeProcessorCount)
        let config = config(from: args)
        let agentName = args.string("agent", default: "greedy")
        guard AgentFactory.make(agentName) != nil else {
            FileHandle.standardError.write("unknown agent: \(agentName)\n".data(using: .utf8)!)
            exit(2)
        }

        // Both seats use the same agent so a card's numbers are not contaminated
        // by a strength difference between the players holding it.
        let records = run(
            games: games, config: config, baseSeed: args.uint64("seed", default: 20260818),
            threads: threads,
            p1: { AgentFactory.make(agentName)! }, p2: { AgentFactory.make(agentName)! }
        )

        var contribution = [Stats](repeating: Stats(), count: ScoringCardID.total)
        var holderScore = [Stats](repeating: Stats(), count: ScoringCardID.total)
        var held = [Int](repeating: 0, count: ScoringCardID.total)
        var heldWins = [Int](repeating: 0, count: ScoringCardID.total)

        for record in records {
            for (player, hand) in [(PlayerID.p1, record.hands.p1), (PlayerID.p2, record.hands.p2)] {
                let score = player == .p1 ? record.p1Score : record.p2Score
                let won = player == .p1 ? record.p1Won : !record.p1Won
                for entry in record.contributions[player] {
                    contribution[entry.id.index].add(entry.points)
                }
                for card in hand {
                    holderScore[card.index].add(score)
                    held[card.index] += 1
                    if won { heldWins[card.index] += 1 }
                }
            }
        }

        // Family means of the per-card payout: the yardstick for "is this card
        // out of line with its siblings".
        var familyMean = [Double](repeating: 0, count: ScoringFamily.allCases.count)
        var familySD = [Double](repeating: 0, count: ScoringFamily.allCases.count)
        for family in ScoringFamily.allCases {
            let values = (0..<ScoringFamily.cardCount).map {
                contribution[Int(family.rawValue) * ScoringFamily.cardCount + $0].mean
            }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
            familyMean[Int(family.rawValue)] = mean
            familySD[Int(family.rawValue)] = variance.squareRoot()
        }

        print("# balance: games=\(games) agent=\(agentName) deck=\(config.deckSize)")
        print("card,name,family,contribution_ev,contribution_sd,holder_score_ev,win_rate_held,win_rate_delta,family_mean,deviation_sd,flag")
        for index in 0..<ScoringCardID.total {
            let id = ScoringCardID.at(index: index)
            let card = ScoringCardCatalog[id]
            let slot = Int(id.family.rawValue)
            let sd = familySD[slot]
            let deviation = sd > 0 ? (contribution[index].mean - familyMean[slot]) / sd : 0
            let winRate = held[index] > 0 ? Double(heldWins[index]) / Double(held[index]) : 0
            let flag = abs(deviation) > 1.5 ? "OUTLIER" : ""
            print([
                id.code, "\"\(card.name)\"", card.family.displayName,
                fmt(contribution[index].mean), fmt(contribution[index].sd),
                fmt(holderScore[index].mean), fmt(winRate, 4), fmt(winRate - 0.5, 4),
                fmt(familyMean[slot]), fmt(deviation), flag,
            ].joined(separator: ","))
        }
    }

    // MARK: - seat

    static func seat(_ args: Args) {
        let games = args.int("games", default: 100_000)
        let threads = args.int("threads", default: ProcessInfo.processInfo.activeProcessorCount)
        let config = config(from: args)
        let seed = args.uint64("seed", default: 20260818)

        print("# seat: games=\(games) deck=\(config.deckSize)")
        print("# P1 splits odd rounds, so P2 splits round 8 and P1 chooses last.")
        print("# Ultimate ties go to P2 by the tiebreak, which is included below.")
        print("matchup,p1_agent,p2_agent,p1_win_rate,ci95,p1_mean_score,p2_mean_score,mean_margin,margin_se")

        // Mirror matches isolate the seat: identical strategies, so any gap is
        // structural rather than a strength difference.
        for name in ["random", "greedy", "inference"] {
            let records = run(
                games: games, config: config, baseSeed: seed, threads: threads,
                p1: { AgentFactory.make(name)! }, p2: { AgentFactory.make(name)! }
            )
            report("mirror", name, name, records)
        }
        // Cross matchups, both orderings, so agent strength can be separated
        // from seat advantage.
        for (a, b) in [("greedy", "random"), ("inference", "greedy"), ("inference", "random")] {
            for (p1n, p2n) in [(a, b), (b, a)] {
                let records = run(
                    games: games, config: config, baseSeed: seed, threads: threads,
                    p1: { AgentFactory.make(p1n)! }, p2: { AgentFactory.make(p2n)! }
                )
                report("cross", p1n, p2n, records)
            }
        }
    }

    static func report(_ label: String, _ p1n: String, _ p2n: String, _ records: [GameRecord]) {
        let (rate, ci) = winRate(records)
        var s1 = Stats(), s2 = Stats(), margin = Stats()
        for record in records {
            s1.add(record.p1Score)
            s2.add(record.p2Score)
            margin.add(record.p1Score - record.p2Score)
        }
        print([
            label, p1n, p2n, fmt(rate, 4), fmt(ci, 4),
            fmt(s1.mean), fmt(s2.mean), fmt(margin.mean, 3), fmt(margin.standardError, 3),
        ].joined(separator: ","))
    }

    // MARK: - hidden

    static func hidden(_ args: Args) {
        let games = args.int("games", default: 50_000)
        let threads = args.int("threads", default: ProcessInfo.processInfo.activeProcessorCount)
        let seed = args.uint64("seed", default: 20260818)

        print("# hidden: games=\(games)")
        print("# The question is whether hidden cards let a better-informed agent")
        print("# convert its information edge. Inference tracks the residual deck;")
        print("# Greedy prices hidden cards at the same expectation but does not")
        print("# model the opponent. If persistence changes nothing, it is not")
        print("# earning its rule.")
        print("hidden_cards,persistent,inference_win_rate,ci95,mean_margin,mean_unseen_p1,mean_unseen_p2,score_sd")

        for hiddenCount in [0, 1, 2] {
            for persistent in [true, false] {
                var config = config(from: args)
                config.hiddenPolicy = .fixed(hiddenCount)
                config.persistentHiddenCards = persistent

                let records = run(
                    games: games, config: config, baseSeed: seed, threads: threads,
                    p1: { InferenceAgent() }, p2: { GreedyAgent() }
                )
                let (rate, ci) = winRate(records)
                var margin = Stats(), unseen1 = Stats(), unseen2 = Stats(), scores = Stats()
                for record in records {
                    margin.add(record.p1Score - record.p2Score)
                    unseen1.add(record.unseen.p1)
                    unseen2.add(record.unseen.p2)
                    scores.add(record.p1Score)
                    scores.add(record.p2Score)
                }
                print([
                    "\(hiddenCount)", "\(persistent)", fmt(rate, 4), fmt(ci, 4),
                    fmt(margin.mean, 3), fmt(unseen1.mean, 2), fmt(unseen2.mean, 2),
                    fmt(scores.sd),
                ].joined(separator: ","))
            }
        }
    }

    // MARK: - reveal

    /// An agent identical to InferenceAgent except that it reveals at random.
    /// The control group for "does the reveal decision matter".
    struct RandomRevealInference: GameAgent {
        let inner = InferenceAgent()
        var name: String { "inference-random-reveal" }
        func selectReveal(_ view: PlayerView, count: Int, rng: inout SeededRNG) -> [ScoringCardID] {
            var hand = view.hand
            rng.shuffle(&hand)
            return Array(hand.prefix(count))
        }
        func split(_ view: PlayerView, rng: inout SeededRNG) -> SplitDecision { inner.split(view, rng: &rng) }
        func choose(_ view: PlayerView, rng: inout SeededRNG) -> PileID { inner.choose(view, rng: &rng) }
        func draftPick(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID {
            inner.draftPick(view, legal: legal, rng: &rng)
        }
        func revealAdditional(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID {
            legal[rng.next(upperBound: legal.count)]
        }
    }

    /// The inverse of the agent's policy -- now the intuitive "hide your sharp
    /// cards" rule, which the data says is the weaker one.
    struct InvertedRevealInference: GameAgent {
        let inner = InferenceAgent()
        var name: String { "inference-inverted-reveal" }
        func selectReveal(_ view: PlayerView, count: Int, rng: inout SeededRNG) -> [ScoringCardID] {
            let ranked = view.hand.sorted { inner.disclosureValue($0) < inner.disclosureValue($1) }
            return Array(ranked.prefix(count))
        }
        func split(_ view: PlayerView, rng: inout SeededRNG) -> SplitDecision { inner.split(view, rng: &rng) }
        func choose(_ view: PlayerView, rng: inout SeededRNG) -> PileID { inner.choose(view, rng: &rng) }
        func draftPick(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID {
            inner.draftPick(view, legal: legal, rng: &rng)
        }
        func revealAdditional(_ view: PlayerView, legal: [ScoringCardID], rng: inout SeededRNG) -> ScoringCardID {
            legal[rng.next(upperBound: legal.count)]
        }
    }

    static func reveal(_ args: Args) {
        let games = args.int("games", default: 50_000)
        let threads = args.int("threads", default: ProcessInfo.processInfo.activeProcessorCount)
        let config = config(from: args)
        let seed = args.uint64("seed", default: 20260818)

        print("# reveal: games=\(games)")
        print("# Every agent below plays identically except for WHICH three cards")
        print("# it makes public. If the win rates are indistinguishable, the")
        print("# reveal decision is decorative and needs redesign.")
        print("p1_policy,p2_policy,p1_win_rate,ci95,mean_margin,margin_se")

        let matchups: [(String, @Sendable () -> any GameAgent, String, @Sendable () -> any GameAgent)] = [
            ("considered", { InferenceAgent() }, "random", { RandomRevealInference() }),
            ("random", { RandomRevealInference() }, "considered", { InferenceAgent() }),
            ("considered", { InferenceAgent() }, "inverted", { InvertedRevealInference() }),
            ("inverted", { InvertedRevealInference() }, "considered", { InferenceAgent() }),
            ("random", { RandomRevealInference() }, "inverted", { InvertedRevealInference() }),
        ]

        for (p1n, p1f, p2n, p2f) in matchups {
            let records = run(
                games: games, config: config, baseSeed: seed, threads: threads, p1: p1f, p2: p2f
            )
            let (rate, ci) = winRate(records)
            var margin = Stats()
            for record in records { margin.add(record.p1Score - record.p2Score) }
            print([
                p1n, p2n, fmt(rate, 4), fmt(ci, 4),
                fmt(margin.mean, 3), fmt(margin.standardError, 3),
            ].joined(separator: ","))
        }
    }

    // MARK: - deck

    static func deck(_ args: Args) {
        let games = args.int("games", default: 50_000)
        let threads = args.int("threads", default: ProcessInfo.processInfo.activeProcessorCount)
        let sizes = args.intList("deck-size", default: [60, 72, 84])
        let seed = args.uint64("seed", default: 20260818)

        print("# deck: games=\(games) sizes=\(sizes.map(String.init).joined(separator: ","))")
        print("# Cards DRAWN stay fixed at 60, so deck size sets residual")
        print("# uncertainty alone: 60 leaves nothing undealt, 84 leaves 24.")
        print("deck_size,residual,composition,inference_win_rate,ci95,mean_margin,mean_unseen,score_sd")

        for size in sizes {
            var config = config(from: args)
            config.deckSize = size
            guard size >= config.totalDrawn else {
                FileHandle.standardError.write(
                    "deck size \(size) cannot supply \(config.totalDrawn) drawn cards; skipping\n"
                        .data(using: .utf8)!
                )
                continue
            }

            let composition = MiningDeck.scaledComposition(to: size)
                .map { "\($0.type.shortName):\($0.count)" }
                .joined(separator: " ")

            let records = run(
                games: games, config: config, baseSeed: seed, threads: threads,
                p1: { InferenceAgent() }, p2: { GreedyAgent() }
            )
            let (rate, ci) = winRate(records)
            var margin = Stats(), unseen = Stats(), scores = Stats()
            for record in records {
                margin.add(record.p1Score - record.p2Score)
                unseen.add(record.unseen.p1)
                unseen.add(record.unseen.p2)
                scores.add(record.p1Score)
                scores.add(record.p2Score)
            }
            print([
                "\(size)", "\(size - config.totalDrawn)", "\"\(composition)\"",
                fmt(rate, 4), fmt(ci, 4), fmt(margin.mean, 3),
                fmt(unseen.mean, 2), fmt(scores.sd),
            ].joined(separator: ","))
        }
    }

    // MARK: - toggles

    static func toggles(_ args: Args) {
        let games = args.int("games", default: 20_000)
        let threads = args.int("threads", default: ProcessInfo.processInfo.activeProcessorCount)
        let seed = args.uint64("seed", default: 20260818)

        print("# toggles: games=\(games) per variant")
        print("draft,progressive_reveal,persistent_hidden,motherlode,inference_win_rate,ci95,mean_score,score_sd,score_min,score_max,mean_margin")

        for draft in [false, true] {
            for progressive in [false, true] {
                for persistent in [true, false] {
                    for motherlode in [true, false] {
                        let config = GameConfig(
                            scoringDraft: draft,
                            progressiveReveal: progressive,
                            persistentHiddenCards: persistent,
                            motherlodeRounds: motherlode
                        )
                        let records = run(
                            games: games, config: config, baseSeed: seed, threads: threads,
                            p1: { InferenceAgent() }, p2: { GreedyAgent() }
                        )
                        let (rate, ci) = winRate(records)
                        var scores = Stats(), margin = Stats()
                        for record in records {
                            scores.add(record.p1Score)
                            scores.add(record.p2Score)
                            margin.add(record.p1Score - record.p2Score)
                        }
                        print([
                            "\(draft)", "\(progressive)", "\(persistent)", "\(motherlode)",
                            fmt(rate, 4), fmt(ci, 4), fmt(scores.mean), fmt(scores.sd),
                            fmt(scores.minimum, 0), fmt(scores.maximum, 0), fmt(margin.mean, 3),
                        ].joined(separator: ","))
                    }
                }
            }
        }
    }
}
