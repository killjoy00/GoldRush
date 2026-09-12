package com.killjoy00.goldrush.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.killjoy00.goldrush.billing.RemoveAdsStore

@Composable
fun RemoveAdsScreen(
    state: RemoveAdsStore.State,
    onPurchase: () -> Unit,
    onRestore: () -> Unit,
    onDone: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 22.dp, vertical = 26.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "NO ADS",
            color = GoldRushColors.Gold,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.4.sp,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Remove ads",
            color = GoldRushColors.GoldBright,
            fontSize = 26.sp,
            fontWeight = FontWeight.Black,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "A one-time purchase that removes the Gold Rush banner ads for good on this Google Play account.",
            color = GoldRushColors.Parchment.copy(alpha = .75f),
            fontSize = 13.sp,
            lineHeight = 18.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 18.dp),
        )

        Spacer(Modifier.height(22.dp))

        state.failure?.let { failure ->
            Text(
                failure,
                color = GoldRushColors.Danger,
                fontSize = 12.sp,
                lineHeight = 17.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 18.dp, vertical = 8.dp),
            )
        }

        if (state.isPurchased) {
            Text(
                "Purchased — thank you",
                color = GoldRushColors.Gold,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(vertical = 12.dp),
            )
        } else {
            Button(
                onClick = onPurchase,
                enabled = state.isReady && state.price != null && !state.isWorking,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = GoldRushColors.Gold,
                    contentColor = GoldRushColors.DirtDeep,
                    disabledContainerColor = GoldRushColors.DirtLight,
                    disabledContentColor = GoldRushColors.Parchment.copy(alpha = .45f),
                ),
                shape = RoundedCornerShape(12.dp),
            ) {
                if (state.isWorking) {
                    CircularProgressIndicator(
                        modifier = Modifier.height(20.dp),
                        strokeWidth = 2.dp,
                        color = GoldRushColors.Parchment,
                    )
                } else {
                    Text(
                        state.price?.let { "Remove ads — $it" } ?: "Remove ads",
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = onRestore,
                enabled = state.isReady && !state.isWorking,
                modifier = Modifier.fillMaxWidth(),
                border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .35f)),
            ) {
                Text("Restore purchase", color = GoldRushColors.Parchment)
            }
        }

        Spacer(Modifier.weight(1f))
        TextButton(onClick = onDone) {
            Text("DONE", color = GoldRushColors.Parchment.copy(alpha = .6f))
        }
    }
}
