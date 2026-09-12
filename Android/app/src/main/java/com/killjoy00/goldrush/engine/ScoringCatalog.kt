package com.killjoy00.goldrush.engine

enum class ScoringFamily(
    val letter: String,
    val displayName: String,
    val rewardSummary: String,
) {
    STRIKE("S", "Strike", "Gold Nuggets"),
    DIG("D", "Dig", "Ore + Shovel sets"),
    SLUICE("L", "Sluice", "Gravel + Pan sets"),
    VEIN("V", "Vein", "Quartz"),
    OUTFIT("O", "Outfit", "Tools"),
    PROSPECT("P", "Prospect", "odd angles — junk, breadth, sheer volume");

    companion object {
        const val CARD_COUNT = 8
    }
}

data class ScoringCardId(
    val family: ScoringFamily,
    val ordinal: Int,
) : Comparable<ScoringCardId> {
    init {
        require(ordinal in 1..ScoringFamily.CARD_COUNT) {
            "scoring card ordinal must be 1..${ScoringFamily.CARD_COUNT}"
        }
    }

    val index: Int
        get() = family.ordinal * ScoringFamily.CARD_COUNT + (ordinal - 1)

    val code: String
        get() = "${family.letter}$ordinal"

    override fun compareTo(other: ScoringCardId): Int = index.compareTo(other.index)

    override fun toString(): String = code

    companion object {
        val total: Int
            get() = ScoringFamily.entries.size * ScoringFamily.CARD_COUNT

        fun atIndex(index: Int): ScoringCardId {
            require(index in 0 until total) { "scoring card index must be 0..<$total" }
            return ScoringCardId(
                ScoringFamily.entries[index / ScoringFamily.CARD_COUNT],
                index % ScoringFamily.CARD_COUNT + 1,
            )
        }
    }
}

data class ScoringCard(
    val id: ScoringCardId,
    val name: String,
    val text: String,
    val effects: List<ScoringEffect>,
) {
    val family: ScoringFamily
        get() = id.family
}

object ScoringCardCatalog {
    val broadClaimTypes: List<MiningType> = listOf(
        MiningType.GOLD_NUGGET,
        MiningType.GOLD_ORE,
        MiningType.SHOVEL,
        MiningType.GRAVEL,
        MiningType.PAN,
        MiningType.QUARTZ,
    )

    private fun id(family: ScoringFamily, ordinal: Int) = ScoringCardId(family, ordinal)
    private fun type(type: MiningType) = Countable.Type(type)
    private fun set(kind: SetKind) = Countable.Set(kind)

