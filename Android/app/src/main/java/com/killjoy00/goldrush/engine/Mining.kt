package com.killjoy00.goldrush.engine

enum class MiningType(
    val displayName: String,
    val shortName: String,
    val standardCount: Int,
) {
    GOLD_NUGGET("Gold Nugget", "Nugget", 14),
    FOOLS_GOLD("Fool's Gold", "Pyrite", 10),
    GOLD_ORE("Gold Ore", "Ore", 10),
    SHOVEL("Shovel", "Shovel", 8),
    GRAVEL("Gravel", "Gravel", 10),
    PAN("Pan", "Pan", 8),
    QUARTZ("Quartz", "Quartz", 8),
    PACK_MULE("Pack Mule", "Mule", 4);

    val isTool: Boolean
        get() = this == SHOVEL || this == PAN || this == PACK_MULE
}

data class MiningCard(val id: Int, val type: MiningType)

data class MiningCounts(
    var goldNugget: Int = 0,
    var foolsGold: Int = 0,
    var goldOre: Int = 0,
    var shovel: Int = 0,
    var gravel: Int = 0,
    var pan: Int = 0,
    var quartz: Int = 0,
    var packMule: Int = 0,
) {
    operator fun get(type: MiningType): Int = when (type) {
        MiningType.GOLD_NUGGET -> goldNugget
        MiningType.FOOLS_GOLD -> foolsGold
        MiningType.GOLD_ORE -> goldOre
        MiningType.SHOVEL -> shovel
        MiningType.GRAVEL -> gravel
        MiningType.PAN -> pan
        MiningType.QUARTZ -> quartz
        MiningType.PACK_MULE -> packMule
    }

    operator fun set(type: MiningType, value: Int) {
        when (type) {
            MiningType.GOLD_NUGGET -> goldNugget = value
            MiningType.FOOLS_GOLD -> foolsGold = value
            MiningType.GOLD_ORE -> goldOre = value
            MiningType.SHOVEL -> shovel = value
            MiningType.GRAVEL -> gravel = value
            MiningType.PAN -> pan = value
            MiningType.QUARTZ -> quartz = value
            MiningType.PACK_MULE -> packMule = value
        }
    }

    val total: Int
        get() = goldNugget + foolsGold + goldOre + shovel + gravel + pan + quartz + packMule

    val toolCount: Int
        get() = shovel + pan + packMule

    fun add(type: MiningType, amount: Int = 1) {
        this[type] = this[type] + amount
    }

    operator fun plus(other: MiningCounts): MiningCounts = MiningCounts().also { out ->
        MiningType.entries.forEach { out[it] = this[it] + other[it] }
    }

    operator fun minus(other: MiningCounts): MiningCounts = MiningCounts().also { out ->
        MiningType.entries.forEach { out[it] = this[it] - other[it] }
    }

    companion object {
        fun counting(cards: Iterable<MiningCard>): MiningCounts = MiningCounts().also { counts ->
            cards.forEach { counts.add(it.type) }
        }

        fun countingTypes(types: Iterable<MiningType>): MiningCounts = MiningCounts().also { counts ->
            types.forEach { counts.add(it) }
        }
    }
}

object MiningDeck {
    const val STANDARD_SIZE = 72

    val standardComposition: List<Pair<MiningType, Int>> = MiningType.entries.map {
        it to it.standardCount
    }

    val standardCounts: MiningCounts
        get() = MiningCounts().also { counts ->
            standardComposition.forEach { (type, count) -> counts[type] = count }
        }

    fun standardDeck(): List<MiningCard> = build(standardComposition)

    fun build(composition: List<Pair<MiningType, Int>>): List<MiningCard> {
        var nextId = 0
        return buildList {
            composition.forEach { (type, count) ->
                repeat(count) { add(MiningCard(nextId++, type)) }
            }
        }
    }

    /**
     * Largest-remainder integer apportionment, matching the Swift engine.
     * The order is deterministic: remainder descending, enum ordinal ascending.
     */
    fun scaledComposition(size: Int): List<Pair<MiningType, Int>> {
        require(size > 0) { "deck size must be positive" }
        if (size == STANDARD_SIZE) return standardComposition

        data class Entry(val type: MiningType, var count: Int, val remainder: Int)

        val scaled = standardComposition.map { (type, count) ->
            val numerator = count * size
            Entry(type, numerator / STANDARD_SIZE, numerator % STANDARD_SIZE)
        }.toMutableList()

        var assigned = scaled.sumOf { it.count }
        val order = scaled.indices.sortedWith(
            compareByDescending<Int> { scaled[it].remainder }.thenBy { scaled[it].type.ordinal }
        )
        var cursor = 0
        while (assigned < size) {
            scaled[order[cursor % order.size]].count += 1
            assigned += 1
            cursor += 1
        }
        return scaled.map { it.type to it.count }
    }
}
