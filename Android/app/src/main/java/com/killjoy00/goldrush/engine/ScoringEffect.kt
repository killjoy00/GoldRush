package com.killjoy00.goldrush.engine

enum class SetKind(
    val resource: MiningType,
    val tool: MiningType,
) {
    ORE_SHOVEL(MiningType.GOLD_ORE, MiningType.SHOVEL),
    GRAVEL_PAN(MiningType.GRAVEL, MiningType.PAN),
}

sealed interface Countable {
    data class Type(val type: MiningType) : Countable
    data class Set(val kind: SetKind) : Countable
    data object Tools : Countable
    data object TotalMiningCards : Countable
}

data class Tier(val maxCount: Int, val points: Int)

sealed interface ScoringEffect {
    data class PerType(val type: MiningType, val points: Int) : ScoringEffect
    data class PerTypeBeyond(val type: MiningType, val threshold: Int, val points: Int) : ScoringEffect
    data class PerTypeCapped(val type: MiningType, val points: Int, val maxCount: Int) : ScoringEffect
    data class PerSet(val kind: SetKind, val points: Int) : ScoringEffect
    data class PerUnmatched(val type: MiningType, val points: Int) : ScoringEffect
    data class PerTool(val points: Int) : ScoringEffect
    data class PerToolCapped(val points: Int, val maxCount: Int) : ScoringEffect
    data class PerToolExcluding(val excluded: MiningType, val points: Int) : ScoringEffect
    data class PerNthScaling(
        val type: MiningType,
        val schedule: List<Int>,
        val repeatLast: Boolean,
    ) : ScoringEffect
    data class PerNthLinear(val type: MiningType, val multiplier: Int) : ScoringEffect
    data class PerTotalMiningCards(val points: Int) : ScoringEffect
    data class TypesHeldAtLeast(
        val types: List<MiningType>,
        val count: Int,
        val points: Int,
    ) : ScoringEffect
    data class BonusIfAtLeast(val countable: Countable, val count: Int, val points: Int) : ScoringEffect
    data class BonusIfAtMost(val countable: Countable, val count: Int, val points: Int) : ScoringEffect
    data class BonusIfStrictlyMore(val countable: Countable, val points: Int) : ScoringEffect
    data class BonusIfExceeds(
        val type: MiningType,
        val other: MiningType,
        val margin: Int,
        val points: Int,
    ) : ScoringEffect
    data class BonusPerTypeStrictlyMore(val types: List<MiningType>, val points: Int) : ScoringEffect
    data class BonusPerTypeWithinMargin(
        val types: List<MiningType>,
        val margin: Int,
        val points: Int,
    ) : ScoringEffect
    data class TieredByCount(val countable: Countable, val tiers: List<Tier>) : ScoringEffect

    val isOpponentRelative: Boolean
        get() = when (this) {
            is BonusIfStrictlyMore,
            is BonusPerTypeStrictlyMore,
            is BonusPerTypeWithinMargin -> true
            else -> false
        }
}
