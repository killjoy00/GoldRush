package com.killjoy00.goldrush.engine

/**
 * SplitMix64, byte-for-byte equivalent to GoldRushEngine.SeededRNG.
 * Unsigned arithmetic gives the same wrapping behavior as Swift UInt64.
 */
class SeededRng(seed: ULong) {
    var state: ULong = seed
        private set

    fun nextULong(): ULong {
        state += 0x9E3779B97F4A7C15UL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9UL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBUL
        return z xor (z shr 31)
    }

    fun nextInt(upperBound: Int): Int {
        require(upperBound > 0) { "upperBound must be positive" }
        val bound = upperBound.toULong()
        val limit = ULong.MAX_VALUE - (ULong.MAX_VALUE % bound)
        var draw = nextULong()
        while (draw >= limit) draw = nextULong()
        return (draw % bound).toInt()
    }

    fun <T> shuffle(items: MutableList<T>) {
        for (i in items.lastIndex downTo 1) {
            val j = nextInt(i + 1)
            if (i != j) {
                val tmp = items[i]
                items[i] = items[j]
                items[j] = tmp
            }
        }
    }

    companion object {
        fun derive(base: ULong, index: Int): SeededRng {
            val indexBits = index.toLong().toULong()
            val mixer = SeededRng(base + indexBits * 0x9E3779B97F4A7C15UL)
            mixer.nextULong()
            return SeededRng(mixer.nextULong())
        }
    }
}
