package com.killjoy00.goldrush.career

import androidx.datastore.preferences.core.mutablePreferencesOf
import com.killjoy00.goldrush.engine.CardScore
import com.killjoy00.goldrush.engine.GameConfig
import com.killjoy00.goldrush.engine.ScoringCardId
import com.killjoy00.goldrush.engine.ScoringFamily
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class CareerStatsTest {
    @Test
    fun completedGameRecordsOverallModeAndFamilyStatsExactlyOnce() {
        val game = CompletedCareerGame(
            id = "game-1",
            won = true,
            score = 42,
            opponentScore = 37,
            config = GameConfig(scoringDraft = true, simultaneousSplit = true),
            cardScores = listOf(
                score(ScoringFamily.STRIKE, 1, 10),
                score(ScoringFamily.STRIKE, 2, 8),
                score(ScoringFamily.DIG, 1, 4),
                score(ScoringFamily.DIG, 2, -1),
                score(ScoringFamily.DIG, 3, 6),
                score(ScoringFamily.PROSPECT, 1, 15),
            ),
        )

        val stats = CareerStatsRecorder.record(CareerStats(), game)
        assertEquals(1, stats.games)
        assertEquals(1, stats.wins)
        assertEquals(0, stats.losses)
        assertEquals(42, stats.totalScore)
        assertEquals(5, stats.totalMargin)
        assertEquals(42, stats.bestScore)
        assertEquals(1.0, stats.winRate, 0.0001)

        val mode = stats.modes.getValue("Drafted · Together")
        assertEquals(1, mode.games)
        assertEquals(1, mode.wins)
        assertEquals(42, mode.totalScore)
        assertEquals(5, mode.totalMargin)
        assertEquals(42, mode.bestScore)

        val strike = stats.families.getValue("Strike")
        assertEquals(2, strike.cards)
        assertEquals(18, strike.points)
        assertEquals(1, strike.games)

        val dig = stats.families.getValue("Dig")
        assertEquals(3, dig.cards)
        assertEquals(9, dig.points)
        assertEquals(1, dig.games)

        val duplicate = CareerStatsRecorder.record(stats, game)
        assertSame(stats, duplicate)
    }

    @Test
    fun modeLabelsMatchIosForAllFourFormats() {
        assertEquals(
            "Dealt · Take Turns",
            CareerStatsRecorder.modeLabel(GameConfig(scoringDraft = false, simultaneousSplit = false)),
        )
        assertEquals(
            "Dealt · Together",
            CareerStatsRecorder.modeLabel(GameConfig(scoringDraft = false, simultaneousSplit = true)),
        )
        assertEquals(
            "Drafted · Take Turns",
            CareerStatsRecorder.modeLabel(GameConfig(scoringDraft = true, simultaneousSplit = false)),
        )
        assertEquals(
            "Drafted · Together",
            CareerStatsRecorder.modeLabel(GameConfig(scoringDraft = true, simultaneousSplit = true)),
        )
    }

    @Test
    fun dedupeWindowKeepsOnlyNewestFiveHundredGameIds() {
        var stats = CareerStats(
            recordedGameIds = (0 until CareerStatsRecorder.MAX_RECORDED_GAME_IDS).map { "old-$it" }
        )
        stats = CareerStatsRecorder.record(
            stats,
            CompletedCareerGame(
                id = "newest",
                won = false,
                score = 1,
                opponentScore = 2,
                config = GameConfig(),
                cardScores = emptyList(),
            )
        )

        assertEquals(CareerStatsRecorder.MAX_RECORDED_GAME_IDS, stats.recordedGameIds.size)
        assertFalse("old-0" in stats.recordedGameIds)
        assertTrue("old-1" in stats.recordedGameIds)
        assertEquals("newest", stats.recordedGameIds.last())
    }

    @Test
    fun preferencesCodecRoundTripsWithoutLosingDedupeOrder() {
        val original = CareerStats(
            games = 3,
            wins = 2,
            totalScore = 111,
            totalMargin = 9,
            bestScore = 44,
            modes = mapOf(
                "Dealt · Together" to CareerModeRecord(
                    games = 3,
                    wins = 2,
                    totalScore = 111,
                    totalMargin = 9,
                    bestScore = 44,
                )
            ),
            families = mapOf(
                "Vein" to CareerFamilyRecord(cards = 4, points = 27, games = 3)
            ),
            recordedGameIds = listOf("a", "b", "c"),
        )
        val preferences = mutablePreferencesOf()

        CareerStatsPreferencesCodec.write(preferences, original)
        val decoded = CareerStatsPreferencesCodec.decode(preferences)

        assertEquals(original, decoded)
    }

    private fun score(family: ScoringFamily, ordinal: Int, points: Int): CardScore =
        CardScore(
            id = ScoringCardId(family, ordinal),
            points = points,
            components = listOf(points),
        )
}
