package com.killjoy00.goldrush.engine

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

data class MuleAllocation(
    val toShovel: Int,
    val toPan: Int,
) {
    companion object {
        val NONE = MuleAllocation(0, 0)

        fun candidates(mules: Int): List<MuleAllocation> {
            if (mules <= 0) return listOf(NONE)
            return buildList {
                for (toShovel in 0..mules) {
                    for (toPan in 0..(mules - toShovel)) {
                        add(MuleAllocation(toShovel, toPan))
                    }
                }
            }
        }
    }
}

data class Board(
    val counts: MiningCounts,
    val allocation: MuleAllocation,
) {
    val oreShovelSets: Int = min(counts.goldOre, counts.shovel + allocation.toShovel)
    val gravelPanSets: Int = min(counts.gravel, counts.pan + allocation.toPan)
    val unmatched: MiningCounts = MiningCounts().also { left ->
        left.goldOre = counts.goldOre - oreShovelSets
        left.gravel = counts.gravel - gravelPanSets
        left.shovel = max(0, counts.shovel - max(0, oreShovelSets - allocation.toShovel))
        left.pan = max(0, counts.pan - max(0, gravelPanSets - allocation.toPan))
    }

    fun sets(kind: SetKind): Int = when (kind) {
        SetKind.ORE_SHOVEL -> oreShovelSets
        SetKind.GRAVEL_PAN -> gravelPanSets
    }

    val toolCount: Int
        get() = counts.toolCount

    fun count(countable: Countable): Int = when (countable) {
        is Countable.Type -> counts[countable.type]
        is Countable.Set -> sets(countable.kind)
        Countable.Tools -> toolCount
        Countable.TotalMiningCards -> counts.total
    }
}

data class CardScore(
    val id: ScoringCardId,
    val points: Int,
    val components: List<Int>,
)

data class Scorecard(
    val total: Int,
    val allocation: MuleAllocation,
    val board: Board,
    val cards: List<CardScore>,
)

object Scoring {
    fun evaluate(effect: ScoringEffect, board: Board, opponent: Board?): Int = when (effect) {
        is ScoringEffect.PerType -> board.counts[effect.type] * effect.points
        is ScoringEffect.PerTypeBeyond -> max(0, board.counts[effect.type] - effect.threshold) * effect.points
        is ScoringEffect.PerTypeCapped -> min(board.counts[effect.type], effect.maxCount) * effect.points
        is ScoringEffect.PerSet -> board.sets(effect.kind) * effect.points
        is ScoringEffect.PerUnmatched -> board.unmatched[effect.type] * effect.points
        is ScoringEffect.PerTool -> board.toolCount * effect.points
        is ScoringEffect.PerToolCapped -> min(board.toolCount, effect.maxCount) * effect.points
        is ScoringEffect.PerToolExcluding -> (board.toolCount - board.counts[effect.excluded]) * effect.points
        is ScoringEffect.PerNthScaling -> {
            if (effect.schedule.isEmpty()) {
                0
            } else {
                var sum = 0
                val held = board.counts[effect.type]
                for (n in 1..held) {
                    sum += when {
                        n <= effect.schedule.size -> effect.schedule[n - 1]
                        effect.repeatLast -> effect.schedule.last()
                        else -> 0
                    }
                }
                sum
            }
        }
        is ScoringEffect.PerNthLinear -> {
            val held = board.counts[effect.type]
            effect.multiplier * (held * (held + 1) / 2)
        }
        is ScoringEffect.PerTotalMiningCards -> board.counts.total * effect.points
        is ScoringEffect.TypesHeldAtLeast -> effect.types.count { board.counts[it] >= effect.count } * effect.points
        is ScoringEffect.BonusIfAtLeast -> if (board.count(effect.countable) >= effect.count) effect.points else 0
        is ScoringEffect.BonusIfAtMost -> if (board.count(effect.countable) <= effect.count) effect.points else 0
        is ScoringEffect.BonusIfStrictlyMore -> {
            if (opponent != null && board.count(effect.countable) > opponent.count(effect.countable)) effect.points else 0
        }
        is ScoringEffect.BonusIfExceeds -> {
            if (board.counts[effect.type] - board.counts[effect.other] >= effect.margin) effect.points else 0
        }
        is ScoringEffect.BonusPerTypeStrictlyMore -> {
            if (opponent == null) 0
            else effect.types.count { board.counts[it] > opponent.counts[it] } * effect.points
        }
        is ScoringEffect.BonusPerTypeWithinMargin -> {
            if (opponent == null) 0
            else effect.types.count { abs(board.counts[it] - opponent.counts[it]) <= effect.margin } * effect.points
        }
        is ScoringEffect.TieredByCount -> {
            val count = board.count(effect.countable)
            effect.tiers.firstOrNull { count <= it.maxCount }?.points ?: 0
        }
    }

