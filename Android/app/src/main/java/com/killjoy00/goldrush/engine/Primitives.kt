package com.killjoy00.goldrush.engine

enum class PileId {
    A,
    B;

    val other: PileId
        get() = if (this == A) B else A
}

data class PlayerPair<T>(
    var p1: T,
    var p2: T,
) {
    operator fun get(player: PlayerId): T = if (player == PlayerId.P1) p1 else p2

    operator fun set(player: PlayerId, value: T) {
        if (player == PlayerId.P1) p1 = value else p2 = value
    }

    val ordered: List<Pair<PlayerId, T>>
        get() = listOf(PlayerId.P1 to p1, PlayerId.P2 to p2)

    fun <R> map(transform: (T) -> R): PlayerPair<R> = PlayerPair(transform(p1), transform(p2))

    companion object {
        fun <T> repeating(factory: () -> T): PlayerPair<T> = PlayerPair(factory(), factory())
    }
}

/** Fixed 128-bit card identity set matching the Swift observation tracker. */
data class CardSet(
    var low: ULong = 0UL,
    var high: ULong = 0UL,
) {
    fun insert(cardId: Int) {
        require(cardId in 0 until CAPACITY) { "CardSet holds ids 0..<128" }
        if (cardId < 64) {
            low = low or (1UL shl cardId)
        } else {
            high = high or (1UL shl (cardId - 64))
        }
    }

    fun insertAll(cardIds: Iterable<Int>) = cardIds.forEach(::insert)

    fun union(other: CardSet): CardSet = CardSet(low or other.low, high or other.high)

    fun contains(cardId: Int): Boolean {
        if (cardId !in 0 until CAPACITY) return false
        return if (cardId < 64) {
            (low and (1UL shl cardId)) != 0UL
        } else {
            (high and (1UL shl (cardId - 64))) != 0UL
        }
    }

    val count: Int
        get() = low.countOneBits() + high.countOneBits()

    val isEmpty: Boolean
        get() = low == 0UL && high == 0UL

    val cards: List<Int>
        get() = buildList {
            for (id in 0 until CAPACITY) if (contains(id)) add(id)
        }

    fun copySet(): CardSet = CardSet(low, high)

    companion object {
        const val CAPACITY = 128

        fun from(cardIds: Iterable<Int>): CardSet = CardSet().also { it.insertAll(cardIds) }
    }
}
