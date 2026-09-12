package com.killjoy00.goldrush.settings

import androidx.datastore.preferences.core.mutablePreferencesOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SetupPreferencesRepositoryTest {
    @Test
    fun defaultsMatchIosSetup() {
        val setup = SetupPreferencesCodec.decode(mutablePreferencesOf())
        assertFalse(setup.scoringDraft)
        assertTrue(setup.simultaneousSplit)
    }

    @Test
    fun codecRoundTripsBothChoices() {
        val expected = SetupPreferences(
            scoringDraft = true,
            simultaneousSplit = false,
        )
        val preferences = mutablePreferencesOf()

        SetupPreferencesCodec.write(preferences, expected)

        assertEquals(expected, SetupPreferencesCodec.decode(preferences))
    }
}
