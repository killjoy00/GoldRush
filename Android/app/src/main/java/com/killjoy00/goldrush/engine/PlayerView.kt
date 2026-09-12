package com.killjoy00.goldrush.engine

sealed interface VisibleCard {
    val id: Int
    val type: MiningType?
    val isHidden: Boolean

    data class Known(
        override val id: Int,
        override val type: MiningType,
    ) : VisibleCard {
        override val isHidden: Boolean = false
    }

    data class Hidden(
        override val id: Int,
    ) : VisibleCard {
        override val type: MiningType? = null
        override val isHidden: Boolean = true
    }
}

data class VisiblePiles(
    val a: List<VisibleCard>,
    val b: List<VisibleCard>,
)

data class ResolvedSplit(
    val splitter: PlayerId,
    val pileA: List<VisibleCard>,
    val pileB: List<VisibleCard>,
    val taken: PileId,
    val mine: Boolean,
) {
    val kept: PileId
        get() = taken.other

    fun cards(pile: PileId): List<VisibleCard> = if (pile == PileId.A) pileA else pileB
}

/** Privacy-safe projection of GameState for exactly one player. */
class PlayerView(
    state: GameState,
    val player: PlayerId,
) {
    val config: GameConfig = state.config
    val phase: Phase = state.phase
    val round: Int = state.round
    val isFinished: Boolean = state.isFinished
    val actingPlayer: PlayerId? = state.actingPlayer
    val isMyTurn: Boolean
        get() = actingPlayer == player

    val collection: List<VisibleCard>
    val collectionCounts: MiningCounts
    val opponentCollection: List<VisibleCard>
    val opponentKnownCounts: MiningCounts
    val opponentHiddenCount: Int

    val hand: List<ScoringCardId>
    val myRevealed: List<ScoringCardId>
    val opponentRevealed: List<ScoringCardId>

    val unseen: MiningCounts
    val unseenTotal: Int

    val currentDraw: List<VisibleCard>
    val piles: VisiblePiles?
    val myPiles: VisiblePiles?
    val draftPool: List<ScoringCardId>
    val draftDiscarded: PlayerPair<ScoringCardId?>
    val draftDiscards: PlayerPair<List<ScoringCardId>>
    val lastRound: List<ResolvedSplit>
    val splitLog: List<SplitRecord>

    init {
        val observed = state.observations[player]

        fun visible(id: Int): VisibleCard = if (observed.contains(id)) {
            VisibleCard.Known(id, state.type(id))
        } else {
            VisibleCard.Hidden(id)
        }

        collection = state.collections[player].map { VisibleCard.Known(it, state.type(it)) }
        collectionCounts = state.counts(player)

        val theirVisible = state.collections[player.opponent].map(::visible)
        opponentCollection = theirVisible
        val knownCounts = MiningCounts()
        var hiddenCount = 0
        theirVisible.forEach { card ->
            val knownType = card.type
            if (knownType != null) knownCounts.add(knownType) else hiddenCount += 1
        }
        opponentKnownCounts = knownCounts
        opponentHiddenCount = hiddenCount

        hand = state.hands[player].toList()
        myRevealed = state.revealed[player].toList()
        draftPool = state.draftPacks[player].toList()
        splitLog = state.splitLog.toList()
        draftDiscarded = if (state.phase == Phase.DRAFT_DISCARD) {
            PlayerPair(null, null)
        } else {
            PlayerPair(state.draftDiscarded.p1, state.draftDiscarded.p2)
        }
        val allDiscards = state.draftDiscards
        draftDiscards = if (allDiscards == null) {
            PlayerPair(emptyList(), emptyList())
        } else {
            PlayerPair(allDiscards.p1.toList(), allDiscards.p2.toList())
        }

        val bothCommitted = state.phase != Phase.REVEAL_SELECTION
        opponentRevealed = if (bothCommitted) state.revealed[player.opponent].toList() else emptyList()

        val observedCounts = MiningCounts()
        observed.cards.forEach { observedCounts.add(state.type(it)) }
        val pool = MiningCounts()
        MiningDeck.scaledComposition(state.config.deckSize).forEach { (type, count) -> pool[type] = count }
        unseen = pool - observedCounts
        unseenTotal = unseen.total

        currentDraw = if (state.phase == Phase.SPLIT) {
            state.currentDraw[player].map { VisibleCard.Known(it, state.type(it)) }
        } else {
            emptyList()
        }

        piles = if (state.phase == Phase.CHOOSE) {
            state.pendingSplits[player.opponent]?.let { split ->
                fun pileCards(ids: List<Int>): List<VisibleCard> = ids.map { id ->
                    if (split.faceDown.contains(id)) VisibleCard.Hidden(id)
                    else VisibleCard.Known(id, state.type(id))
                }
                VisiblePiles(pileCards(split.pileA), pileCards(split.pileB))
            }
        } else {
            null
        }

        lastRound = state.lastRound?.let { outcome ->
            buildList {
                listOf(PlayerId.P1, PlayerId.P2).forEach { splitter ->
                    val split = outcome.splits[splitter] ?: return@forEach
                    val taken = outcome.taken[splitter.opponent] ?: return@forEach
                    val isMine = splitter == player
                    val iChose = splitter.opponent == player

                    fun pileCards(ids: List<Int>, pile: PileId): List<VisibleCard> = ids.map { id ->
                        val claimed = iChose && pile == taken
                        if (isMine || claimed || !split.faceDown.contains(id)) {
                            VisibleCard.Known(id, state.type(id))
                        } else {
                            VisibleCard.Hidden(id)
                        }
                    }

                    add(
                        ResolvedSplit(
                            splitter,
                            pileCards(split.pileA, PileId.A),
                            pileCards(split.pileB, PileId.B),
                            taken,
                            isMine,
                        )
                    )
                }
            }
        } ?: emptyList()

        myPiles = if (state.phase == Phase.CHOOSE) {
            state.pendingSplits[player]?.let { mine ->
                VisiblePiles(
                    mine.pileA.map { VisibleCard.Known(it, state.type(it)) },
                    mine.pileB.map { VisibleCard.Known(it, state.type(it)) },
                )
            }
        } else {
            null
        }
    }

    val unseenDistribution: List<Pair<MiningType, Double>>
        get() {
            if (unseenTotal <= 0) return emptyList()
            return MiningType.entries.map { it to unseen[it].toDouble() / unseenTotal.toDouble() }
        }
}
