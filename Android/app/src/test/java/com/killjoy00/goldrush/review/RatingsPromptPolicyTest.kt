package com.killjoy00.goldrush.review

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RatingsPromptPolicyTest {
    @Test
    fun asksOnlyAfterAWinWithThreeGamesAndOncePerVersion() {
        assertFalse(RatingsPromptPolicy.shouldAsk(didWin = false, games = 10, version = "1.5", askedVersion = null))
        assertFalse(RatingsPromptPolicy.shouldAsk(didWin = true, games = 2, version = "1.5", askedVersion = null))
        assertFalse(RatingsPromptPolicy.shouldAsk(didWin = true, games = 3, version = "1.5", askedVersion = "1.5"))
        assertTrue(RatingsPromptPolicy.shouldAsk(didWin = true, games = 3, version = "1.5", askedVersion = null))
        assertTrue(RatingsPromptPolicy.shouldAsk(didWin = true, games = 8, version = "1.6", askedVersion = "1.5"))
    }
}
