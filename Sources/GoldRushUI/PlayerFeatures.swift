#if canImport(SwiftUI)
import SwiftUI
import Foundation
import GoldRushEngine
import GoldRushUICore

// MARK: - Career stats

struct CareerModeRecord: Codable, Equatable {
    var games = 0
    var wins = 0
    var totalScore = 0
    var totalMargin = 0
    var bestScore = Int.min

    var winRate: Double { games == 0 ? 0 : Double(wins) / Double(games) }
    var averageScore: Double { games == 0 ? 0 : Double(totalScore) / Double(games) }
}

struct CareerFamilyRecord: Codable, Equatable {
    var cards = 0
    var points = 0
    var games = 0

    var averagePerCard: Double { cards == 0 ? 0 : Double(points) / Double(cards) }
}

struct CareerStats: Codable, Equatable {
    var games = 0
    var wins = 0
    var totalScore = 0
    var totalMargin = 0
    var bestScore = Int.min
    var modes: [String: CareerModeRecord] = [:]
    var families: [String: CareerFamilyRecord] = [:]
    var recordedGameIDs: [String] = []

    var losses: Int { games - wins }
    var winRate: Double { games == 0 ? 0 : Double(wins) / Double(games) }
    var averageScore: Double { games == 0 ? 0 : Double(totalScore) / Double(games) }
    var averageMargin: Double { games == 0 ? 0 : Double(totalMargin) / Double(games) }
    var displayBest: Int { bestScore == Int.min ? 0 : bestScore }
}

enum CareerStatsStore {
    static let key = "goldrush.careerStats.v1"

    static func load() -> CareerStats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(CareerStats.self, from: data)
        else { return CareerStats() }
        return stats
    }

    static func save(_ stats: CareerStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Records the seat this device represents. Pass-and-play follows Player 1;
    /// solo and Game Center follow the human/local seat.
    @MainActor
    static func record(model: GameViewModel) {
        guard let gameID = model.finishedGameIdentifier,
              let winner = model.winner else { return }

        var stats = load()
        guard !stats.recordedGameIDs.contains(gameID) else { return }

        let player = model.view.player
        let score = model.total(for: player)
        let opponentScore = model.total(for: player.opponent)
        let won = winner == player
        let config = model.view.config
        let mode = "\(config.scoringDraft ? "Drafted" : "Dealt") · \(config.simultaneousSplit ? "Together" : "Take Turns")"

        stats.games += 1
        if won { stats.wins += 1 }
        stats.totalScore += score
        stats.totalMargin += score - opponentScore
        stats.bestScore = max(stats.bestScore, score)

        var modeRecord = stats.modes[mode] ?? CareerModeRecord()
        modeRecord.games += 1
        if won { modeRecord.wins += 1 }
        modeRecord.totalScore += score
        modeRecord.totalMargin += score - opponentScore
        modeRecord.bestScore = max(modeRecord.bestScore, score)
        stats.modes[mode] = modeRecord

        var touchedFamilies = Set<String>()
        for line in model.scoreLines(for: player) {
            let name = line.id.family.displayName
            var family = stats.families[name] ?? CareerFamilyRecord()
            family.cards += 1
            family.points += line.points
            stats.families[name] = family
            touchedFamilies.insert(name)
        }
        for name in touchedFamilies {
            stats.families[name]?.games += 1
        }

        stats.recordedGameIDs.append(gameID)
        // Enough dedupe history for years of normal play without allowing this
        // tiny metadata list to grow forever.
        if stats.recordedGameIDs.count > 500 {
            stats.recordedGameIDs.removeFirst(stats.recordedGameIDs.count - 500)
        }
        save(stats)
    }
}

public struct CareerStatsView: View {
    @State private var stats = CareerStatsStore.load()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if stats.games == 0 {
                        ContentUnavailableView(
                            "No completed games yet",
                            systemImage: "chart.bar.xaxis",
                            description: Text("Career stats start recording when a game reaches scoring.")
                        )
                        .padding(.top, 40)
                    } else {
                        headline
                        modes
                        families
                        Text("Pass-and-play records Player 1. Solo and online games record your local seat. Stats stay on this device.")
                            .font(.system(size: 10))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.parchment.opacity(0.45))
                            .padding(.horizontal, 20)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Career Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { stats = CareerStatsStore.load() }
        }
    }

    @ViewBuilder
    var headline: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                stat("Record", "\(stats.wins)–\(stats.losses)")
                stat("Win rate", percent(stats.winRate))
            }
            HStack(spacing: 10) {
                stat("Avg score", decimal(stats.averageScore))
                stat("Avg margin", signed(stats.averageMargin))
                stat("Best", "\(stats.displayBest)")
            }
        }
    }

    @ViewBuilder
    var modes: some View {
        section("BY FORMAT") {
            ForEach(stats.modes.keys.sorted(), id: \.self) { key in
                if let record = stats.modes[key] {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.parchment)
                            Text("\(record.games) game\(record.games == 1 ? "" : "s") · avg \(decimal(record.averageScore))")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.parchment.opacity(0.5))
                        }
                        Spacer()
                        Text(percent(record.winRate))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.goldBright)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    var families: some View {
        section("SCORING FAMILIES") {
            ForEach(ScoringFamily.allCases, id: \.rawValue) { family in
                let record = stats.families[family.displayName] ?? CareerFamilyRecord()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(family.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.parchment)
                        Text("\(record.cards) cards scored")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.parchment.opacity(0.5))
                    }
                    Spacer()
                    Text("\(decimal(record.averagePerCard)) pts/card")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
                .padding(.vertical, 3)
            }
        }
    }

    @ViewBuilder
    func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.goldBright)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.parchment.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(Theme.dirtLight.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))
    }

    @ViewBuilder
    func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.gold.opacity(0.8))
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dirtLight.opacity(0.3), in: RoundedRectangle(cornerRadius: 13))
    }

    func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    func decimal(_ value: Double) -> String { String(format: "%.1f", value) }
    func signed(_ value: Double) -> String { String(format: "%+.1f", value) }
}

// MARK: - Scoring-card compendium

public struct ScoringCardCompendiumView: View {
    @State private var family: ScoringFamily?
    @Environment(\.dismiss) private var dismiss

    public init() {}

    var cards: [ScoringCard] {
        guard let family else { return ScoringCardCatalog.all }
        return ScoringCardCatalog.all.filter { $0.family == family }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        filterButton("All", selected: family == nil) { family = nil }
                        ForEach(ScoringFamily.allCases, id: \.rawValue) { item in
                            filterButton(item.displayName, selected: family == item) { family = item }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                ScrollView {
                    LazyVStack(spacing: 9) {
                        if let family {
                            Text("\(family.displayName) rewards \(family.rewardSummary).")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.parchment.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 2)
                        }
                        ForEach(cards, id: \.id) { card in
                            ScoringCardView(id: card.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 20)
                }
            }
            .background(Theme.background)
            .navigationTitle("Scoring Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    func filterButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(selected ? Theme.gold : Theme.dirtLight,
                            in: Capsule())
                .foregroundStyle(selected ? Theme.dirt : Theme.parchment.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}
#endif
