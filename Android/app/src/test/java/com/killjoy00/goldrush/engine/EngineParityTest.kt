package com.killjoy00.goldrush.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EngineParityTest {
    @Test
    fun standardDeckMatchesSwiftComposition() {
        val deck = MiningDeck.standardDeck()
        assertEquals(72, deck.size)
        assertEquals((0 until 72).toList(), deck.map { it.id })

        val counts = MiningCounts.counting(deck)
        assertEquals(14, counts.goldNugget)
        assertEquals(10, counts.foolsGold)
        assertEquals(10, counts.goldOre)
        assertEquals(8, counts.shovel)
        assertEquals(10, counts.gravel)
        assertEquals(8, counts.pan)
        assertEquals(8, counts.quartz)
        assertEquals(4, counts.packMule)
        assertEquals(72, counts.total)
        assertEquals(20, counts.toolCount)
    }

    @Test
    fun roundStructureMatchesSwiftDefaults() {
        val sequential = GameConfig()
        assertEquals(8, sequential.roundCount)
        assertEquals(60, sequential.totalDrawn)
        assertFalse(sequential.isMotherlode(6))
        assertTrue(sequential.isMotherlode(7))
        assertTrue(sequential.isMotherlode(8))
        assertEquals(7, sequential.drawCount(6))
        assertEquals(9, sequential.drawCount(7))
        assertEquals(1, sequential.faceDownCount(6))
        assertEquals(2, sequential.faceDownCount(7))

        val together = GameConfig(simultaneousSplit = true)
        assertEquals(4, together.roundCount)
        assertEquals(60, together.totalDrawn)
        assertFalse(together.isMotherlode(3))
        assertTrue(together.isMotherlode(4))
        assertEquals(2, together.splitters(1).size)
    }

    @Test
    fun splitMix64StreamMatchesSwift() {
        val rng = SeededRng(0UL)
        assertEquals(0xE220A8397B1DCDAFUL, rng.nextULong())
        assertEquals(0x6E789E6AA1B965F4UL, rng.nextULong())
        assertEquals(0x06C45D188009454FUL, rng.nextULong())
        assertEquals(0xF88BB8A8724C81ECUL, rng.nextULong())
        assertEquals(0x1B39896A51A8749BUL, rng.nextULong())
    }

    @Test
    fun fisherYatesShuffleMatchesSwift() {
        val deck = MiningDeck.standardDeck().toMutableList()
        SeededRng(0xC0FFEEUL).shuffle(deck)
        assertEquals(
            listOf(48, 69, 65, 38, 31, 57, 27, 26, 34, 68),
            deck.take(10).map { it.id },
        )
    }

    @Test
    fun scaledDeckAlwaysHitsRequestedSize() {
        for (size in listOf(48, 60, 72, 84, 100)) {
            assertEquals(size, MiningDeck.scaledComposition(size).sumOf { it.second })
        }
    }
}
