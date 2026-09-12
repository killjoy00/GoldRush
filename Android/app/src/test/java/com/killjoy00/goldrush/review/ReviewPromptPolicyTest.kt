package com.killjoy00.goldrush.review

import com.killjoy00.goldrush.career.CareerStats
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReviewPromptPolicyTest {
    @Test
    fun promptsOnAWinStartingWithThirdCompletedGame() {
        assertTrue(
            ReviewPromptPolicy.shouldPrompt(
                previous = CareerStats(games = 2, wins = 1),
                current = CareerStats(games = 3, wins = 2),
                askedVersion = null,
                currentVersion = "1.5",
            )
        )
    }

    @Test
    fun doesNotPromptAfterLossBeforeThirdGameOrTwiceInVersion() {
        assertFalse(
            ReviewPromptPolicy.shouldPrompt(
                CareerStats(games = 3, wins = 2),
                CareerStats(games = 4, wins = 2),
                null,
                "1.5",
            )
        )
        assertFalse(
            ReviewPromptPolicy.shouldPrompt(
                CareerStats(games = 1, wins = 0),
                CareerStats(games = 2, wins = 1),
                null,
                "1.5",
            )
        )
        assertFalse(
            ReviewPromptPolicy.shouldPrompt(
                CareerStats(games = 4, wins = 2),
                CareerStats(games = 5, wins = 3),
                "1.5",
                "1.5",
            )
        )
    }

    @Test
    fun aNewVersionCanPromptAgainAfterANewWin() {
        assertTrue(
            ReviewPromptPolicy.shouldPrompt(
                CareerStats(games = 5, wins = 3),
                CareerStats(games = 6, wins = 4),
                "1.5",
                "1.6",
            )
        )
    }
}
