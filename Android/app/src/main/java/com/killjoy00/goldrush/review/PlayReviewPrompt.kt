package com.killjoy00.goldrush.review

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import com.google.android.play.core.review.ReviewManagerFactory
import com.killjoy00.goldrush.career.CareerStats
import com.killjoy00.goldrush.career.CareerStatsRepository
import kotlinx.coroutines.flow.collect

internal object ReviewPromptPolicy {
    fun shouldPrompt(
        previous: CareerStats,
        current: CareerStats,
        askedVersion: String?,
        currentVersion: String,
    ): Boolean =
        current.games > previous.games &&
            current.wins > previous.wins &&
            current.games >= 3 &&
            askedVersion != currentVersion
}

/**
 * Mirrors the iOS 1.5 policy: after a win, once the player has completed at
 * least three games, ask at most once per app version. Google Play may still
 * suppress the sheet according to its own quota; that is expected.
 */
@Composable
fun PlayReviewPromptHost(activity: Activity) {
    val context = activity.applicationContext
    val careerRepository = remember(context) { CareerStatsRepository(context) }
    val reviewManager = remember(activity) { ReviewManagerFactory.create(activity) }
    val preferences = remember(context) {
        context.getSharedPreferences("goldrush_review_prompt_v1", Context.MODE_PRIVATE)
    }
    val version = remember(context) {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName.orEmpty()
    }

    LaunchedEffect(careerRepository, reviewManager, version) {
        var previous: CareerStats? = null
        careerRepository.stats.collect { current ->
            val prior = previous
            previous = current
            if (prior == null) return@collect

            val askedVersion = preferences.getString("asked_version", null)
            if (!ReviewPromptPolicy.shouldPrompt(prior, current, askedVersion, version)) {
                return@collect
            }

            reviewManager.requestReviewFlow().addOnCompleteListener { request ->
                if (!request.isSuccessful) return@addOnCompleteListener

                // Record before launching, matching iOS: a quota-suppressed or
                // interrupted Play sheet must not cause repeated nagging.
                preferences.edit().putString("asked_version", version).apply()
                reviewManager.launchReviewFlow(activity, request.result)
            }
        }
    }
}
