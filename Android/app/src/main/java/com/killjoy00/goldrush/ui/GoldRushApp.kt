package com.killjoy00.goldrush.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.killjoy00.goldrush.engine.GameConfig
import com.killjoy00.goldrush.engine.MiningCard
import com.killjoy00.goldrush.engine.MiningDeck
import com.killjoy00.goldrush.engine.MiningType
import com.killjoy00.goldrush.engine.SeededRng

private enum class Screen { MENU, RULES, SPLIT, HANDOFF, CHOOSE, RESULT }
private enum class Pile { A, B }

private data class SplitCard(
    val card: MiningCard,
    val pile: Pile = Pile.A,
    val faceDown: Boolean = false,
)

private data class RoundUiState(
    val cards: List<SplitCard>,
    val config: GameConfig = GameConfig(),
    val chosenPile: Pile? = null,
)

@Composable
fun GoldRushApp() {
    var screen by remember { mutableStateOf(Screen.MENU) }
    var round by remember { mutableStateOf(newRound()) }

    GoldRushTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        listOf(GoldRushColors.DirtWarm, GoldRushColors.DirtDeep),
                        radius = 1200f,
                    )
                )
                .statusBarsPadding()
                .navigationBarsPadding()
        ) {
            when (screen) {
                Screen.MENU -> MenuScreen(
                    onPassAndPlay = {
                        round = newRound(System.nanoTime().toULong())
                        screen = Screen.SPLIT
                    },
                    onRules = { screen = Screen.RULES },
                )
                Screen.RULES -> RulesScreen(onBack = { screen = Screen.MENU })
                Screen.SPLIT -> SplitScreen(
                    state = round,
                    onChange = { round = it },
                    onConfirm = { screen = Screen.HANDOFF },
                    onExit = { screen = Screen.MENU },
                )
                Screen.HANDOFF -> HandoffScreen(
                    onReady = { screen = Screen.CHOOSE },
                    onExit = { screen = Screen.MENU },
                )
                Screen.CHOOSE -> ChooseScreen(
                    state = round,
                    onChoose = {
                        round = round.copy(chosenPile = it)
                        screen = Screen.RESULT
                    },
                )
                Screen.RESULT -> ResultScreen(
                    state = round,
                    onAnother = {
                        round = newRound(System.nanoTime().toULong())
                        screen = Screen.SPLIT
                    },
                    onMenu = { screen = Screen.MENU },
                )
            }
        }
    }
}

@Composable
private fun MenuScreen(onPassAndPlay: () -> Unit, onRules: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        PortBadge()
        Spacer(Modifier.height(14.dp))
        BrandMark()
        Spacer(Modifier.height(24.dp))

        Text(
            "SCORING CARDS",
            color = GoldRushColors.Gold.copy(alpha = .82f),
            fontWeight = FontWeight.Bold,
            fontSize = 11.sp,
            letterSpacing = 1.2.sp,
        )
        Spacer(Modifier.height(7.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SetupPill("Dealt", selected = true)
            SetupPill("Drafted · next", selected = false)
        }
        Text(
            "The Android engine currently has deck, RNG and round-structure parity. Scoring-card draft and scoring are the next slice.",
            color = GoldRushColors.Parchment.copy(alpha = .55f),
            fontSize = 11.sp,
            lineHeight = 15.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp, bottom = 18.dp),
        )

        MainMenuButton(
            title = "Pass and play",
            subtitle = "Playable split-and-choose slice",
            filled = true,
            enabled = true,
            onClick = onPassAndPlay,
        )
        Spacer(Modifier.height(10.dp))
        MainMenuButton(
            title = "Play the prospector",
            subtitle = "AI follows full scoring-engine parity",
            filled = false,
            enabled = false,
            onClick = {},
        )
        Spacer(Modifier.height(10.dp))
        MainMenuButton(
            title = "Play a friend online",
            subtitle = "Cross-platform transport comes after local parity",
            filled = false,
            enabled = false,
            onClick = {},
        )

        Spacer(Modifier.height(18.dp))
        TextButton(onClick = onRules) {
            Text("HOW TO PLAY", color = GoldRushColors.Parchment.copy(alpha = .78f))
        }
        Spacer(Modifier.height(10.dp))
        HorizontalDivider(color = GoldRushColors.Gold.copy(alpha = .20f))
        Spacer(Modifier.height(10.dp))
        Text(
            "ANDROID PORT · PHASE 1",
            color = GoldRushColors.Parchment.copy(alpha = .38f),
            fontSize = 10.sp,
            letterSpacing = 1.4.sp,
        )
    }
}

