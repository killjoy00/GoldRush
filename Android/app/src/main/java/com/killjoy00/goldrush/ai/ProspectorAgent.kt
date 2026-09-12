package com.killjoy00.goldrush.ai

import com.killjoy00.goldrush.engine.Action
import com.killjoy00.goldrush.engine.Board
import com.killjoy00.goldrush.engine.DraftShape
import com.killjoy00.goldrush.engine.GameConfig
import com.killjoy00.goldrush.engine.GameState
import com.killjoy00.goldrush.engine.MiningCounts
import com.killjoy00.goldrush.engine.MiningDeck
import com.killjoy00.goldrush.engine.MiningType
import com.killjoy00.goldrush.engine.Phase
import com.killjoy00.goldrush.engine.PileId
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.PlayerView
import com.killjoy00.goldrush.engine.Scoring
import com.killjoy00.goldrush.engine.ScoringCardCatalog
import com.killjoy00.goldrush.engine.ScoringCardId
import com.killjoy00.goldrush.engine.ScoringEffect
import com.killjoy00.goldrush.engine.VisibleCard
import kotlin.math.abs

/** The three shipping iOS Prospector personalities, in increasing inference fidelity. */
enum class ProspectorFidelity(val displayName: String) {
    STEADY("Steady"),
    CUNNING("Cunning"),
    RUTHLESS("Ruthless"),
}

data class SplitDecision(
    val pileA: List<Int>,
    val pileB: List<Int>,
    val faceDown: List<Int>,
)

/**
 * Android port of the shipping iOS InferenceAgent.
 *
 * The public API accepts only PlayerView. That privacy boundary is deliberate:
 * the Prospector can reason from public cards, observed mining cards, and split
 * history, but it cannot inspect identities the player has never observed.
 */
