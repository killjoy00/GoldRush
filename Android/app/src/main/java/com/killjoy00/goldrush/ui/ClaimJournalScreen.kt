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
import com.killjoy00.goldrush.engine.ClaimJournalRound
import com.killjoy00.goldrush.engine.ClaimJournalSplit
import com.killjoy00.goldrush.engine.PileId
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.VisibleCard

data class JournalPilePresentation(
    val label: String,
    val wentToMe: Boolean,
    val cards: List<VisibleCard>,
)

internal fun journalPilePresentation(
    split: ClaimJournalSplit,
    pile: PileId,
): JournalPilePresentation {
    val taken = pile == split.taken
    val owner = if (taken) split.splitter.opponent else split.splitter
    val wentToMe = if (split.mine) {
        owner == split.splitter
    } else {
        owner == split.splitter.opponent
    }
    val verb = if (taken) "took" else "kept"
    val label = if (wentToMe) "You $verb" else "${owner.journalLabel} $verb"
    return JournalPilePresentation(label, wentToMe, split.cards(pile))
}

@Composable
fun ClaimJournalScreen(
    rounds: List<ClaimJournalRound>,
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
                    "HISTORY",
                    color = GoldRushColors.Gold,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp,
                )
                Text(
                    "Claim Journal",
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

        if (rounds.isEmpty()) {
            Text(
                "No claims yet",
                color = GoldRushColors.GoldBright,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 42.dp),
            )
            Text(
                "Completed rounds will appear here.",
                color = GoldRushColors.Parchment.copy(alpha = .55f),
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 7.dp),
            )
        } else {
            rounds.asReversed().forEach { round ->
                JournalRoundCard(round)
                Spacer(Modifier.height(12.dp))
            }
        }
    }
}

@Composable
private fun JournalRoundCard(round: ClaimJournalRound) {
    Surface(
        color = GoldRushColors.DirtLight.copy(alpha = .38f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .12f)),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(13.dp)) {
            Text(
                "ROUND ${round.round}",
                color = GoldRushColors.Gold.copy(alpha = .85f),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.2.sp,
            )
            Spacer(Modifier.height(8.dp))

            round.splits.forEachIndexed { index, split ->
                Text(
                    if (split.mine) "You split" else "${split.splitter.journalLabel} split",
                    color = GoldRushColors.Parchment.copy(alpha = .85f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(6.dp))
                JournalPileRow(journalPilePresentation(split, split.taken))
                Spacer(Modifier.height(7.dp))
                JournalPileRow(journalPilePresentation(split, split.kept))

                if (index != round.splits.lastIndex) {
                    Spacer(Modifier.height(9.dp))
                    HorizontalDivider(color = GoldRushColors.Gold.copy(alpha = .12f))
                    Spacer(Modifier.height(9.dp))
                }
            }
        }
    }
}

@Composable
private fun JournalPileRow(presentation: JournalPilePresentation) {
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (presentation.wentToMe) "●" else "○",
                color = if (presentation.wentToMe) GoldRushColors.Gold else GoldRushColors.Parchment.copy(alpha = .35f),
                fontSize = 10.sp,
            )
            Text(
                presentation.label,
                color = if (presentation.wentToMe) GoldRushColors.GoldBright else GoldRushColors.Parchment.copy(alpha = .6f),
                fontSize = 12.sp,
                fontWeight = if (presentation.wentToMe) FontWeight.SemiBold else FontWeight.Normal,
                modifier = Modifier.padding(start = 6.dp),
            )
            Text(
                " · ${presentation.cards.size} ${if (presentation.cards.size == 1) "card" else "cards"}",
                color = GoldRushColors.Parchment.copy(alpha = .4f),
                fontSize = 11.sp,
            )
        }
        Spacer(Modifier.height(5.dp))

        presentation.cards.chunked(4).forEach { rowCards ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                rowCards.forEach { card ->
                    JournalCardChip(card, presentation.wentToMe, Modifier.weight(1f))
                }
                repeat(4 - rowCards.size) { Spacer(Modifier.weight(1f)) }
            }
            Spacer(Modifier.height(4.dp))
        }
    }
}

@Composable
private fun JournalCardChip(
    card: VisibleCard,
    emphasized: Boolean,
    modifier: Modifier,
) {
    val type = card.type
    Surface(
        color = GoldRushColors.Dirt.copy(alpha = if (emphasized) .9f else .62f),
        border = BorderStroke(
            1.dp,
            (type?.let(GoldRushColors::tint) ?: GoldRushColors.Sluice).copy(
                alpha = if (emphasized) .45f else .24f
            ),
        ),
        shape = RoundedCornerShape(8.dp),
        modifier = modifier,
    ) {
        Text(
            text = type?.shortName ?: "?",
            color = type?.let(GoldRushColors::tint) ?: GoldRushColors.Sluice,
            fontSize = 9.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            maxLines = 1,
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp),
        )
    }
}

private val PlayerId.journalLabel: String
    get() = if (this == PlayerId.P1) "Player 1" else "Player 2"
