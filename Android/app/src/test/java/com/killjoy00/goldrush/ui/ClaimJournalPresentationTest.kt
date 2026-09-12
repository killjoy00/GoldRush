package com.killjoy00.goldrush.ui

import com.killjoy00.goldrush.engine.ClaimJournalSplit
import com.killjoy00.goldrush.engine.PileId
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.VisibleCard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClaimJournalPresentationTest {
    @Test
    fun splitterSeesKeptPileAsTheirsAndTakenPileAsOpponent() {
        val split = ClaimJournalSplit(
            splitter = PlayerId.P1,
            pileA = listOf(VisibleCard.Hidden(1)),
            pileB = listOf(VisibleCard.Hidden(2)),
            taken = PileId.A,
            mine = true,
        )

        val taken = journalPilePresentation(split, PileId.A)
        val kept = journalPilePresentation(split, PileId.B)

        assertEquals("Player 2 took", taken.label)
        assertFalse(taken.wentToMe)
        assertEquals("You kept", kept.label)
        assertTrue(kept.wentToMe)
    }

    @Test
    fun chooserSeesTakenPileAsTheirsAndDeclinedPileAsOpponent() {
        val split = ClaimJournalSplit(
            splitter = PlayerId.P1,
            pileA = listOf(VisibleCard.Hidden(1)),
            pileB = listOf(VisibleCard.Hidden(2)),
            taken = PileId.B,
            mine = false,
        )

        val kept = journalPilePresentation(split, PileId.A)
        val taken = journalPilePresentation(split, PileId.B)

        assertEquals("Player 1 kept", kept.label)
        assertFalse(kept.wentToMe)
        assertEquals("You took", taken.label)
        assertTrue(taken.wentToMe)
    }
}
