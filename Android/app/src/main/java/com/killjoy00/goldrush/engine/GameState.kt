package com.killjoy00.goldrush.engine

enum class Phase {
    DRAFT,
    DRAFT_DISCARD,
    REVEAL_SELECTION,
    ADDITIONAL_REVEAL,
    SPLIT,
    CHOOSE,
    FINISHED,
}

data class RoundOutcome(
    val round: Int,
    val splits: PlayerPair<PendingSplit?>,
    val taken: PlayerPair<PileId?>,
)

data class SplitRecord(
    val round: Int,
    val splitter: PlayerId,
    val drawCount: Int,
    val faceDownCount: Int,
    val faceDownInTaken: Int,
    val taken: PileId,
)

data class PendingSplit(
    val pileA: List<Int>,
    val pileB: List<Int>,
    val faceDown: CardSet,
) {
    fun pile(id: PileId): List<Int> = if (id == PileId.A) pileA else pileB

    fun copySplit(): PendingSplit = copy(
        pileA = pileA.toList(),
        pileB = pileB.toList(),
        faceDown = faceDown.copySet(),
    )
}

sealed interface Action {
    data class SelectRevealedScoringCards(val ids: List<ScoringCardId>) : Action
    data class Split(val pileA: List<Int>, val pileB: List<Int>, val faceDown: List<Int>) : Action
    data class Choose(val pile: PileId) : Action
    data class DraftOpen(val keep: ScoringCardId, val discard: ScoringCardId) : Action
    data class DraftPick(val id: ScoringCardId) : Action
    data class DraftTakePair(val first: ScoringCardId, val second: ScoringCardId) : Action
    data class DraftClose(val keep: ScoringCardId, val discard: ScoringCardId) : Action
    data class DraftDiscard(val id: ScoringCardId) : Action
    data class RevealAdditional(val id: ScoringCardId) : Action
}

class ActionRuleException(message: String) : IllegalArgumentException(message)

/**
 * Android port of GoldRushEngine.GameState.
 *
 * The state owns global truth, including hidden cards. UI and agents should read
 * PlayerView rather than inspecting this type directly when information secrecy matters.
 */
