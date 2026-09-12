package com.killjoy00.goldrush.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ClaimJournalParityTest {
    @Test
    fun declinedBuriedCardStaysHiddenToChooserButKnownToSplitter() {
        var state = readySequentialGame(0xC1A1CUL)
        val draw = state.currentDraw.p1.toList()
        val buried = draw.last()
        val pileA = draw.take(3)
        val pileB = draw.drop(3)

        state = state.applyChecked(
            Action.Split(
                pileA = pileA,
                pileB = pileB,
                faceDown = listOf(buried),
            )
        )
        state = state.applyChecked(Action.Choose(PileId.A))

        val splitterJournal = state.claimJournal(PlayerId.P1)
        val chooserJournal = state.claimJournal(PlayerId.P2)
        assertEquals(1, splitterJournal.size)
        assertEquals(1, chooserJournal.size)

        val splitterSplit = splitterJournal.single().splits.single()
        val chooserSplit = chooserJournal.single().splits.single()
        val splitterBuried = splitterSplit.cards(PileId.B).single { it.id == buried }
        val chooserBuried = chooserSplit.cards(PileId.B).single { it.id == buried }

        assertNotNull(splitterBuried.type)
        assertEquals(state.type(buried), splitterBuried.type)
        assertNull(chooserBuried.type)
        assertTrue(chooserBuried.isHidden)
    }

    @Test
    fun chooserLearnsBuriedCardWhenTakingItsPile() {
        var state = readySequentialGame(0xC1A1DUL)
        val draw = state.currentDraw.p1.toList()
        val buried = draw.last()
        val pileA = draw.take(3)
        val pileB = draw.drop(3)

        state = state.applyChecked(
            Action.Split(
                pileA = pileA,
                pileB = pileB,
                faceDown = listOf(buried),
            )
        )
        state = state.applyChecked(Action.Choose(PileId.B))

        val chooserSplit = state.claimJournal(PlayerId.P2).single().splits.single()
        val chooserBuried = chooserSplit.cards(PileId.B).single { it.id == buried }
        assertEquals(state.type(buried), chooserBuried.type)
    }

    private fun readySequentialGame(seed: ULong): GameState {
        var state = GameState.newGame(GameConfig(), seed)
        repeat(2) {
            val actor = state.actingPlayer!!
            state = state.applyChecked(
                Action.SelectRevealedScoringCards(
                    state.hands[actor].take(state.config.initialRevealCount)
                )
            )
        }
        return state
    }
}