@Composable
private fun PortBadge() {
    Surface(
        shape = RoundedCornerShape(99.dp),
        color = GoldRushColors.Ember.copy(alpha = .52f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .35f)),
    ) {
        Text(
            "ANDROID BUILD",
            color = GoldRushColors.GoldBright,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.2.sp,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun BrandMark() {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(128.dp), contentAlignment = Alignment.Center) {
            Surface(
                modifier = Modifier.size(width = 48.dp, height = 76.dp).rotate(-20f),
                shape = RoundedCornerShape(9.dp),
                color = GoldRushColors.DirtDeep,
                border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .55f)),
            ) {}
            Surface(
                modifier = Modifier.size(width = 48.dp, height = 76.dp).rotate(20f),
                shape = RoundedCornerShape(9.dp),
                color = GoldRushColors.DirtDeep,
                border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .55f)),
            ) {}
            Surface(
                modifier = Modifier.size(62.dp),
                shape = RoundedCornerShape(22.dp),
                color = GoldRushColors.Gold,
                border = BorderStroke(3.dp, GoldRushColors.GoldBright.copy(alpha = .55f)),
                shadowElevation = 12.dp,
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text("◆", color = GoldRushColors.GoldBright, fontSize = 31.sp)
                }
            }
        }
        Text(
            "GOLD RUSH",
            color = GoldRushColors.GoldBright,
            fontSize = 40.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 4.sp,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            DividerRule()
            Text(
                "SPLIT THE CLAIM",
                color = GoldRushColors.Parchment.copy(alpha = .76f),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 2.2.sp,
                modifier = Modifier.padding(horizontal = 9.dp),
            )
            DividerRule()
        }
    }
}

@Composable
private fun DividerRule() {
    Box(
        Modifier
            .width(52.dp)
            .height(1.dp)
            .background(GoldRushColors.Gold.copy(alpha = .45f))
    )
}

@Composable
private fun SetupPill(text: String, selected: Boolean) {
    Surface(
        shape = RoundedCornerShape(9.dp),
        color = if (selected) GoldRushColors.Gold.copy(alpha = .20f) else GoldRushColors.Dirt,
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = if (selected) .65f else .22f)),
    ) {
        Text(
            text,
            color = if (selected) GoldRushColors.GoldBright else GoldRushColors.Parchment.copy(alpha = .40f),
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 8.dp),
        )
    }
}

@Composable
private fun MainMenuButton(
    title: String,
    subtitle: String,
    filled: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val colors = if (filled) {
        ButtonDefaults.buttonColors(
            containerColor = GoldRushColors.Gold,
            contentColor = GoldRushColors.DirtDeep,
            disabledContainerColor = GoldRushColors.Gold.copy(alpha = .18f),
            disabledContentColor = GoldRushColors.Parchment.copy(alpha = .30f),
        )
    } else {
        ButtonDefaults.outlinedButtonColors(
            contentColor = GoldRushColors.Parchment,
            disabledContentColor = GoldRushColors.Parchment.copy(alpha = .30f),
        )
    }

    val content: @Composable () -> Unit = {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.Start) {
            Text(title, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Text(subtitle, fontSize = 11.sp, color = if (enabled && filled) GoldRushColors.DirtDeep.copy(alpha = .72f) else GoldRushColors.Parchment.copy(alpha = .48f))
        }
    }

    if (filled) {
        Button(
            onClick = onClick,
            enabled = enabled,
            colors = colors,
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth(),
            content = { content() },
        )
    } else {
        OutlinedButton(
            onClick = onClick,
            enabled = enabled,
            colors = colors,
            border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = if (enabled) .42f else .16f)),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth(),
            content = { content() },
        )
    }
}

