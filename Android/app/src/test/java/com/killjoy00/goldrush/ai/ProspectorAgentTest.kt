package com.killjoy00.goldrush.ai

import com.killjoy00.goldrush.engine.Action
import com.killjoy00.goldrush.engine.DraftShape
import com.killjoy00.goldrush.engine.GameConfig
import com.killjoy00.goldrush.engine.GameState
import com.killjoy00.goldrush.engine.Phase
import com.killjoy00.goldrush.engine.PileId
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.PlayerView
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertTrue
import org.junit.Test

class ProspectorAgentTest {
    @Test
    fun allThreeProspectorsFinishACompleteTogetherGame() {
        ProspectorFidelity.entries.forEachIndexed { index, fidelity ->
            var state = GameState.newGame(
                GameConfig(simultaneousSplit = true),
                0xA110UL + index.toULong(),
            )
            val controller = ProspectorController(agent = ProspectorAgent(fidelity))
            state = controller.start(state)

            var safety = 0
            while (!state.isFinished && safety++ < 100) {
                assertEquals("controller must return on the human seat", PlayerId.P1, state.actingPlayer)
                val action = firstHumanAction(state.view(PlayerId.P1))
                assertTrue("human fixture action must be legal: $action", state.isLegal(action))
                val next = controller.submit(state, action)
                assertNotSame("legal action must advance state", state, next)
                state = next
            }

            assertTrue("$fidelity game did not finish", state.isFinished)
            assertTrue("$fidelity exceeded safety bound", safety < 100)
            assertEquals(60, state.drawn)
            assertEquals(30, state.collections.p1.size)
            assertEquals(30, state.collections.p2.size)
        }
    }

    @Test
    fun ruthlessFinishesCurrentSevenCardDraftAndTakeTurnsGame() {
        var state = GameState.newGame(
            GameConfig(
                scoringDraft = true,
                simultaneousSplit = false,
                draftShape = DraftShape.SEVEN_PAIRED,
            ),
            0xD8A7UL,
        )
        val controller = ProspectorController(agent = ProspectorAgent(ProspectorFidelity.RUTHLESS))
        state = controller.start(state)

        var safety = 0
        while (!state.isFinished && safety++ < 140) {
            assertEquals(PlayerId.P1, state.actingPlayer)
            val action = firstHumanAction(state.view(PlayerId.P1))
            assertTrue("human fixture action must be legal: $action", state.isLegal(action))
            state = controller.submit(state, action)
        }

        assertTrue("drafted game did not finish", state.isFinished)
        assertTrue(safety < 140)
        assertEquals(6, state.hands.p1.size)
        assertEquals(6, state.hands.p2.size)
        assertEquals(1, state.draftDiscards!!.p1.size)
        assertEquals(1, state.draftDiscards!!.p2.size)
        assertEquals(60, state.drawn)
        assertEquals(8, state.roundHistory!!.size)
    }

    @Test
    fun personalityLabelsMatchTheShippingIosMenu() {
        assertEquals("Steady", ProspectorFidelity.STEADY.displayName)
        assertEquals("Cunning", ProspectorFidelity.CUNNING.displayName)
        assertEquals("Ruthless", ProspectorFidelity.RUTHLESS.displayName)
    }

    private fun firstHumanAction(view: PlayerView): Action = when (view.phase) {
        Phase.REVEAL_SELECTION -> Action.SelectRevealedScoringCards(
            view.hand.take(view.config.initialRevealCount)
        )

        Phase.ADDITIONAL_REVEAL -> Action.RevealAdditional(
            view.hand.first { it !in view.myRevealed }
        )

        Phase.DRAFT -> {
            val pack = view.draftPool
            when {
                view.config.draftShape == DraftShape.SEVEN_PAIRED &&
                    pack.size in view.config.draftShape.pairedPackSizes ->
                    Action.DraftTakePair(pack[0], pack[1])

                pack.size == 2 -> Action.DraftClose(pack[0], pack[1])
                else -> Action.DraftPick(pack.first())
            }
        }

        Phase.DRAFT_DISCARD -> Action.DraftDiscard(view.hand.first())
        Phase.SPLIT -> {
            val ids = view.currentDraw.map { it.id }
            val hidden = ids.takeLast(view.config.faceDownCount(view.round))
            Action.Split(
                pileA = ids.take(1),
                pileB = ids.drop(1),
                faceDown = hidden,
            )
        }

        Phase.CHOOSE -> Action.Choose(PileId.A)
        Phase.FINISHED -> error("finished game has no action")
    }
}
