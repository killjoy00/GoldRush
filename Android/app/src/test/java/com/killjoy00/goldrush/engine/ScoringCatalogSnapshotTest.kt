package com.killjoy00.goldrush.engine

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test

class ScoringCatalogSnapshotTest {
    @Test
    fun androidCatalogMatchesSharedIosAndroidSnapshot() {
        val expected = snapshotFile().readText().trim()
        val actual = canonicalCatalog()
        assertEquals(
            "Scoring catalog drifted from the shared iOS/Android snapshot.\nACTUAL:\n$actual",
            expected,
            actual,
        )
    }

    private fun snapshotFile(): File {
        val base = File(System.getProperty("user.dir"))
        return listOf(
            File(base, "docs/scoring-catalog.snapshot"),
            File(base, "../docs/scoring-catalog.snapshot"),
            File(base, "../../docs/scoring-catalog.snapshot"),
        ).map { it.canonicalFile }
            .firstOrNull { it.isFile }
            ?: error("Could not find docs/scoring-catalog.snapshot from ${base.canonicalPath}")
    }

    private fun canonicalCatalog(): String = ScoringCardCatalog.all.joinToString("\n") { card ->
        val effects = card.effects.joinToString(";") { effectToken(it) }
        "${card.id.code}|${card.name}|${card.text}|$effects"
    }

    private fun miningToken(type: MiningType): String = when (type) {
        MiningType.GOLD_NUGGET -> "goldNugget"
        MiningType.FOOLS_GOLD -> "foolsGold"
        MiningType.GOLD_ORE -> "goldOre"
        MiningType.SHOVEL -> "shovel"
        MiningType.GRAVEL -> "gravel"
        MiningType.PAN -> "pan"
        MiningType.QUARTZ -> "quartz"
        MiningType.PACK_MULE -> "packMule"
    }

    private fun setToken(kind: SetKind): String = when (kind) {
        SetKind.ORE_SHOVEL -> "oreShovel"
        SetKind.GRAVEL_PAN -> "gravelPan"
    }

    private fun countableToken(countable: Countable): String = when (countable) {
        is Countable.Type -> "type(${miningToken(countable.type)})"
        is Countable.Set -> "set(${setToken(countable.kind)})"
        Countable.Tools -> "tools"
        Countable.TotalMiningCards -> "totalMiningCards"
    }

    private fun listToken(types: List<MiningType>): String = types.joinToString(",") { miningToken(it) }

    private fun tiersToken(tiers: List<Tier>): String = tiers.joinToString(",") { "${it.maxCount}:${it.points}" }

    private fun effectToken(effect: ScoringEffect): String = when (effect) {
        is ScoringEffect.PerType -> "perType(${miningToken(effect.type)},${effect.points})"
        is ScoringEffect.PerTypeBeyond -> "perTypeBeyond(${miningToken(effect.type)},${effect.threshold},${effect.points})"
        is ScoringEffect.PerTypeCapped -> "perTypeCapped(${miningToken(effect.type)},${effect.points},${effect.maxCount})"
        is ScoringEffect.PerSet -> "perSet(${setToken(effect.kind)},${effect.points})"
        is ScoringEffect.PerUnmatched -> "perUnmatched(${miningToken(effect.type)},${effect.points})"
        is ScoringEffect.PerTool -> "perTool(${effect.points})"
        is ScoringEffect.PerToolCapped -> "perToolCapped(${effect.points},${effect.maxCount})"
        is ScoringEffect.PerToolExcluding -> "perToolExcluding(${miningToken(effect.excluded)},${effect.points})"
        is ScoringEffect.PerNthScaling -> "perNthScaling(${miningToken(effect.type)},${effect.schedule.joinToString(",")},${if (effect.repeatLast) 1 else 0})"
        is ScoringEffect.PerNthLinear -> "perNthLinear(${miningToken(effect.type)},${effect.multiplier})"
        is ScoringEffect.PerTotalMiningCards -> "perTotalMiningCards(${effect.points})"
        is ScoringEffect.TypesHeldAtLeast -> "typesHeldAtLeast(${listToken(effect.types)},${effect.count},${effect.points})"
        is ScoringEffect.BonusIfAtLeast -> "bonusIfAtLeast(${countableToken(effect.countable)},${effect.count},${effect.points})"
        is ScoringEffect.BonusIfAtMost -> "bonusIfAtMost(${countableToken(effect.countable)},${effect.count},${effect.points})"
        is ScoringEffect.BonusIfStrictlyMore -> "bonusIfStrictlyMore(${countableToken(effect.countable)},${effect.points})"
        is ScoringEffect.BonusIfExceeds -> "bonusIfExceeds(${miningToken(effect.type)},${miningToken(effect.other)},${effect.margin},${effect.points})"
        is ScoringEffect.BonusPerTypeStrictlyMore -> "bonusPerTypeStrictlyMore(${listToken(effect.types)},${effect.points})"
        is ScoringEffect.BonusPerTypeWithinMargin -> "bonusPerTypeWithinMargin(${listToken(effect.types)},${effect.margin},${effect.points})"
        is ScoringEffect.TieredByCount -> "tieredByCount(${countableToken(effect.countable)},${tiersToken(effect.tiers)})"
    }
}
