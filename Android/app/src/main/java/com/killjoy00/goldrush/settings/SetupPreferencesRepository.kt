package com.killjoy00.goldrush.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.preferencesDataStore
import java.io.IOException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map

private const val STORE_NAME = "goldrush_setup_v1"
private val Context.setupDataStore: DataStore<Preferences> by preferencesDataStore(name = STORE_NAME)

data class SetupPreferences(
    val scoringDraft: Boolean = false,
    val simultaneousSplit: Boolean = true,
)

class SetupPreferencesRepository(context: Context) {
    private val dataStore = context.applicationContext.setupDataStore

    val preferences: Flow<SetupPreferences> = dataStore.data
        .catch { error ->
            if (error is IOException) emit(emptyPreferences()) else throw error
        }
        .map(SetupPreferencesCodec::decode)

    suspend fun setScoringDraft(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[SetupPreferencesCodec.scoringDraftKey] = enabled
        }
    }

    suspend fun setSimultaneousSplit(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[SetupPreferencesCodec.simultaneousSplitKey] = enabled
        }
    }
}

internal object SetupPreferencesCodec {
    val scoringDraftKey = booleanPreferencesKey("scoring_draft")
    val simultaneousSplitKey = booleanPreferencesKey("simultaneous_split")

    fun decode(preferences: Preferences): SetupPreferences = SetupPreferences(
        scoringDraft = preferences[scoringDraftKey] ?: false,
        simultaneousSplit = preferences[simultaneousSplitKey] ?: true,
    )

    fun write(preferences: MutablePreferences, setup: SetupPreferences) {
        preferences[scoringDraftKey] = setup.scoringDraft
        preferences[simultaneousSplitKey] = setup.simultaneousSplit
    }
}
