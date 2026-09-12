package com.killjoy00.goldrush.session

import com.killjoy00.goldrush.ai.ProspectorFidelity
import com.killjoy00.goldrush.engine.Action
import com.killjoy00.goldrush.engine.Phase
import com.killjoy00.goldrush.engine.PileId
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.ScoringCardId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ActiveGameSessionTest {
    @Test
    fun codecRoundTripsEveryActionVariant() {
        val cards = (0..7).map(ScoringCardId::atIndex)
        val actions = listOf(
            Action.SelectRevealedScoringCards(cards.take(3)),
            Action.Split(listOf(0, 2, 4), listOf(1, 3, 5, 6), listOf(4)),
            Action.Choose(PileId.B),
            Action.DraftOpen(cards[0], cards[1]),
            Action.DraftPick(cards[2]),
            Action.DraftTakePair(cards[3], cards[4]),
            Action.DraftClose(cards[5], cards[6]),
            Action.DraftDiscard(cards[7]),
            Action.RevealAdditional(cards[1]),
        )
        val session = ActiveGameSession(
            gameId = "game-with-rotation",
            seed = 18446744073709551610UL,
            scoringDraft = true,
            simultaneousSplit = true,
            solo = false,
            prospector = ProspectorFidelity.CUNNING,
            visibleSeat = PlayerId.P2,
            actions = actions,
        )

        assertEquals(session, ActiveGameSessionCodec.decode(ActiveGameSessionCodec.encode(session)))
    }

    @Test
    fun passAndPlayRebuildReplaysAcceptedActionsExactly() {
        var session = ActiveGameSession(
            gameId = "pass-and-play",
            seed = 42UL,
            scoringDraft = false,
            simultaneousSplit = false,
            solo = false,
            prospector = ProspectorFidelity.RUTHLESS,
            visibleSeat = PlayerId.P1,
        )

        val initial = session.rebuild()!!.state
        assertEquals(PlayerId.P1, initial.actingPlayer)
        val p1Reveal = Action.SelectRevealedScoringCards(initial.view(PlayerId.P1).hand.take(3))
        session = session.append(p1Reveal, null)

        val afterP1 = session.rebuild()!!.state
        assertEquals(PlayerId.P2, afterP1.actingPlayer)
        val p2Reveal = Action.SelectRevealedScoringCards(afterP1.view(PlayerId.P2).hand.take(3))
        session = session.append(p2Reveal, null)

        val restored = ActiveGameSessionCodec.decode(ActiveGameSessionCodec.encode(session))!!.rebuild()!!.state
        assertEquals(Phase.SPLIT, restored.phase)
        assertEquals(PlayerId.P1, restored.actingPlayer)
        assertEquals(initial.hands.p1, restored.hands.p1)
        assertEquals(initial.hands.p2, restored.hands.p2)
        assertEquals(initial.deck, restored.deck)
    }

    @Test
    fun soloRebuildRunsProspectorBetweenSavedHumanActions() {
        var session = ActiveGameSession(
            gameId = "solo",
            seed = 99UL,
            scoringDraft = false,
            simultaneousSplit = false,
            solo = true,
            prospector = ProspectorFidelity.RUTHLESS,
            visibleSeat = PlayerId.P1,
        )
        val initial = session.rebuild()!!
        assertNotNull(initial.controller)
        assertEquals(PlayerId.P1, initial.state.actingPlayer)

        val reveal = Action.SelectRevealedScoringCards(initial.state.view(PlayerId.P1).hand.take(3))
        session = session.append(reveal, PlayerId.P1)
        val restored = session.rebuild()!!.state

        assertEquals(Phase.SPLIT, restored.phase)
        assertEquals(PlayerId.P1, restored.actingPlayer)
        assertEquals(3, restored.revealed.p1.size)
        assertEquals(3, restored.revealed.p2.size)
    }

    @Test
    fun malformedOrImpossibleSessionsFailClosed() {
        assertNull(ActiveGameSessionCodec.decode("not-a-session"))

        val impossible = ActiveGameSession(
            gameId = "bad",
            seed = 1UL,
            scoringDraft = false,
            simultaneousSplit = false,
            solo = false,
            prospector = ProspectorFidelity.STEADY,
            visibleSeat = null,
            actions = listOf(Action.Choose(PileId.A)),
        )
        assertNull(impossible.rebuild())
    }

    @Test
    fun visibleSeatIsPersistedWithoutChangingGameTruth() {
        val session = ActiveGameSession(
            gameId = "handoff",
            seed = 7UL,
            scoringDraft = false,
            simultaneousSplit = true,
            solo = false,
            prospector = ProspectorFidelity.STEADY,
            visibleSeat = null,
        )
        val ready = session.withVisibleSeat(PlayerId.P1)
        val decoded = ActiveGameSessionCodec.decode(ActiveGameSessionCodec.encode(ready))!!

        assertEquals(PlayerId.P1, decoded.visibleSeat)
        assertTrue(decoded.rebuild()!!.state.deck.isNotEmpty())
    }
}