class ProspectorAgent(
    val fidelity: ProspectorFidelity = ProspectorFidelity.RUTHLESS,
) {
    fun action(view: PlayerView): Action? = when (view.phase) {
        Phase.REVEAL_SELECTION -> Action.SelectRevealedScoringCards(
            selectReveal(view, view.config.initialRevealCount)
        )

        Phase.ADDITIONAL_REVEAL -> {
            val legal = view.hand.filter { it !in view.myRevealed }
            if (legal.isEmpty()) null else Action.RevealAdditional(revealAdditional(legal))
        }

        Phase.SPLIT -> split(view).let { Action.Split(it.pileA, it.pileB, it.faceDown) }
        Phase.CHOOSE -> Action.Choose(choose(view))
        Phase.DRAFT -> draftAction(view)
        Phase.DRAFT_DISCARD -> {
            if (view.hand.isEmpty()) null else Action.DraftDiscard(draftDiscard(view, view.hand))
        }

        Phase.FINISHED -> null
    }

    fun selectReveal(view: PlayerView, count: Int): List<ScoringCardId> =
        view.hand.sortedWith(
            compareByDescending<ScoringCardId> { disclosureValue(it) }
                .thenBy { it.index }
        ).take(count)

    fun disclosureValue(id: ScoringCardId): Int =
        ScoringCardCatalog[id].effects.sumOf { effect ->
            when (effect) {
                is ScoringEffect.BonusIfStrictlyMore,
                is ScoringEffect.BonusPerTypeStrictlyMore -> 3

                is ScoringEffect.BonusIfAtLeast,
                is ScoringEffect.TieredByCount -> 2

                is ScoringEffect.PerTypeBeyond,
                is ScoringEffect.PerNthScaling,
                is ScoringEffect.PerNthLinear -> 1

                else -> 0
            }
        }

    fun split(view: PlayerView): SplitDecision {
        val types = view.currentDraw.mapNotNull { card -> card.type?.let { card.id to it } }.toMap()
        val ids = view.currentDraw.map { it.id }
        require(ids.size >= 2) { "Prospector needs at least two cards to split" }

        val current = view.collectionCounts
        val hand = view.hand
        val model = OpponentModel(view)
        val hiddenNeeded = view.config.faceDownCount(view.round)

        fun counts(pile: List<Int>): MiningCounts =
            MiningCounts.countingTypes(pile.mapNotNull { types[it] })

        fun ownValue(pile: List<Int>): Int =
            AgentValuation.marginal(counts(pile), current, hand)

        fun opponentValue(pile: List<Int>): Int = model.value(counts(pile))

        var bestA = listOf(ids.first())
        var bestB = ids.drop(1)
        var bestScore = Double.NEGATIVE_INFINITY

        SplitEnumerator.cuts(ids).forEach { (a, b) ->
            if (abs(a.size - b.size) > SIZE_SLACK) return@forEach
            val ownA = ownValue(a).toDouble()
            val ownB = ownValue(b).toDouble()
            val floor = minOf(ownA, ownB)
            val oppA = opponentValue(a).toDouble()
            val oppB = opponentValue(b).toDouble()
            val steer = if (ownA <= ownB) oppA - oppB else oppB - oppA
            val score = floor + 0.01 * steer
            if (score > bestScore) {
                bestScore = score
                bestA = a
                bestB = b
            }
        }

        if (fidelity == ProspectorFidelity.STEADY || hiddenNeeded == 0) {
            val byOwnValue = ids.sortedBy { ownValue(listOf(it)) }
            return SplitDecision(bestA, bestB, byOwnValue.take(hiddenNeeded))
        }

        val poolAverage = averageCardValue(model)
        var bestHidden = SplitEnumerator.faceDownChoices(ids, hiddenNeeded).firstOrNull().orEmpty()
        var bestDistortion = Double.NEGATIVE_INFINITY

        SplitEnumerator.faceDownChoices(ids, hiddenNeeded).forEach { candidate ->
            val distortion = candidate.sumOf { id ->
                abs(opponentValue(listOf(id)).toDouble() - poolAverage)
            }
            if (distortion > bestDistortion) {
                bestDistortion = distortion
                bestHidden = candidate
            }
        }

        return SplitDecision(bestA, bestB, bestHidden)
    }

    private fun averageCardValue(model: OpponentModel): Double {
        val pool = model.unseen.total
        if (pool <= 0) return 0.0

        var sum = 0.0
        MiningType.entries.forEach { type ->
            val unseenCount = model.unseen[type]
            if (unseenCount <= 0) return@forEach
            val one = MiningCounts().also { it[type] = 1 }
            sum += model.value(one).toDouble() * unseenCount.toDouble() / pool.toDouble()
        }
        return sum
    }

    fun choose(view: PlayerView): PileId {
        val piles = view.piles ?: return PileId.A
        val a = AgentValuation.expectedMarginal(
            piles.a,
            view.collectionCounts,
            view.hand,
            view.unseen,
        )
        val b = AgentValuation.expectedMarginal(
            piles.b,
            view.collectionCounts,
            view.hand,
            view.unseen,
        )

        if (fidelity != ProspectorFidelity.RUTHLESS) {
            return if (a >= b) PileId.A else PileId.B
        }

        val hiddenA = piles.a.count { it.isHidden }
        val hiddenB = piles.b.count { it.isHidden }
        val adjustedA = a - hiddenA.toDouble() * SUSPICION * abs(a)
        val adjustedB = b - hiddenB.toDouble() * SUSPICION * abs(b)
        return if (adjustedA >= adjustedB) PileId.A else PileId.B
    }

    fun draftPick(view: PlayerView, legal: List<ScoringCardId>): ScoringCardId {
        require(legal.isNotEmpty()) { "draft needs at least one legal card" }
        var best = legal.first()
        var bestValue = Int.MIN_VALUE
        legal.forEach { candidate ->
            val value = draftPriorValue(view.hand + candidate)
            if (value > bestValue) {
                bestValue = value
                best = candidate
            }
        }
        return best
    }

    fun draftDiscard(view: PlayerView, legal: List<ScoringCardId>): ScoringCardId {
        if (legal.isEmpty()) return view.hand.first()
        var best = legal.first()
        var bestKept = Int.MIN_VALUE
        legal.forEach { candidate ->
            val value = draftPriorValue(legal.filter { it != candidate })
            if (value > bestKept) {
                bestKept = value
                best = candidate
            }
        }
        return best
    }

    fun revealAdditional(legal: List<ScoringCardId>): ScoringCardId =
        legal.maxWithOrNull(
            compareBy<ScoringCardId> { disclosureValue(it) }
                .thenByDescending { -it.index }
        ) ?: legal.first()

    fun draftAction(view: PlayerView): Action? {
        val pack = view.draftPool
        if (pack.isEmpty()) return null

        if (view.config.draftShape == DraftShape.SEVEN_PAIRED) {
            return pairedDraftAction(view, pack)
        }

        if (pack.size == GameConfig.DRAFT_OPENING_PACK_SIZE) {
            val keep = draftPick(view, pack)
            val remaining = pack.filter { it != keep }
            if (remaining.isEmpty()) return null
            val discard = draftPick(view, remaining)
            return Action.DraftOpen(keep, discard)
        }

        if (pack.size == 2) {
            val keep = draftPick(view, pack)
            val discard = pack.firstOrNull { it != keep } ?: return null
            return Action.DraftClose(keep, discard)
        }

        return Action.DraftPick(draftPick(view, pack))
    }

    private fun pairedDraftAction(view: PlayerView, pack: List<ScoringCardId>): Action? {
        if (pack.size == 2) {
            val keep = draftPick(view, pack)
            val discard = pack.firstOrNull { it != keep } ?: return null
            return Action.DraftClose(keep, discard)
        }

        val first = draftPick(view, pack)
        if (pack.size !in view.config.draftShape.pairedPackSizes) {
            return Action.DraftPick(first)
        }

        val remaining = pack.filter { it != first }
        if (remaining.isEmpty()) return Action.DraftPick(first)

        var best = remaining.first()
        var bestValue = Int.MIN_VALUE
        remaining.forEach { candidate ->
            val value = draftPriorValue(view.hand + first + candidate)
            if (value > bestValue) {
                bestValue = value
                best = candidate
            }
        }
        return Action.DraftTakePair(first, best)
    }

    private fun draftReferenceProfiles(): List<MiningCounts> {
        val floor = MiningCounts()
        MiningDeck.standardComposition.forEach { (type, count) ->
            floor[type] = count * 30 / MiningDeck.STANDARD_SIZE
        }

        val residuals = listOf(
            listOf(MiningType.GOLD_NUGGET, MiningType.PACK_MULE, MiningType.SHOVEL),
            listOf(MiningType.GOLD_NUGGET, MiningType.PACK_MULE, MiningType.PAN),
            listOf(MiningType.GOLD_NUGGET, MiningType.PACK_MULE, MiningType.QUARTZ),
            listOf(MiningType.GOLD_NUGGET, MiningType.PACK_MULE, MiningType.SHOVEL),
            listOf(MiningType.GOLD_NUGGET, MiningType.PAN, MiningType.QUARTZ),
            listOf(MiningType.FOOLS_GOLD, MiningType.GOLD_ORE, MiningType.GRAVEL),
        )

        return residuals.map { extras ->
            floor.copy().also { counts -> extras.forEach { counts.add(it) } }
        }
    }

    fun draftPriorValue(hand: List<ScoringCardId>): Int {
        fun value(
            counts: MiningCounts,
            opponentBehind: Board,
            opponentAhead: Board,
        ): Int =
            Scoring.bestAllocation(counts, hand, opponentBehind).third +
                Scoring.bestAllocation(counts, hand, opponentAhead).third

        var total = 0
        draftReferenceProfiles().forEach { reference ->
            val leaner = reference.copy()
            val richer = reference.copy()
            MiningType.entries.forEach { type ->
                leaner[type] = maxOf(0, reference[type] - 1)
                richer[type] = reference[type] + 1
            }

            val behind = Scoring.bestAllocation(leaner, emptyList(), null).second
            val ahead = Scoring.bestAllocation(richer, emptyList(), null).second
            val baseline = value(reference, behind, ahead)
            var focused = baseline

            MiningType.entries.forEach { type ->
                val oneMore = reference.copy().also { it[type] = it[type] + 1 }
                focused = maxOf(focused, value(oneMore, behind, ahead))
            }
            total += baseline + focused
        }
        return total
    }

    companion object {
        private const val SIZE_SLACK = 1
        private const val SUSPICION = 0.15
    }
}

