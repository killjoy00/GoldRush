package com.killjoy00.goldrush.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.killjoy00.goldrush.engine.MiningType

object GoldRushColors {
    val Dirt = Color(0xFF16120F)
    val DirtDeep = Color(0xFF0B0908)
    val DirtWarm = Color(0xFF2D2117)
    val DirtLight = Color(0xFF29221C)
    val Ember = Color(0xFF533619)
    val Gold = Color(0xFFE1AF3C)
    val GoldBright = Color(0xFFFCD87E)
    val GoldDeep = Color(0xFF8B631B)
    val Parchment = Color(0xFFEFE8D8)
    val Danger = Color(0xFFD05A44)
    val Sluice = Color(0xFF5C96AA)

    fun tint(type: MiningType): Color = when (type) {
        MiningType.GOLD_NUGGET -> GoldBright
        MiningType.FOOLS_GOLD -> Color(0xFFB89E4D)
        MiningType.GOLD_ORE -> Color(0xFFCC8547)
        MiningType.SHOVEL -> Color(0xFF8C949E)
        MiningType.GRAVEL -> Color(0xFF948778)
        MiningType.PAN -> Sluice
        MiningType.QUARTZ -> Color(0xFFB3C2D9)
        MiningType.PACK_MULE -> Color(0xFFA37359)
    }
}

private val Scheme = darkColorScheme(
    primary = GoldRushColors.Gold,
    onPrimary = GoldRushColors.DirtDeep,
    secondary = GoldRushColors.GoldBright,
    background = GoldRushColors.DirtDeep,
    onBackground = GoldRushColors.Parchment,
    surface = GoldRushColors.Dirt,
    onSurface = GoldRushColors.Parchment,
    error = GoldRushColors.Danger,
)

@Composable
fun GoldRushTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = Scheme, content = content)
}
