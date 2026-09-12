package com.killjoy00.goldrush.engine

import org.junit.Assert.assertEquals
import org.junit.Test

class ScoringCatalogDigestTest {
    @Test
    fun fullScoringCatalogMatchesCrossPlatformDigest() {
        val canonical = ScoringCardCatalog.byIndex.joinToString("\n") { card ->
            listOf(
                card.id.code,
                card.effects.joinToString(",", transform = ::effect),
            ).joinToString("|")
        }
        val digest = fnv1a64(canonical)
        println("SCORING_CATALOG_DIGEST=$digest")

        assertEquals(
            "PENDING",
            digest,
        )
    }

    private fun effect(effect: ScoringEffect): String = when (effect) {
        is ScoringEffect.PerType -> "pt:${type(effect.type)}:${effect.points}"
        is ScoringEffect.PerTypeBeyond -> "ptb:${type(effect.type)}:${effect.threshold}:${effect.points}"
        is ScoringEffect.PerTypeCapped -> "ptc:${type(effect.type)}:${effect.points}:${effect.maxCount}"
        is ScoringEffect.PerSet -> "ps:${set(effect.kind)}:${effect.points}"
        is ScoringEffect.PerUnmatched -> "pu:${type(effect.type)}:${effect.points}"
        is ScoringEffect.PerTool -> "tool:${effect.points}"
        is ScoringEffect.PerToolCapped -> "toolc:${effect.points}:${effect.maxCount}"
        is ScoringEffect.PerToolExcluding -> "toolx:${type(effect.excluded)}:${effect.points}"
        is ScoringEffect.PerNthScaling -> "nth:${type(effect.type)}:${ints(effect.schedule)}:${bool(effect.repeatLast)}"
        is ScoringEffect.PerNthLinear -> "nthl:${type(effect.type)}:${effect.multiplier}"
        is ScoringEffect.PerTotalMiningCards -> "total:${effect.points}"
        is ScoringEffect.TypesHeldAtLeast -> "types:${types(effect.types)}:${effect.count}:${effect.points}"
        is ScoringEffect.BonusIfAtLeast -> "min:${countable(effect.countable)}:${effect.count}:${effect.points}"
        is ScoringEffect.BonusIfAtMost -> "max:${countable(effect.countable)}:${effect.count}:${effect.points}"
        is ScoringEffect.BonusIfStrictlyMore -> "more:${countable(effect.countable)}:${effect.points}"
        is ScoringEffect.BonusIfExceeds -> "exceeds:${type(effect.type)}:${type(effect.other)}:${effect.margin}:${effect.points}"
        is ScoringEffect.BonusPerTypeStrictlyMore -> "moretypes:${types(effect.types)}:${effect.points}"
        is ScoringEffect.BonusPerTypeWithinMargin -> "near:${types(effect.types)}:${effect.margin}:${effect.points}"
        is ScoringEffect.TieredByCount -> "tiers:${countable(effect.countable)}:${effect.tiers.joinToString(".") { tier(it) }}"
    }

    private fun countable(value: Countable): String = when (value) {
        is Countable.Type -> "t${type(value.type)}"
        is Countable.Set -> "s${set(value.kind)}"
        Countable.Tools -> "tools"
        Countable.TotalMiningCards -> "total"
    }

    private fun tier(value: Tier): String = "${if (value.maxCount == Int.MAX_VALUE) "INF" else value.maxCount}:${value.points}"
    private fun type(value: MiningType): String = value.ordinal.toString()
    private fun set(value: SetKind): String = value.ordinal.toString()
    private fun types(values: List<MiningType>): String = values.joinToString(".", transform = ::type)
    private fun ints(values: List<Int>): String = values.joinToString(".")
    private fun bool(value: Boolean): String = if (value) "1" else "0"

    private fun fnv1a64(value: String): String {
        var hash = 0xcbf29ce484222325UL
        for (byte in value.encodeToByteArray()) {
            hash = hash xor byte.toUByte().toULong()
            hash *= 0x100000001b3UL
        }
        return hash.toString(16).padStart(16, '0')
    }
}