/**
 * Local solo transport equivalent to iOS AgentTransport. The caller owns the
 * returned GameState so Compose can keep state updates explicit and testable.
 */
class ProspectorController(
    val humanSeat: PlayerId = PlayerId.P1,
    val agent: ProspectorAgent,
) {
    val agentSeat: PlayerId = humanSeat.opponent

    fun start(state: GameState): GameState = advance(state)

    fun submit(state: GameState, action: Action): GameState {
        val next = state.apply(action)
        if (next === state) return state
        return advance(next)
    }

    fun advance(initial: GameState): GameState {
        var state = initial
        var safety = 0
        while (!state.isFinished && state.actingPlayer == agentSeat && safety++ < 32) {
            val action = agent.action(state.view(agentSeat)) ?: break
            val next = state.apply(action)
            if (next === state) break
            state = next
        }
        return state
    }
}

private object AgentValuation {
    fun selfValue(counts: MiningCounts, hand: List<ScoringCardId>): Int =
        Scoring.bestAllocation(counts, hand, null).third

    fun marginal(
        additions: MiningCounts,
        current: MiningCounts,
        hand: List<ScoringCardId>,
    ): Int = selfValue(current + additions, hand) - selfValue(current, hand)

    fun expectedMarginal(
        cards: List<VisibleCard>,
        current: MiningCounts,
        hand: List<ScoringCardId>,
        unseen: MiningCounts,
    ): Double {
        val known = MiningCounts()
        var hiddenCount = 0
        cards.forEach { card ->
            val type = card.type
            if (type == null) hiddenCount += 1 else known.add(type)
        }

        val base = marginal(known, current, hand).toDouble()
        if (hiddenCount == 0 || unseen.total <= 0) return base

        val after = current + known
        var expectedPerCard = 0.0
        MiningType.entries.forEach { type ->
            val count = unseen[type]
            if (count <= 0) return@forEach
            val one = MiningCounts().also { it[type] = 1 }
            val gain = marginal(one, after, hand)
            expectedPerCard += gain.toDouble() * count.toDouble() / unseen.total.toDouble()
        }
        return base + expectedPerCard * hiddenCount.toDouble()
    }
}

