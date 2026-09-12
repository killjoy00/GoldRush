package com.killjoy00.goldrush.review

import android.app.Activity
import android.content.Context
import com.google.android.play.core.review.ReviewManagerFactory
import com.killjoy00.goldrush.BuildConfig
import com.killjoy00.goldrush.career.CareerStats

internal object RatingsPromptPolicy {
    const val MINIMUM_GAMES = 3

    fun shouldAsk(
        didWin: Boolean,
        games: Int,
        version: String,
        askedVersion: String?,
    ): Boolean = didWin && games >= MINIMUM_GAMES && askedVersion != version
}

/**
 * Android counterpart to the iOS ratings prompt: ask only after a win, only
 * after the player has enough completed games to have an opinion, and at most
 * once per public app version.
 *
 * Google Play intentionally does not report whether its review card was shown
 * or whether the player submitted a rating, so we record the attempt before
 * requesting the flow and never block normal navigation on it.
 */
object RatingsPrompt {
    private const val STORE_NAME = "goldrush_ratings_prompt_v1"
    private const val ASKED_VERSION_KEY = "asked_version"

    fun consider(activity: Activity, didWin: Boolean, stats: CareerStats) {
        val version = BuildConfig.VERSION_NAME
        val preferences = activity.getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
        val askedVersion = preferences.getString(ASKED_VERSION_KEY, null)
        if (!RatingsPromptPolicy.shouldAsk(didWin, stats.games, version, askedVersion)) return

        preferences.edit().putString(ASKED_VERSION_KEY, version).apply()

        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (request.isSuccessful) {
                manager.launchReviewFlow(activity, request.result)
                    .addOnCompleteListener { /* The result is intentionally opaque. */ }
            }
        }
    }
}