    private fun scoreCards(
        cards: List<ScoringCard>,
        board: Board,
        opponent: Board?,
    ): Pair<Int, List<CardScore>> {
        var total = 0
        val details = cards.map { card ->
            val components = card.effects.map { evaluate(it, board, opponent) }
            val points = components.sum()
            total += points
            CardScore(card.id, points, components)
        }
        return total to details
    }

    private fun totalCards(cards: List<ScoringCard>, board: Board, opponent: Board?): Int =
        cards.sumOf { card -> card.effects.sumOf { evaluate(it, board, opponent) } }

    private fun handCards(hand: List<ScoringCardId>): List<ScoringCard> = hand.map { ScoringCardCatalog[it] }

    fun bestAllocationCards(
        counts: MiningCounts,
        cards: List<ScoringCard>,
        opponent: Board?,
    ): Triple<MuleAllocation, Board, Int> {
        var bestAllocation = MuleAllocation.NONE
        var bestBoard = Board(counts, MuleAllocation.NONE)
        var bestTotal = Int.MIN_VALUE

        for (candidate in MuleAllocation.candidates(counts.packMule)) {
            val board = Board(counts, candidate)
            val value = totalCards(cards, board, opponent)
            if (value > bestTotal) {
                bestTotal = value
                bestAllocation = candidate
                bestBoard = board
            }
        }
        return Triple(bestAllocation, bestBoard, bestTotal)
    }

    fun bestAllocation(
        counts: MiningCounts,
        hand: List<ScoringCardId>,
        opponent: Board?,
    ): Triple<MuleAllocation, Board, Int> = bestAllocationCards(counts, handCards(hand), opponent)

    fun opponentReference(counts: MiningCounts, hand: List<ScoringCardId>): Board {
        val selfRegarding = hand.filter { id ->
            ScoringCardCatalog[id].effects.any { !it.isOpponentRelative }
        }

        if (selfRegarding.isEmpty()) {
            var best = Board(counts, MuleAllocation.NONE)
            for (candidate in MuleAllocation.candidates(counts.packMule)) {
                val board = Board(counts, candidate)
                if (board.oreShovelSets + board.gravelPanSets > best.oreShovelSets + best.gravelPanSets) {
                    best = board
                }
            }
            return best
        }

        return bestAllocation(counts, selfRegarding, null).second
    }

    fun score(
        counts: MiningCounts,
        hand: List<ScoringCardId>,
        opponentCounts: MiningCounts,
        opponentHand: List<ScoringCardId>,
    ): Scorecard {
        val reference = opponentReference(opponentCounts, opponentHand)
        val best = bestAllocation(counts, hand, reference)
        val resolved = scoreCards(handCards(hand), best.second, reference)
        return Scorecard(resolved.first, best.first, best.second, resolved.second)
    }

    fun scoreSoloCards(counts: MiningCounts, cards: List<ScoringCard>): Scorecard {
        val best = bestAllocationCards(counts, cards, null)
        val resolved = scoreCards(cards, best.second, null)
        return Scorecard(resolved.first, best.first, best.second, resolved.second)
    }

    fun scoreSolo(counts: MiningCounts, hand: List<ScoringCardId>): Scorecard =
        scoreSoloCards(counts, handCards(hand))

    fun scoreWithAllocationCards(
        counts: MiningCounts,
        cards: List<ScoringCard>,
        allocation: MuleAllocation,
        opponent: Board? = null,
    ): Scorecard {
        val board = Board(counts, allocation)
        val resolved = scoreCards(cards, board, opponent)
        return Scorecard(resolved.first, allocation, board, resolved.second)
    }

    fun scoreWithAllocation(
        counts: MiningCounts,
        hand: List<ScoringCardId>,
        allocation: MuleAllocation,
        opponent: Board? = null,
    ): Scorecard = scoreWithAllocationCards(counts, handCards(hand), allocation, opponent)
}
