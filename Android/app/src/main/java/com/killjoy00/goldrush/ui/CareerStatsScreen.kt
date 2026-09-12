package com.killjoy00.goldrush.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.killjoy00.goldrush.career.CareerFamilyRecord
import com.killjoy00.goldrush.career.CareerStats
import com.killjoy00.goldrush.engine.ScoringFamily
import java.util.Locale

@Composable
fun CareerStatsScreen(
    stats: CareerStats,
    onBack: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 18.dp, vertical = 14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    "CAREER",
                    color = GoldRushColors.Gold,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp,
                )
                Text(
                    "Career Stats",
                    color = GoldRushColors.GoldBright,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Black,
                )
            }
            TextButton(onClick = onBack) {
                Text("BACK", color = GoldRushColors.Parchment.copy(alpha = .65f))
            }
        }
        HorizontalDivider(color = GoldRushColors.Gold.copy(alpha = .18f))
        Spacer(Modifier.height(14.dp))

        if (stats.games == 0) {
            Text(
                "No completed games yet",
                color = GoldRushColors.GoldBright,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 42.dp),
            )
            Text(
                "Career stats start recording when a game reaches scoring.",
                color = GoldRushColors.Parchment.copy(alpha = .55f),
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 7.dp),
            )
            return@Column
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            CareerStatTile("Record", "${stats.wins}–${stats.losses}", Modifier.weight(1f))
            CareerStatTile("Win rate", percent(stats.winRate), Modifier.weight(1f))
        }
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            CareerStatTile("Avg score", decimal(stats.averageScore), Modifier.weight(1f))
            CareerStatTile("Avg margin", signed(stats.averageMargin), Modifier.weight(1f))
            CareerStatTile("Best", stats.displayBest.toString(), Modifier.weight(1f))
        }

        Spacer(Modifier.height(14.dp))
        CareerSection("BY FORMAT") {
            stats.modes.keys.sorted().forEach { label ->
                val record = stats.modes.getValue(label)
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            label,
                            color = GoldRushColors.Parchment,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            "${record.games} ${if (record.games == 1) "game" else "games"} · avg ${decimal(record.averageScore)}",
                            color = GoldRushColors.Parchment.copy(alpha = .5f),
                            fontSize = 10.sp,
                        )
                    }
                    Text(
                        percent(record.winRate),
                        color = GoldRushColors.GoldBright,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }

        Spacer(Modifier.height(12.dp))
        CareerSection("SCORING FAMILIES") {
            ScoringFamily.entries.forEach { family ->
                val record = stats.families[family.displayName] ?: CareerFamilyRecord()
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            family.displayName,
                            color = GoldRushColors.Parchment,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            "${record.cards} cards scored",
                            color = GoldRushColors.Parchment.copy(alpha = .5f),
                            fontSize = 10.sp,
                        )
                    }
                    Text(
                        "${decimal(record.averagePerCard)} pts/card",
                        color = GoldRushColors.Gold,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }

        Text(
            "Pass-and-play records Player 1. Solo records you. Stats stay on this device.",
            color = GoldRushColors.Parchment.copy(alpha = .45f),
            fontSize = 10.sp,
            lineHeight = 14.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 16.dp),
        )
    }
}

@Composable
private fun CareerStatTile(label: String, value: String, modifier: Modifier) {
    Surface(
        color = GoldRushColors.DirtLight.copy(alpha = .45f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .12f)),
        shape = RoundedCornerShape(11.dp),
        modifier = modifier,
    ) {
        Column(
            modifier = Modifier.padding(vertical = 11.dp, horizontal = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                value,
                color = GoldRushColors.GoldBright,
                fontSize = 20.sp,
                fontWeight = FontWeight.Black,
            )
            Text(
                label.uppercase(),
                color = GoldRushColors.Parchment.copy(alpha = .5f),
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = .6.sp,
            )
        }
    }
}

@Composable
private fun CareerSection(title: String, content: @Composable () -> Unit) {
    Surface(
        color = GoldRushColors.DirtLight.copy(alpha = .3f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .12f)),
        shape = RoundedCornerShape(13.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(
                title,
                color = GoldRushColors.Gold.copy(alpha = .8f),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp,
            )
            Spacer(Modifier.height(6.dp))
            content()
        }
    }
}

private fun percent(value: Double): String = "${kotlin.math.round(value * 100).toInt()}%"
private fun decimal(value: Double): String = String.format(Locale.US, "%.1f", value)
private fun signed(value: Double): String = String.format(Locale.US, "%+.1f", value)
