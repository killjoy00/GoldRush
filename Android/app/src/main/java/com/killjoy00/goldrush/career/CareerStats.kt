package com.killjoy00.goldrush.career

import com.killjoy00.goldrush.engine.CardScore
import com.killjoy00.goldrush.engine.GameConfig
import com.killjoy00.goldrush.engine.GameState
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.ScoringFamily

data class CareerModeRecord(
    val games: Int = 0,
    val wins: Int = 0,
    val totalScore: Int = 0,
    val totalMargin: Int = 0,
    val bestScore: Int = Int.MIN_VALUE,
) {
    val winRate: Double
        get() = if (games == 0) 0.0 else wins.toDouble() / games.toDouble()

    val averageScore: Double
        get() = if (games == 0) 0.0 else totalScore.toDouble() / games.toDouble()

    val displayBest: Int
        get() = if (bestScore == Int.MIN_VALUE) 0 else bestScore
}

data class CareerFamilyRecord(
    val cards: Int = 0,
    val points: Int = 0,
    val games: Int = 0,
) {
    val averagePerCard: Double
        get() = if (cards == 0) 0.0 else points.toDouble() / cards.toDouble()
}

data class CareerStats(
    val games: Int = 0,
    val wins: Int = 0,
    val totalScore: Int = 0,
    val totalMargin: Int = 0,
    val bestScore: Int = Int.MIN_VALUE,
    val modes: Map<String, CareerModeRecord> = emptyMap(),
    val families: Map<String, CareerFamilyRecord> = emptyMap(),
    val recordedGameIds: List<String> = emptyList(),
) {
    val losses: Int
        get() = games - wins

    val winRate: Double
        get() = if (games == 0) 0.0 else wins.toDouble() / games.toDouble()

    val averageScore: Double
        get() = if (games == 0) 0.0 else totalScore.toDouble() / games.toDouble()

    val averageMargin: Double
        get() = if (games == 0) 0.0 else totalMargin.toDouble() / games.toDouble()

    val displayBest: Int
        get() = if (bestScore == Int.MIN_VALUE) 0 else bestScore
}

data class CompletedCareerGame(
    val id: String,
    val won: Boolean,
    val score: Int,
    val opponentScore: Int,
    val config: GameConfig,
    val cardScores: List<CardScore>,
)

object CareerStatsRecorder {
    const val MAX_RECORDED_GAME_IDS = 500

    val modeLabels: List<String> = listOf(
        "Dealt · Take Turns",
        "Dealt · Together",
        "Drafted · Take Turns",
        "Drafted · Together",
    )

    fun modeLabel(config: GameConfig): String =
        "${if (config.scoringDraft) "Drafted" else "Dealt"} · " +
            if (config.simultaneousSplit) "Together" else "Take Turns"

    fun completedGame(
        id: String,
        state: GameState,
        player: PlayerId = PlayerId.P1,
    ): CompletedCareerGame? {
        if (!state.isFinished) return null
        val mine = state.scorecard(player)
        val theirs = state.scorecard(player.opponent)
        return CompletedCareerGame(
            id = id,
            won = state.winner() == player,
            score = mine.total,
            opponentScore = theirs.total,
            config = state.config,
            cardScores = mine.cards,
        )
    }

    fun record(stats: CareerStats, game: CompletedCareerGame): CareerStats {
        if (game.id in stats.recordedGameIds) return stats

        val mode = modeLabel(game.config)
        val priorMode = stats.modes[mode] ?: CareerModeRecord()
        val nextModes = stats.modes + (
            mode to priorMode.copy(
                games = priorMode.games + 1,
                wins = priorMode.wins + if (game.won) 1 else 0,
                totalScore = priorMode.totalScore + game.score,
                totalMargin = priorMode.totalMargin + game.score - game.opponentScore,
                bestScore = maxOf(priorMode.bestScore, game.score),
            )
        )

        val nextFamilies = stats.families.toMutableMap()
        val touched = linkedSetOf<String>()
        game.cardScores.forEach { line ->
            val name = line.id.family.displayName
            val prior = nextFamilies[name] ?: CareerFamilyRecord()
            nextFamilies[name] = prior.copy(
                cards = prior.cards + 1,
                points = prior.points + line.points,
            )
            touched += name
        }
        touched.forEach { name ->
            val prior = nextFamilies[name] ?: CareerFamilyRecord()
            nextFamilies[name] = prior.copy(games = prior.games + 1)
        }

        val ids = (stats.recordedGameIds + game.id).takeLast(MAX_RECORDED_GAME_IDS)
        return stats.copy(
            games = stats.games + 1,
            wins = stats.wins + if (game.won) 1 else 0,
            totalScore = stats.totalScore + game.score,
            totalMargin = stats.totalMargin + game.score - game.opponentScore,
            bestScore = maxOf(stats.bestScore, game.score),
            modes = nextModes,
            families = nextFamilies,
            recordedGameIds = ids,
        )
    }

    fun emptyFamilyMap(): Map<String, CareerFamilyRecord> =
        ScoringFamily.entries.associate { it.displayName to CareerFamilyRecord() }
}
