package com.killjoy00.goldrush.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FullRulesParityTest {
    @Test
    fun fullScoringCatalogMatchesSwiftShape() {
        assertEquals(48, ScoringCardId.total)
        assertEquals(48, ScoringCardCatalog.all.size)
        ScoringFamily.entries.forEach { family ->
            val members = ScoringCardCatalog.all.filter { it.family == family }
            assertEquals(8, members.size)
            assertEquals((1..8).toSet(), members.map { it.id.ordinal }.toSet())
        }
        for (index in 0 until ScoringCardId.total) {
            val id = ScoringCardId.atIndex(index)
            assertEquals(index, id.index)
            assertEquals(id, ScoringCardCatalog[id].id)
            assertTrue(ScoringCardCatalog[id].effects.isNotEmpty())
        }
    }

    @Test
    fun swiftPackMuleFixtureScores97WithBothMulesOnPan() {
        val counts = MiningCounts(
            goldNugget = 6,
            foolsGold = 4,
            goldOre = 5,
            shovel = 3,
            gravel = 5,
            pan = 3,
            quartz = 3,
            packMule = 2,
        )
        val cards = listOf(
            ScoringCard(
                ScoringCardId(ScoringFamily.STRIKE, 1),
                "Rich Vein",
                "3 per Gold Nugget",
                listOf(ScoringEffect.PerType(MiningType.GOLD_NUGGET, 3)),
            ),
            ScoringCard(
                ScoringCardId(ScoringFamily.DIG, 1),
                "Pay Streak",
                "4 per Ore+Shovel set",
                listOf(ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 4)),
            ),
            ScoringCard(
                ScoringCardId(ScoringFamily.SLUICE, 1),
                "Wash Plant",
                "4 per Gravel+Pan set; -1 per unmatched Gravel",
                listOf(
                    ScoringEffect.PerSet(SetKind.GRAVEL_PAN, 4),
                    ScoringEffect.PerUnmatched(MiningType.GRAVEL, -1),
                ),
            ),
            ScoringCard(
                ScoringCardId(ScoringFamily.VEIN, 4),
                "Prism",
                "Nth Quartz scores 2xN",
                listOf(ScoringEffect.PerNthLinear(MiningType.QUARTZ, 2)),
            ),
            ScoringCard(
                ScoringCardId(ScoringFamily.OUTFIT, 1),
                "Full Outfit",
                "2 per Tool",
                listOf(ScoringEffect.PerTool(2)),
            ),
            ScoringCard(
                ScoringCardId(ScoringFamily.PROSPECT, 6),
                "Volume Play",
                "1 per mining card in collection; -3 per Fool's Gold",
                listOf(
                    ScoringEffect.PerTotalMiningCards(1),
                    ScoringEffect.PerType(MiningType.FOOLS_GOLD, -3),
                ),
            ),
        )

        val result = Scoring.scoreSoloCards(counts, cards)
        assertEquals(31, counts.total)
        assertEquals(97, result.total)
        assertEquals(MuleAllocation(0, 2), result.allocation)
        assertEquals(5, result.board.gravelPanSets)
        assertEquals(0, result.board.unmatched.gravel)
        assertEquals(3, result.board.oreShovelSets)
        assertEquals(8, result.board.toolCount)
        assertEquals(
            mapOf("S1" to 18, "D1" to 12, "L1" to 20, "V4" to 12, "O1" to 16, "P6" to 19),
            result.cards.associate { it.id.code to it.points },
        )
    }

    @Test
    fun opponentAndThresholdScoringMatchesSwiftFixtures() {
        val s2 = ScoringCardId(ScoringFamily.STRIKE, 2)
        val a = MiningCounts(goldNugget = 7, quartz = 2)
        val b = MiningCounts(goldNugget = 5, quartz = 4)
        assertEquals(21, Scoring.score(a, listOf(s2), b, listOf(s2)).total)

        val v5 = ScoringCardId(ScoringFamily.VEIN, 5)
        assertEquals(6, Scoring.score(a, listOf(v5), b, listOf(v5)).total)

        val o8 = ScoringCardId(ScoringFamily.OUTFIT, 8)
        assertEquals(22, Scoring.scoreSolo(MiningCounts(shovel = 4, pan = 3), listOf(o8)).total)
        assertEquals(16, Scoring.scoreSolo(MiningCounts(shovel = 4, pan = 4), listOf(o8)).total)

        val l7 = ScoringCardId(ScoringFamily.SLUICE, 7)
        assertEquals(16, Scoring.scoreSolo(MiningCounts(gravel = 5, pan = 3), listOf(l7)).total)
        assertEquals(26, Scoring.scoreSolo(MiningCounts(gravel = 6, pan = 3), listOf(l7)).total)

        val p8 = ScoringCardId(ScoringFamily.PROSPECT, 8)
        val mine = MiningCounts(goldNugget = 5, goldOre = 1, quartz = 4)
        val theirs = MiningCounts(goldNugget = 7, goldOre = 5, quartz = 4)
        assertEquals(28, Scoring.score(mine, listOf(p8), theirs, listOf(p8)).total)
    }

    @Test
    fun dealtSetupKeepsInitialRevealsSealedUntilBothCommit() {
        var state = GameState.newGame(GameConfig(), 0xA11CEUL)
        assertEquals(Phase.REVEAL_SELECTION, state.phase)
        assertEquals(6, state.hands.p1.size)
        assertEquals(6, state.hands.p2.size)
        assertEquals(PlayerId.P1, state.actingPlayer)

        val p1Reveal = state.hands.p1.take(3)
        state = state.applyChecked(Action.SelectRevealedScoringCards(p1Reveal))
        assertEquals(Phase.REVEAL_SELECTION, state.phase)
        assertEquals(PlayerId.P2, state.actingPlayer)
        assertTrue(state.view(PlayerId.P1).opponentRevealed.isEmpty())

        val p2Reveal = state.hands.p2.take(3)
        state = state.applyChecked(Action.SelectRevealedScoringCards(p2Reveal))
        assertEquals(Phase.SPLIT, state.phase)
        assertEquals(1, state.round)
        assertEquals(7, state.currentDraw.p1.size)
        assertTrue(state.currentDraw.p2.isEmpty())
        assertEquals(p2Reveal, state.view(PlayerId.P1).opponentRevealed)
    }

    @Test
    fun faceDownCardDeclinedByChooserStaysUnknown() {
        var state = readySequentialGame(0xB0BUL)
        val draw = state.currentDraw.p1.toList()
        val hidden = draw.last()
        state = state.applyChecked(
            Action.Split(
                pileA = draw.take(3),
                pileB = draw.drop(3),
                faceDown = listOf(hidden),
            )
        )
        assertEquals(Phase.CHOOSE, state.phase)

        val chooserView = state.view(PlayerId.P2)
        assertTrue(chooserView.piles!!.b.any { it.id == hidden && it.isHidden })
        state = state.applyChecked(Action.Choose(PileId.A))

        assertEquals(2, state.round)
        assertEquals(Phase.SPLIT, state.phase)
        val p2After = state.view(PlayerId.P2)
        assertEquals(1, p2After.opponentHiddenCount)
        assertTrue(p2After.opponentCollection.any { it.id == hidden && it.isHidden })
        assertEquals(7, state.collections.p1.size + state.collections.p2.size)
    }

    @Test
    fun simultaneousFormatSealsBothSplitsAndResolvesBothChoices() {
        var state = readyTogetherGame(0xC0FFEEUL)
        assertEquals(7, state.currentDraw.p1.size)
        assertEquals(7, state.currentDraw.p2.size)

        state = splitSimply(state)
        assertEquals(Phase.SPLIT, state.phase)
        assertEquals(PlayerId.P2, state.actingPlayer)
        assertTrue(state.view(PlayerId.P2).piles == null)

        state = splitSimply(state)
        assertEquals(Phase.CHOOSE, state.phase)
        // Swift computes simultaneous choosers as [.p1, .p2].map(\.opponent),
        // therefore P2 chooses first, then P1.
        assertEquals(PlayerId.P2, state.actingPlayer)
        assertNotNull(state.view(PlayerId.P1).piles)
        assertNotNull(state.view(PlayerId.P2).piles)

        state = state.applyChecked(Action.Choose(PileId.A))
        assertEquals(PlayerId.P1, state.actingPlayer)
        state = state.applyChecked(Action.Choose(PileId.A))
        assertEquals(2, state.round)
        assertEquals(Phase.SPLIT, state.phase)
        assertEquals(14, state.collections.p1.size + state.collections.p2.size)
        assertEquals(2, state.splitLog.size)
    }

    @Test
    fun fullSequentialAndTogetherGamesBothUseExactly60MiningCards() {
        var sequential = readySequentialGame(0x5157UL)
        sequential = playMiningGameToEnd(sequential)
        assertTrue(sequential.isFinished)
        assertEquals(60, sequential.drawn)
        assertEquals(30, sequential.collections.p1.size)
        assertEquals(30, sequential.collections.p2.size)
        assertEquals(8, sequential.roundHistory!!.size)

        var together = readyTogetherGame(0x5157UL)
        together = playMiningGameToEnd(together)
        assertTrue(together.isFinished)
        assertEquals(60, together.drawn)
        assertEquals(30, together.collections.p1.size)
        assertEquals(30, together.collections.p2.size)
        assertEquals(4, together.roundHistory!!.size)
        assertEquals(8, together.splitLog.size)
    }

    @Test
    fun currentSevenPairedDraftEndsWithSixCardsAndOnePublicBurn() {
        var state = GameState.newGame(
            GameConfig(scoringDraft = true, draftShape = DraftShape.SEVEN_PAIRED),
            0xD8A7UL,
        )
        assertEquals(Phase.DRAFT, state.phase)
        assertEquals(7, state.draftPacks.p1.size)
        assertEquals(7, state.draftPacks.p2.size)

        repeat(2) {
            val actor = state.actingPlayer!!
            state = state.applyChecked(Action.DraftPick(state.draftPacks[actor].first()))
        }
        assertEquals(6, state.draftPacks.p1.size)
        assertEquals(6, state.draftPacks.p2.size)

        repeat(2) {
            val actor = state.actingPlayer!!
            val pack = state.draftPacks[actor]
            state = state.applyChecked(Action.DraftTakePair(pack[0], pack[1]))
        }
        assertEquals(4, state.draftPacks.p1.size)
        assertEquals(4, state.draftPacks.p2.size)

        repeat(2) {
            val actor = state.actingPlayer!!
            val pack = state.draftPacks[actor]
            state = state.applyChecked(Action.DraftTakePair(pack[0], pack[1]))
        }
        assertEquals(2, state.draftPacks.p1.size)
        assertEquals(2, state.draftPacks.p2.size)

        repeat(2) {
            val actor = state.actingPlayer!!
            val pack = state.draftPacks[actor]
            state = state.applyChecked(Action.DraftClose(pack[0], pack[1]))
        }

        assertEquals(Phase.SPLIT, state.phase)
        assertEquals(6, state.hands.p1.size)
        assertEquals(6, state.hands.p2.size)
        assertEquals(5, state.revealed.p1.size)
        assertEquals(5, state.revealed.p2.size)
        assertFalse(state.revealed.p1.contains(state.draftFirstPick.p1))
        assertFalse(state.revealed.p2.contains(state.draftFirstPick.p2))
        assertEquals(1, state.draftDiscards!!.p1.size)
        assertEquals(1, state.draftDiscards!!.p2.size)
    }

    private fun readySequentialGame(seed: ULong): GameState = finishInitialReveal(
        GameState.newGame(GameConfig(), seed)
    )

    private fun readyTogetherGame(seed: ULong): GameState = finishInitialReveal(
        GameState.newGame(GameConfig(simultaneousSplit = true), seed)
    )

    private fun finishInitialReveal(initial: GameState): GameState {
        var state = initial
        repeat(2) {
            val actor = state.actingPlayer!!
            state = state.applyChecked(
                Action.SelectRevealedScoringCards(state.hands[actor].take(state.config.initialRevealCount))
            )
        }
        return state
    }

    private fun splitSimply(initial: GameState): GameState {
        val actor = initial.actingPlayer!!
        val draw = initial.currentDraw[actor].toList()
        val hiddenCount = initial.config.faceDownCount(initial.round)
        return initial.applyChecked(
            Action.Split(
                pileA = draw.take(1),
                pileB = draw.drop(1),
                faceDown = draw.takeLast(hiddenCount),
            )
        )
    }

    private fun playMiningGameToEnd(initial: GameState): GameState {
        var state = initial
        var safety = 0
        while (!state.isFinished && safety++ < 100) {
            state = when (state.phase) {
                Phase.SPLIT -> splitSimply(state)
                Phase.CHOOSE -> state.applyChecked(Action.Choose(PileId.A))
                Phase.ADDITIONAL_REVEAL -> {
                    val actor = state.actingPlayer!!
                    val id = state.hands[actor].first { it !in state.revealed[actor] }
                    state.applyChecked(Action.RevealAdditional(id))
                }
                else -> error("unexpected phase ${state.phase}")
            }
        }
        assertTrue("game did not terminate", safety < 100)
        return state
    }
}