@Composable
private fun SplitScreen(
    state: RoundUiState,
    onChange: (RoundUiState) -> Unit,
    onConfirm: () -> Unit,
    onExit: () -> Unit,
) {
    val requiredHidden = state.config.faceDownCount(1)
    val valid = state.cards.any { it.pile == Pile.A } &&
        state.cards.any { it.pile == Pile.B } &&
        state.cards.count { it.faceDown } == requiredHidden

    ScreenColumn {
        ScreenHeader("PLAYER 1", "Split the claim", onExit)
        Text(
            "Divide all ${state.cards.size} cards between two non-empty piles. Turn exactly $requiredHidden card face down. You still know what it is.",
            color = GoldRushColors.Parchment.copy(alpha = .68f),
            fontSize = 12.sp,
            lineHeight = 17.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
        )

        PileSection(
            title = "PILE A",
            cards = state.cards.filter { it.pile == Pile.A },
            chooserView = false,
            onMove = { card -> onChange(state.updateCard(card.id) { it.copy(pile = Pile.B) }) },
            onHide = { card -> onChange(state.updateCard(card.id) { it.copy(faceDown = !it.faceDown) }) },
        )
        Spacer(Modifier.height(10.dp))
        PileSection(
            title = "PILE B",
            cards = state.cards.filter { it.pile == Pile.B },
            chooserView = false,
            onMove = { card -> onChange(state.updateCard(card.id) { it.copy(pile = Pile.A) }) },
            onHide = { card -> onChange(state.updateCard(card.id) { it.copy(faceDown = !it.faceDown) }) },
        )

        Text(
            if (valid) "Both piles are legal." else "Need two non-empty piles and exactly $requiredHidden face-down card.",
            color = if (valid) GoldRushColors.Gold else GoldRushColors.Danger,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(vertical = 10.dp),
        )
        Button(
            onClick = onConfirm,
            enabled = valid,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = GoldRushColors.Gold, contentColor = GoldRushColors.DirtDeep),
        ) {
            Text("CONFIRM SPLIT", fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun HandoffScreen(onReady: () -> Unit, onExit: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("HAND OFF", color = GoldRushColors.Gold, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.4.sp)
        Spacer(Modifier.height(12.dp))
        Text("Player 2", color = GoldRushColors.GoldBright, fontSize = 31.sp, fontWeight = FontWeight.Black)
        Text(
            "Player 1's split is locked. Hand over the phone before continuing so the hidden card stays hidden.",
            color = GoldRushColors.Parchment.copy(alpha = .70f),
            textAlign = TextAlign.Center,
            lineHeight = 19.sp,
            modifier = Modifier.padding(vertical = 18.dp),
        )
        Button(
            onClick = onReady,
            colors = ButtonDefaults.buttonColors(containerColor = GoldRushColors.Gold, contentColor = GoldRushColors.DirtDeep),
            modifier = Modifier.fillMaxWidth(),
        ) { Text("I'M PLAYER 2 — SHOW THE PILES", fontWeight = FontWeight.Bold) }
        TextButton(onClick = onExit) { Text("Leave game", color = GoldRushColors.Parchment.copy(alpha = .45f)) }
    }
}

@Composable
private fun ChooseScreen(state: RoundUiState, onChoose: (Pile) -> Unit) {
    ScreenColumn {
        Text("PLAYER 2", color = GoldRushColors.Gold, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.4.sp)
        Text("Choose your claim", color = GoldRushColors.GoldBright, fontSize = 26.sp, fontWeight = FontWeight.Black)
        Text(
            "You take one pile. Player 1 keeps the other. Face-down cards stay unknown until you take them.",
            color = GoldRushColors.Parchment.copy(alpha = .65f),
            fontSize = 12.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(bottom = 12.dp),
        )

        ChoicePile("PILE A", state.cards.filter { it.pile == Pile.A }) { onChoose(Pile.A) }
        Spacer(Modifier.height(12.dp))
        ChoicePile("PILE B", state.cards.filter { it.pile == Pile.B }) { onChoose(Pile.B) }
    }
}

@Composable
private fun ChoicePile(title: String, cards: List<SplitCard>, onChoose: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = GoldRushColors.Dirt.copy(alpha = .88f)),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .32f)),
        shape = RoundedCornerShape(15.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(title, color = GoldRushColors.Gold, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            cards.forEach { card ->
                MiningCardRow(card = card, chooserView = true, onMove = null, onHide = null)
                Spacer(Modifier.height(6.dp))
            }
            Button(
                onClick = onChoose,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = GoldRushColors.Gold, contentColor = GoldRushColors.DirtDeep),
            ) { Text("TAKE $title", fontWeight = FontWeight.Bold) }
        }
    }
}