    private val strike = listOf(
        ScoringCard(
            id(ScoringFamily.STRIKE, 1), "Rich Vein", "3 per Gold Nugget",
            listOf(ScoringEffect.PerType(MiningType.GOLD_NUGGET, 3)),
        ),
        ScoringCard(
            id(ScoringFamily.STRIKE, 2), "Sure Thing",
            "2 per Gold Nugget; +7 if strictly more Gold Nugget than opponent",
            listOf(
                ScoringEffect.PerType(MiningType.GOLD_NUGGET, 2),
                ScoringEffect.BonusIfStrictlyMore(type(MiningType.GOLD_NUGGET), 7),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.STRIKE, 3), "Careful Assay",
            "4 per Gold Nugget; -2 per Fool's Gold",
            listOf(
                ScoringEffect.PerType(MiningType.GOLD_NUGGET, 4),
                ScoringEffect.PerType(MiningType.FOOLS_GOLD, -2),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.STRIKE, 4), "Bonanza",
            "5 per Gold Nugget beyond your 3rd",
            listOf(ScoringEffect.PerTypeBeyond(MiningType.GOLD_NUGGET, 3, 5)),
        ),
        ScoringCard(
            id(ScoringFamily.STRIKE, 5), "Steady Take",
            "2 per Gold Nugget; 1 per Quartz",
            listOf(
                ScoringEffect.PerType(MiningType.GOLD_NUGGET, 2),
                ScoringEffect.PerType(MiningType.QUARTZ, 1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.STRIKE, 6), "Grubstake",
            "5 per Gold Nugget, max 3 counted",
            listOf(ScoringEffect.PerTypeCapped(MiningType.GOLD_NUGGET, 5, 3)),
        ),
        ScoringCard(
            id(ScoringFamily.STRIKE, 7), "Gold Fever",
            "1 per Gold Nugget; 3 per Fool's Gold",
            listOf(
                ScoringEffect.PerType(MiningType.GOLD_NUGGET, 1),
                ScoringEffect.PerType(MiningType.FOOLS_GOLD, 3),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.STRIKE, 8), "Assay Office",
            "4 per Gold Nugget; -8 per Gold Nugget beyond your 6th",
            listOf(
                ScoringEffect.PerType(MiningType.GOLD_NUGGET, 4),
                ScoringEffect.PerTypeBeyond(MiningType.GOLD_NUGGET, 6, -8),
            ),
        ),
    )

    private val dig = listOf(
        ScoringCard(
            id(ScoringFamily.DIG, 1), "Pay Streak", "4 per Ore+Shovel set",
            listOf(ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 4)),
        ),
        ScoringCard(
            id(ScoringFamily.DIG, 2), "Hard Rock",
            "3 per Ore+Shovel set; +8 if 4+ sets",
            listOf(
                ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 3),
                ScoringEffect.BonusIfAtLeast(set(SetKind.ORE_SHOVEL), 4, 8),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.DIG, 3), "Deep Shaft",
            "5 per Ore+Shovel set; -1 per unmatched Gold Ore",
            listOf(
                ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 5),
                ScoringEffect.PerUnmatched(MiningType.GOLD_ORE, -1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.DIG, 4), "Ore Buyer",
            "2 per Gold Ore; 2 per Shovel (matched or not)",
            listOf(
                ScoringEffect.PerType(MiningType.GOLD_ORE, 2),
                ScoringEffect.PerType(MiningType.SHOVEL, 2),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.DIG, 5), "Claim Rivalry",
            "3 per Ore+Shovel set; +7 if strictly more sets than opponent",
            listOf(
                ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 3),
                ScoringEffect.BonusIfStrictlyMore(set(SetKind.ORE_SHOVEL), 7),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.DIG, 6), "Muck Out",
            "5 per Ore+Shovel set; -1 per Fool's Gold",
            listOf(
                ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 5),
                ScoringEffect.PerType(MiningType.FOOLS_GOLD, -1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.DIG, 7), "Prospector's Eye",
            "3 per Ore+Shovel set; +3 per unmatched Gold Ore",
            listOf(
                ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 3),
                ScoringEffect.PerUnmatched(MiningType.GOLD_ORE, 3),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.DIG, 8), "Union Crew",
            "5 per Ore+Shovel set; -4 per Shovel not in a set (Pack Mules exempt)",
            listOf(
                ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 5),
                ScoringEffect.PerUnmatched(MiningType.SHOVEL, -4),
            ),
        ),
    )

    private val sluice = listOf(
        ScoringCard(
            id(ScoringFamily.SLUICE, 1), "Wash Plant",
            "4 per Gravel+Pan set; -1 per unmatched Gravel",
            listOf(
                ScoringEffect.PerSet(SetKind.GRAVEL_PAN, 4),
                ScoringEffect.PerUnmatched(MiningType.GRAVEL, -1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.SLUICE, 2), "Long Tom",
            "3 per Gravel+Pan set; +8 if 4+ sets",
            listOf(
                ScoringEffect.PerSet(SetKind.GRAVEL_PAN, 3),
                ScoringEffect.BonusIfAtLeast(set(SetKind.GRAVEL_PAN), 4, 8),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.SLUICE, 3), "Tailings",
            "2 per Gravel; 2 per Pan (matched or not)",
            listOf(
                ScoringEffect.PerType(MiningType.GRAVEL, 2),
                ScoringEffect.PerType(MiningType.PAN, 2),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.SLUICE, 4), "Riffle Box",
            "5 per Gravel+Pan set; -2 per unmatched Gravel",
            listOf(
                ScoringEffect.PerSet(SetKind.GRAVEL_PAN, 5),
                ScoringEffect.PerUnmatched(MiningType.GRAVEL, -2),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.SLUICE, 5), "Downstream Claim",
            "3 per Gravel+Pan set; +7 if strictly more sets than opponent",
            listOf(
                ScoringEffect.PerSet(SetKind.GRAVEL_PAN, 3),
                ScoringEffect.BonusIfStrictlyMore(set(SetKind.GRAVEL_PAN), 7),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.SLUICE, 6), "Sluice Rights",
            "4 per Gravel+Pan set; +1 per Pack Mule",
            listOf(
                ScoringEffect.PerSet(SetKind.GRAVEL_PAN, 4),
                ScoringEffect.PerType(MiningType.PACK_MULE, 1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.SLUICE, 7), "River Rat",
            "2 per Gravel; 2 per Pan; +8 if Gravel exceeds Pan by 3 or more",
            listOf(
                ScoringEffect.PerType(MiningType.GRAVEL, 2),
                ScoringEffect.PerType(MiningType.PAN, 2),
                ScoringEffect.BonusIfExceeds(MiningType.GRAVEL, MiningType.PAN, 3, 8),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.SLUICE, 8), "Fine Gold",
            "6 per Gravel+Pan set; -1 per Gold Nugget",
            listOf(
                ScoringEffect.PerSet(SetKind.GRAVEL_PAN, 6),
                ScoringEffect.PerType(MiningType.GOLD_NUGGET, -1),
            ),
        ),
    )

    private val vein = listOf(
        ScoringCard(
            id(ScoringFamily.VEIN, 1), "Crystal Ladder",
            "Nth Quartz scores 3/4/5/6/7; 6th and beyond score 7",
            listOf(ScoringEffect.PerNthScaling(MiningType.QUARTZ, listOf(3, 4, 5, 6, 7), true)),
        ),
        ScoringCard(
            id(ScoringFamily.VEIN, 2), "Mother Lode",
            "4 per Quartz; +10 if 5+ Quartz",
            listOf(
                ScoringEffect.PerType(MiningType.QUARTZ, 4),
                ScoringEffect.BonusIfAtLeast(type(MiningType.QUARTZ), 5, 10),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.VEIN, 3), "Crystal Trade",
            "5 per Quartz; -1 per unmatched Gravel",
            listOf(
                ScoringEffect.PerType(MiningType.QUARTZ, 5),
                ScoringEffect.PerUnmatched(MiningType.GRAVEL, -1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.VEIN, 4), "Prism", "Nth Quartz scores 2xN",
            listOf(ScoringEffect.PerNthLinear(MiningType.QUARTZ, 2)),
        ),
        ScoringCard(
            id(ScoringFamily.VEIN, 5), "Vein Rivalry",
            "3 per Quartz; +9 if strictly more Quartz than opponent",
            listOf(
                ScoringEffect.PerType(MiningType.QUARTZ, 3),
                ScoringEffect.BonusIfStrictlyMore(type(MiningType.QUARTZ), 9),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.VEIN, 6), "Cut and Polish",
            "2 per Quartz; 1 per Tool",
            listOf(
                ScoringEffect.PerType(MiningType.QUARTZ, 2),
                ScoringEffect.PerTool(1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.VEIN, 7), "Crystal Cache",
            "3 per Quartz; +4 per Quartz beyond your 3rd",
            listOf(
                ScoringEffect.PerType(MiningType.QUARTZ, 3),
                ScoringEffect.PerTypeBeyond(MiningType.QUARTZ, 3, 4),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.VEIN, 8), "Lode Miner",
            "6 per Quartz; -2 per Gravel+Pan set",
            listOf(
                ScoringEffect.PerType(MiningType.QUARTZ, 6),
                ScoringEffect.PerSet(SetKind.GRAVEL_PAN, -2),
            ),
        ),
    )

    private val outfit = listOf(
        ScoringCard(
            id(ScoringFamily.OUTFIT, 1), "Full Outfit", "2 per Tool",
            listOf(ScoringEffect.PerTool(2)),
        ),
        ScoringCard(
            id(ScoringFamily.OUTFIT, 2), "Mule Train",
            "5 per Pack Mule; 1 per other Tool",
            listOf(
                ScoringEffect.PerType(MiningType.PACK_MULE, 5),
                ScoringEffect.PerToolExcluding(MiningType.PACK_MULE, 1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.OUTFIT, 3), "Well Equipped",
            "3 per Tool, max 6 counted",
            listOf(ScoringEffect.PerToolCapped(3, 6)),
        ),
        ScoringCard(
            id(ScoringFamily.OUTFIT, 4), "Sharpened Steel",
            "2 per Shovel; 2 per Pan; +6 if 8+ Tools",
            listOf(
                ScoringEffect.PerType(MiningType.SHOVEL, 2),
                ScoringEffect.PerType(MiningType.PAN, 2),
                ScoringEffect.BonusIfAtLeast(Countable.Tools, 8, 6),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.OUTFIT, 5), "Supply Line",
            "1 per Tool; +12 if strictly more Tools than opponent",
            listOf(
                ScoringEffect.PerTool(1),
                ScoringEffect.BonusIfStrictlyMore(Countable.Tools, 12),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.OUTFIT, 6), "Camp Store",
            "1 per Tool; 1 per Gold Nugget",
            listOf(
                ScoringEffect.PerTool(1),
                ScoringEffect.PerType(MiningType.GOLD_NUGGET, 1),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.OUTFIT, 7), "Traveling Crew",
            "1 per Tool; +2 per resource type of which you hold 3 or more (Gold Nugget, Gold Ore, Gravel, Quartz, Fool's Gold)",
            listOf(
                ScoringEffect.PerTool(1),
                ScoringEffect.TypesHeldAtLeast(
                    listOf(
                        MiningType.GOLD_NUGGET,
                        MiningType.GOLD_ORE,
                        MiningType.GRAVEL,
                        MiningType.QUARTZ,
                        MiningType.FOOLS_GOLD,
                    ),
                    3,
                    2,
                ),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.OUTFIT, 8), "Broken Handles",
            "2 per Tool; +8 if you hold 7 or fewer Tools",
            listOf(
                ScoringEffect.PerTool(2),
                ScoringEffect.BonusIfAtMost(Countable.Tools, 7, 8),
            ),
        ),
    )

    private val prospect = listOf(
        ScoringCard(
            id(ScoringFamily.PROSPECT, 1), "Pyrite Hoarder",
            "3 per Fool's Gold; +8 if strictly more Fool's Gold than opponent",
            listOf(
                ScoringEffect.PerType(MiningType.FOOLS_GOLD, 3),
                ScoringEffect.BonusIfStrictlyMore(type(MiningType.FOOLS_GOLD), 8),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.PROSPECT, 2), "Clean Claim",
            "22 if 4 or fewer Fool's Gold; 11 if 5-7; 0 if 8+",
            listOf(
                ScoringEffect.TieredByCount(
                    type(MiningType.FOOLS_GOLD),
                    listOf(
                        Tier(4, 22),
                        Tier(7, 11),
                        Tier(Int.MAX_VALUE, 0),
                    ),
                )
            ),
        ),
        ScoringCard(
            id(ScoringFamily.PROSPECT, 3), "Broad Claim",
            "4 per resource type of which you hold 4+",
            listOf(ScoringEffect.TypesHeldAtLeast(broadClaimTypes, 4, 4)),
        ),
        ScoringCard(
            id(ScoringFamily.PROSPECT, 4), "Two Trades",
            "2 per Ore+Shovel set; 2 per Gravel+Pan set",
            listOf(
                ScoringEffect.PerSet(SetKind.ORE_SHOVEL, 2),
                ScoringEffect.PerSet(SetKind.GRAVEL_PAN, 2),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.PROSPECT, 5), "Highgrader",
            "13 for each of Gold Nugget, Quartz, Gold Ore where strictly more than opponent",
            listOf(
                ScoringEffect.BonusPerTypeStrictlyMore(
                    listOf(MiningType.GOLD_NUGGET, MiningType.QUARTZ, MiningType.GOLD_ORE),
                    13,
                )
            ),
        ),
        ScoringCard(
            id(ScoringFamily.PROSPECT, 6), "Volume Play",
            "1 per mining card in collection; -4 per Fool's Gold",
            listOf(
                ScoringEffect.PerTotalMiningCards(1),
                ScoringEffect.PerType(MiningType.FOOLS_GOLD, -4),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.PROSPECT, 7), "Lucky Strike",
            "6 for each: 5+ Gold Nugget, 4+ Quartz, 3+ Ore+Shovel sets, 3+ Gravel+Pan sets",
            listOf(
                ScoringEffect.BonusIfAtLeast(type(MiningType.GOLD_NUGGET), 5, 6),
                ScoringEffect.BonusIfAtLeast(type(MiningType.QUARTZ), 4, 6),
                ScoringEffect.BonusIfAtLeast(set(SetKind.ORE_SHOVEL), 3, 6),
                ScoringEffect.BonusIfAtLeast(set(SetKind.GRAVEL_PAN), 3, 6),
            ),
        ),
        ScoringCard(
            id(ScoringFamily.PROSPECT, 8), "Grubstake Partner",
            "7 per resource type where your count and your opponent's are within 2 (Gold Nugget, Gold Ore, Gravel, Quartz, Fool's Gold)",
            listOf(
                ScoringEffect.BonusPerTypeWithinMargin(
                    listOf(
                        MiningType.GOLD_NUGGET,
                        MiningType.GOLD_ORE,
                        MiningType.GRAVEL,
                        MiningType.QUARTZ,
                        MiningType.FOOLS_GOLD,
                    ),
                    2,
                    7,
                )
            ),
        ),
    )

    val all: List<ScoringCard> = strike + dig + sluice + vein + outfit + prospect

    val byIndex: List<ScoringCard> = all.sortedBy { it.id.index }

    operator fun get(id: ScoringCardId): ScoringCard = byIndex[id.index]
}
