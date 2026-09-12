package com.killjoy00.goldrush.engine

enum class PlayerId {
    P1,
    P2;

    val opponent: PlayerId
        get() = if (this == P1) P2 else P1
}

sealed interface HiddenPolicy {
    data object Standard : HiddenPolicy
    data class Fixed(val count: Int) : HiddenPolicy
}

enum class DraftShape {
    EIGHT_SINGLES,
    SEVEN_PAIRED;

    val openingPackSize: Int
        get() = when (this) {
            EIGHT_SINGLES -> GameConfig.HAND_SIZE + 2
            SEVEN_PAIRED -> GameConfig.HAND_SIZE + 1
        }

    val pairedPackSizes: Set<Int>
        get() = when (this) {
            EIGHT_SINGLES -> emptySet()
            SEVEN_PAIRED -> setOf(6, 4)
        }
}

data class GameConfig(
    val scoringDraft: Boolean = false,
    val simultaneousSplit: Boolean = false,
    val progressiveReveal: Boolean = false,
    val persistentHiddenCards: Boolean = true,
    val motherlodeRounds: Boolean = true,
    val hiddenPolicy: HiddenPolicy = HiddenPolicy.Standard,
    val deckSize: Int = MiningDeck.STANDARD_SIZE,
    val roundCount: Int = if (simultaneousSplit) 4 else 8,
    val draftShape: DraftShape = DraftShape.SEVEN_PAIRED,
) {
    fun isMotherlode(round: Int): Boolean {
        if (!motherlodeRounds) return false
        return if (simultaneousSplit) round == roundCount else round >= roundCount - 1
    }

    fun drawCount(round: Int): Int = if (isMotherlode(round)) 9 else 7

    fun faceDownCount(round: Int): Int = when (val policy = hiddenPolicy) {
        HiddenPolicy.Standard -> if (isMotherlode(round)) 2 else 1
        is HiddenPolicy.Fixed -> policy.count.coerceIn(0, drawCount(round) - 1)
    }

    fun splitter(round: Int): PlayerId = if (round % 2 == 0) PlayerId.P2 else PlayerId.P1

    fun chooser(round: Int): PlayerId = splitter(round).opponent

    fun splitters(round: Int): List<PlayerId> =
        if (simultaneousSplit) listOf(PlayerId.P1, PlayerId.P2) else listOf(splitter(round))

    fun choosers(round: Int): List<PlayerId> = splitters(round).map { it.opponent }

    val totalDrawn: Int
        get() = (1..roundCount).sumOf { drawCount(it) * splitters(it).size }

    val initialRevealCount: Int
        get() = if (progressiveReveal) 2 else 3

    val finalRevealCount: Int
        get() = 3

    val progressiveRevealAfterRound: Int
        get() = roundCount / 2

    companion object {
        const val HAND_SIZE = 6
        const val DRAFT_OPENING_PACK_SIZE = HAND_SIZE + 2
        const val DRAFT_OPENING_POOL_SIZE = DRAFT_OPENING_PACK_SIZE * 2
        const val DRAFT_DISCARDS_PER_PLAYER = 2

        // Legacy seven-card draft compatibility constants from the Swift engine.
        const val DRAFT_PACK_SIZE = HAND_SIZE + 1
        const val DRAFT_POOL_SIZE = DRAFT_PACK_SIZE * 2
        const val DRAFT_DISCARD_COUNT = DRAFT_PACK_SIZE - HAND_SIZE
    }
}
