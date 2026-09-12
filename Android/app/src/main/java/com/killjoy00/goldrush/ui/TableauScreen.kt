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
import com.killjoy00.goldrush.engine.MiningCounts
import com.killjoy00.goldrush.engine.MiningType
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.PlayerView
import com.killjoy00.goldrush.engine.ScoringCardCatalog
import com.killjoy00.goldrush.engine.ScoringCardId

@Composable
fun TableauScreen(
    view: PlayerView,
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
                    "TABLEAU",
                    color = GoldRushColors.Gold,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp,
                )
                Text(
                    "My Claim",
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

        CountsStrip(
            title = "YOUR CLAIM — ${view.collectionCounts.total} CARDS",
            counts = view.collectionCounts,
            emphasized = true,
        )
        Spacer(Modifier.height(12.dp))

        MiningType.entries.forEach { type ->
            val count = view.collectionCounts[type]
            if (count > 0) {
                MiningTypeGroup(type, count)
                Spacer(Modifier.height(10.dp))
            }
        }

        HorizontalDivider(color = GoldRushColors.Gold.copy(alpha = .3f))
        Spacer(Modifier.height(12.dp))

        Text(
            "OPPONENT'S CLAIM — ${view.opponentCollection.size} CARDS",
            color = GoldRushColors.Gold.copy(alpha = .8f),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = .6.sp,
        )
        Spacer(Modifier.height(6.dp))
        CountsStrip(
            title = "IDENTIFIED BY YOU",
            counts = view.opponentKnownCounts,
            emphasized = false,
        )
        if (view.opponentHiddenCount > 0) {
            Text(
                "${view.opponentHiddenCount} ${if (view.opponentHiddenCount == 1) "card" else "cards"} you never saw",
                color = GoldRushColors.Sluice,
                fontSize = 11.sp,
                modifier = Modifier.padding(top = 7.dp),
            )
        }

        Spacer(Modifier.height(16.dp))
        Text(
            "YOUR SCORING CARDS",
            color = GoldRushColors.Gold.copy(alpha = .8f),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = .6.sp,
        )
        Spacer(Modifier.height(5.dp))
        view.hand.forEach { id ->
            TableauScoringCard(
                id = id,
                public = id in view.myRevealed,
            )
        }
        Text(
            "Dimmed cards are secret. All six score.",
            color = GoldRushColors.Parchment.copy(alpha = .5f),
            fontSize = 10.sp,
            modifier = Modifier.padding(top = 4.dp),
        )

        if (view.draftDiscards.p1.isNotEmpty() || view.draftDiscards.p2.isNotEmpty()) {
            Spacer(Modifier.height(14.dp))
            HorizontalDivider(color = GoldRushColors.Gold.copy(alpha = .3f))
            Spacer(Modifier.height(12.dp))
            Text(
                "FACE-UP DRAFT BURNS",
                color = GoldRushColors.Gold.copy(alpha = .8f),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = .6.sp,
            )
            Spacer(Modifier.height(6.dp))
            PlayerId.entries.forEach { player ->
                val burns = view.draftDiscards[player]
                if (burns.isNotEmpty()) {
                    Text(
                        if (player == view.player) "YOU BURNED" else "${player.tableauLabel.uppercase()} BURNED",
                        color = GoldRushColors.Parchment.copy(alpha = .5f),
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                    burns.forEach { id -> TableauScoringCard(id, public = true) }
                }
            }
        }

        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun CountsStrip(
    title: String,
    counts: MiningCounts,
    emphasized: Boolean,
) {
    Surface(
        color = GoldRushColors.DirtLight.copy(alpha = if (emphasized) .5f else .3f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = if (emphasized) .2f else .1f)),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(10.dp)) {
            Text(
                title,
                color = GoldRushColors.Gold.copy(alpha = .82f),
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = .6.sp,
            )
            Spacer(Modifier.height(7.dp))
            MiningType.entries.chunked(4).forEach { types ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    types.forEach { type ->
                        val count = counts[type]
                        Surface(
                            color = GoldRushColors.Dirt.copy(alpha = .65f),
                            border = BorderStroke(1.dp, GoldRushColors.tint(type).copy(alpha = .28f)),
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.weight(1f),
                        ) {
                            Column(
                                modifier = Modifier.padding(horizontal = 3.dp, vertical = 6.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                            ) {
                                Text(
                                    type.shortName,
                                    color = GoldRushColors.tint(type),
                                    fontSize = 8.sp,
                                    maxLines = 1,
                                )
                                Text(
                                    count.toString(),
                                    color = if (count > 0) GoldRushColors.GoldBright else GoldRushColors.Parchment.copy(alpha = .28f),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Black,
                                )
                            }
                        }
                    }
                }
                Spacer(Modifier.height(5.dp))
            }
        }
    }
}

@Composable
private fun MiningTypeGroup(type: MiningType, count: Int) {
    Text(
        "${type.displayName}  ×$count",
        color = GoldRushColors.Parchment,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
    )
    Spacer(Modifier.height(5.dp))
    repeat(count.chunkedRows()) { row ->
        val from = row * 6
        val inRow = minOf(6, count - from)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            repeat(inRow) {
                Surface(
                    color = GoldRushColors.Dirt.copy(alpha = .82f),
                    border = BorderStroke(1.dp, GoldRushColors.tint(type).copy(alpha = .4f)),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(
                        type.shortName,
                        color = GoldRushColors.tint(type),
                        textAlign = TextAlign.Center,
                        fontSize = 8.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        modifier = Modifier.padding(horizontal = 2.dp, vertical = 7.dp),
                    )
                }
            }
            repeat(6 - inRow) { Spacer(Modifier.weight(1f)) }
        }
        Spacer(Modifier.height(4.dp))
    }
}

@Composable
private fun TableauScoringCard(id: ScoringCardId, public: Boolean) {
    val card = ScoringCardCatalog[id]
    Surface(
        color = GoldRushColors.Dirt.copy(alpha = if (public) .78f else .42f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = if (public) .22f else .10f)),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
    ) {
        Row(
            modifier = Modifier.padding(10.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                id.code,
                color = GoldRushColors.GoldBright.copy(alpha = if (public) 1f else .58f),
                fontSize = 11.sp,
                fontWeight = FontWeight.Black,
                modifier = Modifier.padding(end = 9.dp),
            )
            Column(Modifier.weight(1f)) {
                Text(
                    card.name,
                    color = GoldRushColors.Parchment.copy(alpha = if (public) .95f else .55f),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    card.text,
                    color = GoldRushColors.Parchment.copy(alpha = if (public) .48f else .30f),
                    fontSize = 9.sp,
                    lineHeight = 12.sp,
                )
            }
            Text(
                if (public) "PUBLIC" else "SECRET",
                color = if (public) GoldRushColors.Gold else GoldRushColors.Sluice.copy(alpha = .7f),
                fontSize = 8.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

private fun Int.chunkedRows(): Int = if (this <= 0) 0 else (this + 5) / 6

private val PlayerId.tableauLabel: String
    get() = if (this == PlayerId.P1) "Player 1" else "Player 2"