class GameState private constructor(
    val config: GameConfig,
    var rng: SeededRng,
    var phase: Phase,
    var round: Int,
    val deck: List<MiningCard>,
    var drawn: Int,
    val collections: PlayerPair<MutableList<Int>>,
    val hands: PlayerPair<MutableList<ScoringCardId>>,
    val revealed: PlayerPair<MutableList<ScoringCardId>>,
    val observations: PlayerPair<CardSet>,
    val currentDraw: PlayerPair<MutableList<Int>>,
    val pendingSplits: PlayerPair<PendingSplit?>,
    private val splitSubmitted: PlayerPair<Boolean>,
    private val chooseSubmitted: PlayerPair<Boolean>,
    private val takenPile: PlayerPair<PileId?>,
    var lastRound: RoundOutcome?,
    val roundHistory: MutableList<RoundOutcome>?,
    val splitLog: MutableList<SplitRecord>,
    private val revealSubmitted: PlayerPair<Boolean>,
    val draftPacks: PlayerPair<MutableList<ScoringCardId>>,
    private val draftSubmitted: PlayerPair<Boolean>,
    val draftFirstPick: PlayerPair<ScoringCardId?>,
    val draftDiscarded: PlayerPair<ScoringCardId?>,
    var draftDiscards: PlayerPair<MutableList<ScoringCardId>>?,
    private var draftPendingDiscard: PlayerPair<ScoringCardId?>?,
    private var draftLegacyMode: Boolean?,
) {
    fun card(id: Int): MiningCard = deck[id]

    fun type(id: Int): MiningType = deck[id].type

    fun counts(player: PlayerId): MiningCounts {
        val counts = MiningCounts()
        collections[player].forEach { counts.add(type(it)) }
        return counts
    }

    val actingPlayer: PlayerId?
        get() = when (phase) {
            Phase.DRAFT, Phase.DRAFT_DISCARD -> when {
                !draftSubmitted.p1 -> PlayerId.P1
                !draftSubmitted.p2 -> PlayerId.P2
                else -> null
            }
            Phase.REVEAL_SELECTION, Phase.ADDITIONAL_REVEAL -> when {
                !revealSubmitted.p1 -> PlayerId.P1
                !revealSubmitted.p2 -> PlayerId.P2
                else -> null
            }
            Phase.SPLIT -> config.splitters(round).firstOrNull { !splitSubmitted[it] }
            Phase.CHOOSE -> config.choosers(round).firstOrNull { !chooseSubmitted[it] }
            Phase.FINISHED -> null
        }

    val isFinished: Boolean
        get() = phase == Phase.FINISHED

    fun isLegal(action: Action): Boolean = try {
        validate(action)
        true
    } catch (_: ActionRuleException) {
        false
    }

    fun validate(action: Action) {
        if (phase == Phase.FINISHED) throw ActionRuleException("game finished")
        val actor = actingPlayer ?: throw ActionRuleException("no acting player in $phase")

        when (action) {
            is Action.DraftOpen -> {
                requirePhase(Phase.DRAFT)
                val pack = draftPacks[actor]
                if (pack.size != GameConfig.DRAFT_OPENING_PACK_SIZE) {
                    throw ActionRuleException("draft pack must contain ${GameConfig.DRAFT_OPENING_PACK_SIZE} cards")
                }
                if (action.keep == action.discard) throw ActionRuleException("draft keep and discard must differ")
                if (action.keep !in pack) throw ActionRuleException("${action.keep} is not in the draft pack")
                if (action.discard !in pack) throw ActionRuleException("${action.discard} is not in the draft pack")
            }

            is Action.DraftPick -> {
                requirePhase(Phase.DRAFT)
                val pack = draftPacks[actor]
                if (action.id !in pack) throw ActionRuleException("${action.id} is not in the draft pack")
                if (pack.size in config.draftShape.pairedPackSizes) {
                    throw ActionRuleException("this draft step takes two cards")
                }
            }

            is Action.DraftTakePair -> {
                requirePhase(Phase.DRAFT)
                val pack = draftPacks[actor]
                if (pack.size !in config.draftShape.pairedPackSizes) {
                    throw ActionRuleException("this draft step does not take a pair")
                }
                if (action.first == action.second) throw ActionRuleException("draft pair must contain two cards")
                if (action.first !in pack) throw ActionRuleException("${action.first} is not in the draft pack")
                if (action.second !in pack) throw ActionRuleException("${action.second} is not in the draft pack")
            }

            is Action.DraftClose -> {
                requirePhase(Phase.DRAFT)
                val pack = draftPacks[actor]
                if (pack.size != 2) throw ActionRuleException("closing draft pack must contain two cards")
                if (action.keep == action.discard) throw ActionRuleException("draft keep and discard must differ")
                if (action.keep !in pack) throw ActionRuleException("${action.keep} is not in the draft pack")
                if (action.discard !in pack) throw ActionRuleException("${action.discard} is not in the draft pack")
            }

            is Action.DraftDiscard -> {
                requirePhase(Phase.DRAFT_DISCARD)
                if (action.id !in hands[actor]) throw ActionRuleException("${action.id} is not in hand")
            }

            is Action.SelectRevealedScoringCards -> {
                requirePhase(Phase.REVEAL_SELECTION)
                if (action.ids.size != config.initialRevealCount) {
                    throw ActionRuleException("must reveal ${config.initialRevealCount} scoring cards")
                }
                if (action.ids.toSet().size != action.ids.size) {
                    throw ActionRuleException("revealed scoring cards must be unique")
                }
                action.ids.forEach {
                    if (it !in hands[actor]) throw ActionRuleException("$it is not in hand")
                }
            }

            is Action.RevealAdditional -> {
                requirePhase(Phase.ADDITIONAL_REVEAL)
                if (action.id !in hands[actor]) throw ActionRuleException("${action.id} is not in hand")
                if (action.id in revealed[actor]) throw ActionRuleException("${action.id} is already revealed")
            }

            is Action.Split -> {
                requirePhase(Phase.SPLIT)
                if (action.pileA.isEmpty()) throw ActionRuleException("pile A may not be empty")
                if (action.pileB.isEmpty()) throw ActionRuleException("pile B may not be empty")

                val mine = currentDraw[actor]
                val combined = action.pileA + action.pileB
                if (
                    combined.size != mine.size ||
                    combined.toSet().size != combined.size ||
                    combined.toSet() != mine.toSet()
                ) {
                    throw ActionRuleException("split must contain the entire draw exactly once")
                }

                val expected = config.faceDownCount(round)
                if (action.faceDown.size != expected || action.faceDown.toSet().size != action.faceDown.size) {
                    throw ActionRuleException("split must contain exactly $expected face-down cards")
                }
                val placed = combined.toSet()
                action.faceDown.forEach {
                    if (it !in placed) throw ActionRuleException("face-down card $it is not in either pile")
                }
            }

            is Action.Choose -> {
                requirePhase(Phase.CHOOSE)
                if (pendingSplits[actor.opponent] == null) {
                    throw ActionRuleException("opponent has no pending split")
                }
            }
        }
    }

    private fun requirePhase(expected: Phase) {
        if (phase != expected) throw ActionRuleException("expected $expected, actual $phase")
    }

    /** Illegal actions return this state unchanged, matching the Swift reducer. */
    fun apply(action: Action): GameState {
        if (!isLegal(action)) return this
        val next = deepCopy()
        next.reduce(action)
        return next
    }

    fun applyChecked(action: Action): GameState {
        validate(action)
        val next = deepCopy()
        next.reduce(action)
        return next
    }

    private fun publishDraftDiscards() {
        val pending = draftPendingDiscard ?: return
        val p1 = pending.p1 ?: return
        val p2 = pending.p2 ?: return
        draftDiscarded.p1 = p1
        draftDiscarded.p2 = p2
        if (draftDiscards == null) draftDiscards = PlayerPair.repeating { mutableListOf() }
        draftDiscards!!.p1.add(p1)
        draftDiscards!!.p2.add(p2)
        draftPendingDiscard = PlayerPair(null, null)
    }

    private fun reduce(action: Action) {
        val actor = actingPlayer ?: return

        when (action) {
            is Action.DraftOpen -> {
                draftLegacyMode = false
                draftFirstPick[actor] = action.keep
                hands[actor].add(action.keep)
                draftPacks[actor].removeAll { it == action.keep || it == action.discard }
                if (draftPendingDiscard == null) draftPendingDiscard = PlayerPair(null, null)
                draftPendingDiscard!![actor] = action.discard
                draftSubmitted[actor] = true

                if (draftSubmitted.p1 && draftSubmitted.p2) {
                    publishDraftDiscards()
                    draftSubmitted.p1 = false
                    draftSubmitted.p2 = false
                    swapDraftPacks()
                }
            }

            is Action.DraftPick -> {
                if (config.draftShape == DraftShape.SEVEN_PAIRED) {
                    draftLegacyMode = false
                } else {
                    if (draftLegacyMode == null) draftLegacyMode = true
                    if (hands[actor].isEmpty() && draftPacks[actor].size == GameConfig.DRAFT_OPENING_PACK_SIZE) {
                        draftLegacyMode = true
                    }
                }

                if (hands[actor].isEmpty()) draftFirstPick[actor] = action.id
                hands[actor].add(action.id)
                draftPacks[actor].remove(action.id)
                draftSubmitted[actor] = true

                if (draftSubmitted.p1 && draftSubmitted.p2) {
                    draftSubmitted.p1 = false
                    draftSubmitted.p2 = false
                    swapDraftPacks()

                    if (
                        draftLegacyMode == true &&
                        hands.p1.size >= GameConfig.DRAFT_PACK_SIZE &&
                        hands.p2.size >= GameConfig.DRAFT_PACK_SIZE
                    ) {
                        draftPacks.p1.clear()
                        draftPacks.p2.clear()
                        phase = Phase.DRAFT_DISCARD
                    }
                }
            }

            is Action.DraftTakePair -> {
                if (hands[actor].isEmpty()) draftFirstPick[actor] = action.first
                hands[actor].add(action.first)
                hands[actor].add(action.second)
                draftPacks[actor].removeAll { it == action.first || it == action.second }
                draftSubmitted[actor] = true

                if (draftSubmitted.p1 && draftSubmitted.p2) {
                    draftSubmitted.p1 = false
                    draftSubmitted.p2 = false
                    swapDraftPacks()
                }
            }

            is Action.DraftClose -> {
                hands[actor].add(action.keep)
                draftPacks[actor].removeAll { it == action.keep || it == action.discard }
                if (draftPendingDiscard == null) draftPendingDiscard = PlayerPair(null, null)
                draftPendingDiscard!![actor] = action.discard
                draftSubmitted[actor] = true

                if (draftSubmitted.p1 && draftSubmitted.p2) {
                    publishDraftDiscards()
                    draftSubmitted.p1 = false
                    draftSubmitted.p2 = false
                    draftPacks.p1.clear()
                    draftPacks.p2.clear()
                    revealDraftedHands()
                    beginRound()
                }
            }

            is Action.DraftDiscard -> {
                hands[actor].remove(action.id)
                draftDiscarded[actor] = action.id
                draftSubmitted[actor] = true

                if (draftSubmitted.p1 && draftSubmitted.p2) {
                    draftSubmitted.p1 = false
                    draftSubmitted.p2 = false
                    if (draftDiscards == null) draftDiscards = PlayerPair.repeating { mutableListOf() }
                    draftDiscarded.p1?.let { draftDiscards!!.p1.add(it) }
                    draftDiscarded.p2?.let { draftDiscards!!.p2.add(it) }
                    revealDraftedHands()
                    beginRound()
                }
            }

            is Action.SelectRevealedScoringCards -> {
                revealed[actor].clear()
                revealed[actor].addAll(action.ids)
                revealSubmitted[actor] = true
                if (revealSubmitted.p1 && revealSubmitted.p2) {
                    revealSubmitted.p1 = false
                    revealSubmitted.p2 = false
                    beginRound()
                }
            }

            is Action.RevealAdditional -> {
                revealed[actor].add(action.id)
                revealSubmitted[actor] = true
                if (revealSubmitted.p1 && revealSubmitted.p2) {
                    revealSubmitted.p1 = false
                    revealSubmitted.p2 = false
                    round += 1
                    beginRound()
                }
            }

            is Action.Split -> {
                pendingSplits[actor] = PendingSplit(
                    action.pileA.toList(),
                    action.pileB.toList(),
                    CardSet.from(action.faceDown),
                )
                splitSubmitted[actor] = true
                if (config.splitters(round).all { splitSubmitted[it] }) {
                    splitSubmitted.p1 = false
                    splitSubmitted.p2 = false
                    phase = Phase.CHOOSE
                }
            }

            is Action.Choose -> {
                val chooser = actor
                val splitter = actor.opponent
                val split = pendingSplits[splitter] ?: return
                val taken = split.pile(action.pile)
                val left = split.pile(action.pile.other)

                collections[chooser].addAll(taken)
                collections[splitter].addAll(left)

                (split.pileA + split.pileB).forEach { id ->
                    if (!split.faceDown.contains(id)) observations[chooser].insert(id)
                }
                taken.forEach { observations[chooser].insert(it) }
                if (!config.persistentHiddenCards) {
                    (split.pileA + split.pileB).forEach { observations[chooser].insert(it) }
                }

                chooseSubmitted[chooser] = true
                takenPile[chooser] = action.pile

                if (config.choosers(round).all { chooseSubmitted[it] }) {
                    val outcome = RoundOutcome(
                        round,
                        PlayerPair(
                            pendingSplits.p1?.copySplit(),
                            pendingSplits.p2?.copySplit(),
                        ),
                        PlayerPair(takenPile.p1, takenPile.p2),
                    )
                    lastRound = outcome
                    roundHistory?.add(outcome.copyOutcome())

                    config.splitters(round).forEach { splitMaker ->
                        val resolvedSplit = pendingSplits[splitMaker] ?: return@forEach
                        val resolvedTaken = takenPile[splitMaker.opponent] ?: return@forEach
                        val faceDownInTaken = resolvedSplit.pile(resolvedTaken).count {
                            resolvedSplit.faceDown.contains(it)
                        }
                        splitLog.add(
                            SplitRecord(
                                round = round,
                                splitter = splitMaker,
                                drawCount = resolvedSplit.pileA.size + resolvedSplit.pileB.size,
                                faceDownCount = resolvedSplit.faceDown.count,
                                faceDownInTaken = faceDownInTaken,
                                taken = resolvedTaken,
                            )
                        )
                    }

                    chooseSubmitted.p1 = false
                    chooseSubmitted.p2 = false
                    takenPile.p1 = null
                    takenPile.p2 = null
                    pendingSplits.p1 = null
                    pendingSplits.p2 = null
                    currentDraw.p1.clear()
                    currentDraw.p2.clear()
                    advanceAfterChoose()
                }
            }
        }
    }

    private fun swapDraftPacks() {
        val p1 = draftPacks.p1
        draftPacks.p1 = draftPacks.p2
        draftPacks.p2 = p1
    }

    private fun revealDraftedHands() {
        listOf(PlayerId.P1, PlayerId.P2).forEach { player ->
            val first = draftFirstPick[player]
            revealed[player].clear()
            revealed[player].addAll(hands[player].filter { it != first })
        }
    }

    private fun beginRound() {
        currentDraw.p1.clear()
        currentDraw.p2.clear()

        for (splitter in config.splitters(round)) {
            val count = config.drawCount(round)
            val available = deck.size - drawn
            val take = minOf(count, available)
            val ids = mutableListOf<Int>()
            repeat(take) { offset -> ids.add(deck[drawn + offset].id) }
            drawn += take
            currentDraw[splitter].addAll(ids)
            ids.forEach { observations[splitter].insert(it) }
        }

        phase = Phase.SPLIT
    }

    private fun advanceAfterChoose() {
        if (
            config.progressiveReveal &&
            round == config.progressiveRevealAfterRound &&
            revealed.p1.size < config.finalRevealCount
        ) {
            phase = Phase.ADDITIONAL_REVEAL
            return
        }

        if (round >= config.roundCount) {
            phase = Phase.FINISHED
            return
        }

        round += 1
        beginRound()
    }

    fun scorecard(player: PlayerId): Scorecard = Scoring.score(
        counts = counts(player),
        hand = hands[player],
        opponentCounts = counts(player.opponent),
        opponentHand = hands[player.opponent],
    )

    /** Final tiebreak: most Gold Nuggets, then fewest Fool's Gold, then Player 2. */
    fun winner(): PlayerId {
        val s1 = scorecard(PlayerId.P1).total
        val s2 = scorecard(PlayerId.P2).total
        if (s1 != s2) return if (s1 > s2) PlayerId.P1 else PlayerId.P2

        val c1 = counts(PlayerId.P1)
        val c2 = counts(PlayerId.P2)
        if (c1.goldNugget != c2.goldNugget) return if (c1.goldNugget > c2.goldNugget) PlayerId.P1 else PlayerId.P2
        if (c1.foolsGold != c2.foolsGold) return if (c1.foolsGold < c2.foolsGold) PlayerId.P1 else PlayerId.P2
        return PlayerId.P2
    }

    fun view(player: PlayerId): PlayerView = PlayerView(this, player)

    fun claimJournal(player: PlayerId): List<ClaimJournalRound> = (roundHistory ?: emptyList()).map { outcome ->
        val projected = mutableListOf<ClaimJournalSplit>()
        listOf(PlayerId.P1, PlayerId.P2).forEach { splitter ->
            val split = outcome.splits[splitter] ?: return@forEach
            val taken = outcome.taken[splitter.opponent] ?: return@forEach
            val isMine = splitter == player
            val iChose = splitter.opponent == player

            fun cards(ids: List<Int>, pile: PileId): List<VisibleCard> = ids.map { id ->
                val claimed = iChose && pile == taken
                if (isMine || claimed || !split.faceDown.contains(id)) {
                    VisibleCard.Known(id, type(id))
                } else {
                    VisibleCard.Hidden(id)
                }
            }

            projected.add(
                ClaimJournalSplit(
                    splitter,
                    cards(split.pileA, PileId.A),
                    cards(split.pileB, PileId.B),
                    taken,
                    isMine,
                )
            )
        }
        ClaimJournalRound(outcome.round, projected)
    }

    private fun deepCopy(): GameState = GameState(
        config = config,
        rng = SeededRng(rng.state),
        phase = phase,
        round = round,
        deck = deck,
        drawn = drawn,
        collections = PlayerPair(collections.p1.toMutableList(), collections.p2.toMutableList()),
        hands = PlayerPair(hands.p1.toMutableList(), hands.p2.toMutableList()),
        revealed = PlayerPair(revealed.p1.toMutableList(), revealed.p2.toMutableList()),
        observations = PlayerPair(observations.p1.copySet(), observations.p2.copySet()),
        currentDraw = PlayerPair(currentDraw.p1.toMutableList(), currentDraw.p2.toMutableList()),
        pendingSplits = PlayerPair(pendingSplits.p1?.copySplit(), pendingSplits.p2?.copySplit()),
        splitSubmitted = PlayerPair(splitSubmitted.p1, splitSubmitted.p2),
        chooseSubmitted = PlayerPair(chooseSubmitted.p1, chooseSubmitted.p2),
        takenPile = PlayerPair(takenPile.p1, takenPile.p2),
        lastRound = lastRound?.copyOutcome(),
        roundHistory = roundHistory?.map { it.copyOutcome() }?.toMutableList(),
        splitLog = splitLog.toMutableList(),
        revealSubmitted = PlayerPair(revealSubmitted.p1, revealSubmitted.p2),
        draftPacks = PlayerPair(draftPacks.p1.toMutableList(), draftPacks.p2.toMutableList()),
        draftSubmitted = PlayerPair(draftSubmitted.p1, draftSubmitted.p2),
        draftFirstPick = PlayerPair(draftFirstPick.p1, draftFirstPick.p2),
        draftDiscarded = PlayerPair(draftDiscarded.p1, draftDiscarded.p2),
        draftDiscards = draftDiscards?.let { PlayerPair(it.p1.toMutableList(), it.p2.toMutableList()) },
        draftPendingDiscard = draftPendingDiscard?.let { PlayerPair(it.p1, it.p2) },
        draftLegacyMode = draftLegacyMode,
    )

    companion object {
        fun newGame(config: GameConfig = GameConfig(), seed: ULong): GameState {
            val rng = SeededRng(seed)

            val shuffledDeck = MiningDeck.build(MiningDeck.scaledComposition(config.deckSize)).toMutableList()
            rng.shuffle(shuffledDeck)
            val deck = shuffledDeck.mapIndexed { index, card -> MiningCard(index, card.type) }

            val scoring = (0 until ScoringCardId.total).map { ScoringCardId.atIndex(it) }.toMutableList()
            rng.shuffle(scoring)

            val hands = PlayerPair.repeating { mutableListOf<ScoringCardId>() }
            val draftPacks = PlayerPair.repeating { mutableListOf<ScoringCardId>() }

            if (config.scoringDraft) {
                val packSize = config.draftShape.openingPackSize
                val pool = scoring.take(packSize * 2)
                draftPacks.p1.addAll(pool.take(packSize))
                draftPacks.p2.addAll(pool.takeLast(packSize))
            } else {
                hands.p1.addAll(scoring.subList(0, GameConfig.HAND_SIZE))
                hands.p2.addAll(scoring.subList(GameConfig.HAND_SIZE, GameConfig.HAND_SIZE * 2))
            }

            return GameState(
                config = config,
                rng = rng,
                phase = if (config.scoringDraft) Phase.DRAFT else Phase.REVEAL_SELECTION,
                round = 1,
                deck = deck,
                drawn = 0,
                collections = PlayerPair.repeating { mutableListOf() },
                hands = hands,
                revealed = PlayerPair.repeating { mutableListOf() },
                observations = PlayerPair.repeating { CardSet() },
                currentDraw = PlayerPair.repeating { mutableListOf() },
                pendingSplits = PlayerPair(null, null),
                splitSubmitted = PlayerPair(false, false),
                chooseSubmitted = PlayerPair(false, false),
                takenPile = PlayerPair(null, null),
                lastRound = null,
                roundHistory = mutableListOf(),
                splitLog = mutableListOf(),
                revealSubmitted = PlayerPair(false, false),
                draftPacks = draftPacks,
                draftSubmitted = PlayerPair(false, false),
                draftFirstPick = PlayerPair(null, null),
                draftDiscarded = PlayerPair(null, null),
                draftDiscards = PlayerPair.repeating { mutableListOf() },
                draftPendingDiscard = PlayerPair(null, null),
                draftLegacyMode = false,
            )
        }
    }
}

private fun RoundOutcome.copyOutcome(): RoundOutcome = RoundOutcome(
    round,
    PlayerPair(splits.p1?.copySplit(), splits.p2?.copySplit()),
    PlayerPair(taken.p1, taken.p2),
)
