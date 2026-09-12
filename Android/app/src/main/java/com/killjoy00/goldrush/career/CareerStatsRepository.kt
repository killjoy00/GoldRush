package com.killjoy00.goldrush.career

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.killjoy00.goldrush.engine.ScoringFamily
import java.io.IOException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map

private const val STORE_NAME = "goldrush_career_stats_v1"
private val Context.careerDataStore: DataStore<Preferences> by preferencesDataStore(name = STORE_NAME)

class CareerStatsRepository(context: Context) {
    private val dataStore = context.applicationContext.careerDataStore

    val stats: Flow<CareerStats> = dataStore.data
        .catch { error ->
            if (error is IOException) emit(emptyPreferences()) else throw error
        }
        .map(CareerStatsPreferencesCodec::decode)

    suspend fun record(game: CompletedCareerGame?): CareerStats {
        var result = CareerStats()
        dataStore.edit { preferences ->
            val current = CareerStatsPreferencesCodec.decode(preferences)
            val next = if (game == null) current else CareerStatsRecorder.record(current, game)
            if (next != current) CareerStatsPreferencesCodec.write(preferences, next)
            result = next
        }
        return result
    }

    suspend fun clear() {
        dataStore.edit { preferences -> CareerStatsPreferencesCodec.clear(preferences) }
    }
}

internal object CareerStatsPreferencesCodec {
    private val gamesKey = intPreferencesKey("games")
    private val winsKey = intPreferencesKey("wins")
    private val totalScoreKey = intPreferencesKey("total_score")
    private val totalMarginKey = intPreferencesKey("total_margin")
    private val bestScoreKey = intPreferencesKey("best_score")
    private val recordedIdsKey = stringPreferencesKey("recorded_game_ids")

    private fun modeIndex(label: String): Int = CareerStatsRecorder.modeLabels.indexOf(label)

    private fun modeKey(label: String, field: String): Preferences.Key<Int> =
        intPreferencesKey("mode_${modeIndex(label)}_$field")

    private fun familyKey(family: ScoringFamily, field: String): Preferences.Key<Int> =
        intPreferencesKey("family_${family.name.lowercase()}_$field")

    fun decode(preferences: Preferences): CareerStats {
        val modes = buildMap {
            CareerStatsRecorder.modeLabels.forEach { label ->
                val games = preferences[modeKey(label, "games")] ?: 0
                val wins = preferences[modeKey(label, "wins")] ?: 0
                val totalScore = preferences[modeKey(label, "total_score")] ?: 0
                val totalMargin = preferences[modeKey(label, "total_margin")] ?: 0
                val bestScore = preferences[modeKey(label, "best_score")] ?: Int.MIN_VALUE
                if (games != 0 || wins != 0 || totalScore != 0 || totalMargin != 0 || bestScore != Int.MIN_VALUE) {
                    put(
                        label,
                        CareerModeRecord(
                            games = games,
                            wins = wins,
                            totalScore = totalScore,
                            totalMargin = totalMargin,
                            bestScore = bestScore,
                        )
                    )
                }
            }
        }

        val families = buildMap {
            ScoringFamily.entries.forEach { family ->
                val cards = preferences[familyKey(family, "cards")] ?: 0
                val points = preferences[familyKey(family, "points")] ?: 0
                val games = preferences[familyKey(family, "games")] ?: 0
                if (cards != 0 || points != 0 || games != 0) {
                    put(
                        family.displayName,
                        CareerFamilyRecord(cards = cards, points = points, games = games)
                    )
                }
            }
        }

        val recordedIds = preferences[recordedIdsKey]
            ?.lineSequence()
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?.toList()
            ?.takeLast(CareerStatsRecorder.MAX_RECORDED_GAME_IDS)
            ?: emptyList()

        return CareerStats(
            games = preferences[gamesKey] ?: 0,
            wins = preferences[winsKey] ?: 0,
            totalScore = preferences[totalScoreKey] ?: 0,
            totalMargin = preferences[totalMarginKey] ?: 0,
            bestScore = preferences[bestScoreKey] ?: Int.MIN_VALUE,
            modes = modes,
            families = families,
            recordedGameIds = recordedIds,
        )
    }

    fun write(preferences: MutablePreferences, stats: CareerStats) {
        preferences[gamesKey] = stats.games
        preferences[winsKey] = stats.wins
        preferences[totalScoreKey] = stats.totalScore
        preferences[totalMarginKey] = stats.totalMargin
        preferences[bestScoreKey] = stats.bestScore
        preferences[recordedIdsKey] = stats.recordedGameIds.joinToString("\n")

        CareerStatsRecorder.modeLabels.forEach { label ->
            val record = stats.modes[label] ?: CareerModeRecord()
            preferences[modeKey(label, "games")] = record.games
            preferences[modeKey(label, "wins")] = record.wins
            preferences[modeKey(label, "total_score")] = record.totalScore
            preferences[modeKey(label, "total_margin")] = record.totalMargin
            preferences[modeKey(label, "best_score")] = record.bestScore
        }

        ScoringFamily.entries.forEach { family ->
            val record = stats.families[family.displayName] ?: CareerFamilyRecord()
            preferences[familyKey(family, "cards")] = record.cards
            preferences[familyKey(family, "points")] = record.points
            preferences[familyKey(family, "games")] = record.games
        }
    }

    fun clear(preferences: MutablePreferences) {
        preferences.clear()
    }
}