private class OpponentModel(view: PlayerView) {
    val revealedHand: List<ScoringCardId> = view.opponentRevealed
    val knownCounts: MiningCounts = view.opponentKnownCounts
    val hiddenCount: Int = view.opponentHiddenCount
    val unseen: MiningCounts = opponentUnseen(view)

    val estimatedCounts: MiningCounts
        get() {
            if (hiddenCount <= 0 || unseen.total <= 0) return knownCounts.copy()
            val estimate = knownCounts.copy()
            MiningType.entries.forEach { type ->
                estimate[type] = estimate[type] + (unseen[type] * hiddenCount) / unseen.total
            }
            return estimate
        }

    fun value(additions: MiningCounts): Int {
        if (revealedHand.isEmpty()) return additions.total
        val base = estimatedCounts
        return AgentValuation.selfValue(base + additions, revealedHand) -
            AgentValuation.selfValue(base, revealedHand)
    }

    private fun opponentUnseen(view: PlayerView): MiningCounts {
        val opponent = view.player.opponent
        var opponentSeen = 0

        view.splitLog.forEach { record ->
            if (record.splitter == opponent) {
                opponentSeen += record.drawCount
            } else {
                opponentSeen += (record.drawCount - record.faceDownCount) + record.faceDownInTaken
                if (!view.config.persistentHiddenCards) {
                    opponentSeen += record.faceDownCount - record.faceDownInTaken
                }
            }
        }

        if (view.config.splitters(view.round).contains(opponent)) {
            opponentSeen += view.config.drawCount(view.round)
        }

        val myUnseen = view.unseen
        val myUnseenTotal = myUnseen.total
        val opponentUnseenTotal = maxOf(0, view.config.deckSize - opponentSeen)
        if (myUnseenTotal <= 0) return myUnseen.copy()

        data class Remainder(
            val index: Int,
            val type: MiningType,
            val remainder: Int,
        )

        val estimate = MiningCounts()
        val remainders = mutableListOf<Remainder>()
        var allocated = 0

        MiningType.entries.forEachIndexed { index, type ->
            val scaled = myUnseen[type] * opponentUnseenTotal
            estimate[type] = scaled / myUnseenTotal
            allocated += estimate[type]
            remainders += Remainder(index, type, scaled % myUnseenTotal)
        }

        val shortfall = opponentUnseenTotal - allocated
        remainders.sortedWith(
            compareByDescending<Remainder> { it.remainder }.thenBy { it.index }
        ).take(shortfall).forEach { entry ->
            estimate[entry.type] = estimate[entry.type] + 1
        }
        return estimate
    }
}

private object SplitEnumerator {
    fun cuts(cards: List<Int>): List<Pair<List<Int>, List<Int>>> {
        if (cards.size < 2) return emptyList()
        val result = mutableListOf<Pair<List<Int>, List<Int>>>()
        val total = 1 shl cards.size

        for (mask in 1 until total) {
            if (mask and 1 == 0) continue
            if (mask == total - 1) continue
            val a = mutableListOf<Int>()
            val b = mutableListOf<Int>()
            cards.indices.forEach { index ->
                if (mask and (1 shl index) != 0) a += cards[index] else b += cards[index]
            }
            result += a to b
        }
        return result
    }

    fun faceDownChoices(cards: List<Int>, count: Int): List<List<Int>> {
        if (count <= 0) return listOf(emptyList())
        if (count > cards.size) return emptyList()
        val result = mutableListOf<List<Int>>()
        val current = mutableListOf<Int>()

        fun recurse(start: Int) {
            if (current.size == count) {
                result += current.toList()
                return
            }
            if (start >= cards.size) return
            for (index in start until cards.size) {
                current += cards[index]
                recurse(index + 1)
                current.removeAt(current.lastIndex)
            }
        }

        recurse(0)
        return result
    }
}
