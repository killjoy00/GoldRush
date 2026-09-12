package com.killjoy00.goldrush.engine

data class ClaimJournalSplit(
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

data class ClaimJournalRound(
    val round: Int,
    val splits: List<ClaimJournalSplit>,
) {
    val id: Int
        get() = round
}