@Composable
private fun ResultScreen(state: RoundUiState, onAnother: () -> Unit, onMenu: () -> Unit) {
    val chosen = state.chosenPile ?: Pile.A
    val kept = if (chosen == Pile.A) Pile.B else Pile.A
    val p2 = state.cards.filter { it.pile == chosen }
    val p1 = state.cards.filter { it.pile == kept }

    ScreenColumn {
        Text("CLAIM SETTLED", color = GoldRushColors.Gold, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.4.sp)
        Text("Player 2 took Pile ${chosen.name}", color = GoldRushColors.GoldBright, fontSize = 25.sp, fontWeight = FontWeight.Black)
        Text(
            "This prototype reveals the result so both players can verify the split. Persistent hidden-information rules arrive with the full state engine.",
            color = GoldRushColors.Parchment.copy(alpha = .58f),
            fontSize = 11.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(bottom = 12.dp),
        )
        ResultPile("PLAYER 2", p2)
        Spacer(Modifier.height(10.dp))
        ResultPile("PLAYER 1", p1)
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onAnother,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = GoldRushColors.Gold, contentColor = GoldRushColors.DirtDeep),
        ) { Text("ANOTHER ROUND", fontWeight = FontWeight.Bold) }
        OutlinedButton(
            onClick = onMenu,
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .35f)),
        ) { Text("MAIN MENU", color = GoldRushColors.Parchment) }
    }
}

@Composable
private fun ResultPile(owner: String, cards: List<SplitCard>) {
    Card(
        colors = CardDefaults.cardColors(containerColor = GoldRushColors.Dirt.copy(alpha = .78f)),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .25f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text("$owner · ${cards.size} cards", color = GoldRushColors.Gold, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            Text(
                cards.joinToString("  ·  ") { it.card.type.shortName },
                color = GoldRushColors.Parchment.copy(alpha = .78f),
                fontSize = 12.sp,
                lineHeight = 18.sp,
            )
        }
    }
}

@Composable
private fun PileSection(
    title: String,
    cards: List<SplitCard>,
    chooserView: Boolean,
    onMove: (MiningCard) -> Unit,
    onHide: (MiningCard) -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = GoldRushColors.Dirt.copy(alpha = .72f)),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = if (cards.isEmpty()) .14f else .28f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text("$title · ${cards.size}", color = GoldRushColors.Gold, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            if (cards.isEmpty()) {
                Text("Move at least one card here", color = GoldRushColors.Parchment.copy(alpha = .38f), fontSize = 11.sp, modifier = Modifier.padding(vertical = 12.dp))
            } else {
                cards.forEach { card ->
                    MiningCardRow(card, chooserView, onMove, onHide)
                    Spacer(Modifier.height(6.dp))
                }
            }
        }
    }
}

