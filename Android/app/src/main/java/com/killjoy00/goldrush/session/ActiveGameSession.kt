package com.killjoy00.goldrush.session

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.killjoy00.goldrush.ai.ProspectorAgent
import com.killjoy00.goldrush.ai.ProspectorController
import com.killjoy00.goldrush.ai.ProspectorFidelity
import com.killjoy00.goldrush.engine.Action
import com.killjoy00.goldrush.engine.GameConfig
import com.killjoy00.goldrush.engine.GameState
import com.killjoy00.goldrush.engine.PileId
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.ScoringCardId
import java.util.Base64
import kotlinx.coroutines.flow.first

private const val STORE_NAME = "goldrush_active_game_v1"
private val Context.activeGameDataStore: DataStore<Preferences> by preferencesDataStore(name = STORE_NAME)

data class ActiveGameSession(
    val gameId: String,
    val seed: ULong,
    val scoringDraft: Boolean,
    val simultaneousSplit: Boolean,
    val solo: Boolean,
    val prospector: ProspectorFidelity,
    val visibleSeat: PlayerId?,
    val actions: List<Action> = emptyList(),
) {
    fun append(action: Action, nextVisibleSeat: PlayerId?): ActiveGameSession = copy(
        visibleSeat = nextVisibleSeat,
        actions = actions + action,
    )

    fun withVisibleSeat(seat: PlayerId?): ActiveGameSession = copy(visibleSeat = seat)

    fun rebuild(): RebuiltGameSession? = runCatching {
        val controller = if (solo) {
            ProspectorController(
                humanSeat = PlayerId.P1,
                agent = ProspectorAgent(prospector),
            )
        } else {
            null
        }

        var state = GameState.newGame(
            config = GameConfig(
                scoringDraft = scoringDraft,
                simultaneousSplit = simultaneousSplit,
            ),
            seed = seed,
        )
        if (controller != null) state = controller.start(state)

        actions.forEach { action ->
            val next = if (controller != null) controller.submit(state, action) else state.apply(action)
            require(next !== state) { "saved action is no longer legal: $action" }
            state = next
        }

        RebuiltGameSession(state, controller)
    }.getOrNull()
}

data class RebuiltGameSession(
    val state: GameState,
    val controller: ProspectorController?,
)

class ActiveGameSessionRepository(context: Context) {
    private val dataStore = context.applicationContext.activeGameDataStore

    suspend fun loadEncoded(): String? = dataStore.data.first()[SESSION_KEY]

    suspend fun saveEncoded(encoded: String?) {
        dataStore.edit { preferences ->
            if (encoded == null) preferences.remove(SESSION_KEY) else preferences[SESSION_KEY] = encoded
        }
    }

    companion object {
        private val SESSION_KEY = stringPreferencesKey("active_game")
    }
}

/**
 * Stable, deliberately boring text format. The transcript is small, contains no
 * arbitrary user text, and can be discarded safely if a future schema cannot decode it.
 */
object ActiveGameSessionCodec {
    private const val VERSION = "GR1"

    fun encode(session: ActiveGameSession): String = buildString {
        appendLine(VERSION)
        appendLine("id=${encodeText(session.gameId)}")
        appendLine("seed=${session.seed}")
        appendLine("draft=${bool(session.scoringDraft)}")
        appendLine("together=${bool(session.simultaneousSplit)}")
        appendLine("solo=${bool(session.solo)}")
        appendLine("prospector=${session.prospector.name}")
        appendLine("seat=${session.visibleSeat?.name ?: "-"}")
        session.actions.forEach { appendLine("action=${encodeAction(it)}") }
    }.trimEnd()

    fun decode(encoded: String?): ActiveGameSession? {
        if (encoded.isNullOrBlank()) return null
        return runCatching {
            val lines = encoded.lineSequence().filter { it.isNotBlank() }.toList()
            require(lines.firstOrNull() == VERSION)
            val fields = lines.drop(1).filterNot { it.startsWith("action=") }
                .associate { line -> line.substringBefore('=') to line.substringAfter('=') }
            val actions = lines.drop(1).filter { it.startsWith("action=") }
                .map { decodeAction(it.removePrefix("action=")) }

            ActiveGameSession(
                gameId = decodeText(fields.getValue("id")),
                seed = fields.getValue("seed").toULong(),
                scoringDraft = parseBool(fields.getValue("draft")),
                simultaneousSplit = parseBool(fields.getValue("together")),
                solo = parseBool(fields.getValue("solo")),
                prospector = ProspectorFidelity.valueOf(fields.getValue("prospector")),
                visibleSeat = fields.getValue("seat").takeUnless { it == "-" }?.let(PlayerId::valueOf),
                actions = actions,
            )
        }.getOrNull()
    }

    private fun encodeAction(action: Action): String = when (action) {
        is Action.SelectRevealedScoringCards -> "R|${cards(action.ids)}"
        is Action.Split -> "S|${ints(action.pileA)}|${ints(action.pileB)}|${ints(action.faceDown)}"
        is Action.Choose -> "C|${action.pile.name}"
        is Action.DraftOpen -> "DO|${action.keep.index}|${action.discard.index}"
        is Action.DraftPick -> "DP|${action.id.index}"
        is Action.DraftTakePair -> "DT|${action.first.index}|${action.second.index}"
        is Action.DraftClose -> "DC|${action.keep.index}|${action.discard.index}"
        is Action.DraftDiscard -> "DD|${action.id.index}"
        is Action.RevealAdditional -> "RA|${action.id.index}"
    }

    private fun decodeAction(encoded: String): Action {
        val p = encoded.split('|')
        return when (p[0]) {
            "R" -> Action.SelectRevealedScoringCards(parseCards(p.getOrElse(1) { "" }))
            "S" -> Action.Split(parseInts(p[1]), parseInts(p[2]), parseInts(p[3]))
            "C" -> Action.Choose(PileId.valueOf(p[1]))
            "DO" -> Action.DraftOpen(card(p[1]), card(p[2]))
            "DP" -> Action.DraftPick(card(p[1]))
            "DT" -> Action.DraftTakePair(card(p[1]), card(p[2]))
            "DC" -> Action.DraftClose(card(p[1]), card(p[2]))
            "DD" -> Action.DraftDiscard(card(p[1]))
            "RA" -> Action.RevealAdditional(card(p[1]))
            else -> error("unknown saved action ${p[0]}")
        }
    }

    private fun card(index: String) = ScoringCardId.atIndex(index.toInt())
    private fun cards(ids: List<ScoringCardId>) = ids.joinToString(",") { it.index.toString() }
    private fun ints(ids: List<Int>) = ids.joinToString(",")
    private fun parseCards(value: String) = parseInts(value).map(ScoringCardId::atIndex)
    private fun parseInts(value: String) = if (value.isBlank()) emptyList() else value.split(',').map(String::toInt)
    private fun bool(value: Boolean) = if (value) "1" else "0"
    private fun parseBool(value: String): Boolean = when (value) {
        "1" -> true
        "0" -> false
        else -> error("invalid boolean")
    }

    private fun encodeText(value: String): String =
        Base64.getUrlEncoder().withoutPadding().encodeToString(value.toByteArray(Charsets.UTF_8))

    private fun decodeText(value: String): String =
        Base64.getUrlDecoder().decode(value).toString(Charsets.UTF_8)
}
