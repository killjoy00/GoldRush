package com.killjoy00.goldrush

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.killjoy00.goldrush.career.CareerStats
import com.killjoy00.goldrush.career.CareerStatsRepository
import com.killjoy00.goldrush.review.RatingsPrompt
import com.killjoy00.goldrush.ui.GoldRushApp
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val activityScope = MainScope()
    private val careerRepository by lazy { CareerStatsRepository(applicationContext) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        observeCareerForRatingsPrompt()
        setContent { GoldRushApp() }
    }

    override fun onDestroy() {
        activityScope.cancel()
        super.onDestroy()
    }

    private fun observeCareerForRatingsPrompt() {
        activityScope.launch {
            var previous: CareerStats? = null
            careerRepository.stats.collect { current ->
                val prior = previous
                if (prior != null && current.games > prior.games) {
                    RatingsPrompt.consider(
                        activity = this@MainActivity,
                        didWin = current.wins > prior.wins,
                        stats = current,
                    )
                }
                previous = current
            }
        }
    }
}