@Composable
private fun MiningCardRow(
    card: SplitCard,
    chooserView: Boolean,
    onMove: ((MiningCard) -> Unit)?,
    onHide: ((MiningCard) -> Unit)?,
) {
    val hiddenFromChooser = chooserView && card.faceDown
    val tint = if (hiddenFromChooser) GoldRushColors.DirtLight else GoldRushColors.tint(card.card.type)

    Surface(
        color = tint.copy(alpha = if (hiddenFromChooser) .75f else .17f),
        shape = RoundedCornerShape(11.dp),
        border = BorderStroke(1.dp, tint.copy(alpha = .46f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                if (hiddenFromChooser) "?" else glyph(card.card.type),
                color = if (hiddenFromChooser) GoldRushColors.Gold else tint,
                fontSize = 23.sp,
                fontWeight = FontWeight.Black,
                modifier = Modifier.width(32.dp),
                textAlign = TextAlign.Center,
            )
            Column(Modifier.weight(1f)) {
                Text(
                    if (hiddenFromChooser) "Face down" else card.card.type.displayName,
                    color = GoldRushColors.Parchment,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                )
                if (card.faceDown && !hiddenFromChooser) {
                    Text("FACE DOWN · only you see this", color = GoldRushColors.Gold.copy(alpha = .78f), fontSize = 9.sp, fontWeight = FontWeight.Bold)
                }
            }
            if (onHide != null) {
                TextButton(onClick = { onHide(card.card) }) {
                    Text(if (card.faceDown) "Show" else "Hide", color = GoldRushColors.Gold, fontSize = 11.sp)
                }
            }
            if (onMove != null) {
                OutlinedButton(
                    onClick = { onMove(card.card) },
                    border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .30f)),
                ) {
                    Text(if (card.pile == Pile.A) "→ B" else "← A", color = GoldRushColors.Parchment, fontSize = 11.sp)
                }
            }
        }
    }
}

@Composable
private fun ScreenColumn(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        content = { content() },
    )
}

@Composable
private fun ScreenHeader(kicker: String, title: String, onExit: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(kicker, color = GoldRushColors.Gold, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
            Text(title, color = GoldRushColors.GoldBright, fontSize = 24.sp, fontWeight = FontWeight.Black)
        }
        TextButton(onClick = onExit) { Text("Leave", color = GoldRushColors.Parchment.copy(alpha = .46f)) }
    }
}

@Composable
private fun RulesScreen(onBack: () -> Unit) {
    ScreenColumn {
        ScreenHeader("HOW TO PLAY", "Split the claim", onBack)
        RuleSection("1 · YOUR GOAL", "Collect mining cards that pay off your six scoring cards. Once all 60 cards in play have been claimed, every scoring card pays out and the higher score wins.")
        RuleSection("2 · PLAY A ROUND", "Draw 7 cards privately. Divide every card between two non-empty piles. Turn 1 card face down. Your opponent takes one pile; you keep the other.")
        RuleSection("3 · THE MOTHERLODE", "The final 18 mining cards come out in bigger handfuls. A Motherlode draw has 9 cards and 2 face down.")
        RuleSection("4 · WHAT'S PORTED", "This first Android slice implements the deterministic deck, SplitMix64 RNG, round structure, and a privacy-safe split-and-choose handoff. Scoring cards, full game state, AI, career data, ads, purchases, and online play follow next.")
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
            Text("BACK", color = GoldRushColors.Parchment)
        }
    }
}

@Composable
private fun RuleSection(title: String, body: String) {
    Card(
        colors = CardDefaults.cardColors(containerColor = GoldRushColors.Dirt.copy(alpha = .72f)),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .20f)),
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
    ) {
        Column(Modifier.padding(14.dp)) {
            Text(title, color = GoldRushColors.Gold, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = .8.sp)
            Text(body, color = GoldRushColors.Parchment.copy(alpha = .78f), fontSize = 13.sp, lineHeight = 19.sp, modifier = Modifier.padding(top = 6.dp))
        }
    }
}

private fun newRound(seed: ULong = 0xC0FFEEUL): RoundUiState {
    val deck = MiningDeck.standardDeck().toMutableList()
    SeededRng(seed).shuffle(deck)
    return RoundUiState(cards = deck.take(7).map { SplitCard(it) })
}

private fun RoundUiState.updateCard(id: Int, transform: (SplitCard) -> SplitCard): RoundUiState =
    copy(cards = cards.map { if (it.card.id == id) transform(it) else it })

private fun glyph(type: MiningType): String = when (type) {
    MiningType.GOLD_NUGGET -> "⬡"
    MiningType.FOOLS_GOLD -> "◌"
    MiningType.GOLD_ORE -> "◆"
    MiningType.SHOVEL -> "⛏"
    MiningType.GRAVEL -> "∷"
    MiningType.PAN -> "◒"
    MiningType.QUARTZ -> "◇"
    MiningType.PACK_MULE -> "♞"
}
