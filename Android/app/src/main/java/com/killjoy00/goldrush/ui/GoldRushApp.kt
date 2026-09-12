package com.killjoy00.goldrush.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.killjoy00.goldrush.ai.ProspectorAgent
import com.killjoy00.goldrush.ai.ProspectorController
import com.killjoy00.goldrush.ai.ProspectorFidelity
import com.killjoy00.goldrush.career.CareerStats
import com.killjoy00.goldrush.career.CareerStatsRecorder
import com.killjoy00.goldrush.career.CareerStatsRepository
import com.killjoy00.goldrush.engine.Action
import com.killjoy00.goldrush.engine.GameConfig
import com.killjoy00.goldrush.engine.GameState
import com.killjoy00.goldrush.engine.Phase
import com.killjoy00.goldrush.engine.PileId
import com.killjoy00.goldrush.engine.PlayerId
import com.killjoy00.goldrush.engine.PlayerView
import com.killjoy00.goldrush.engine.ScoringCard
import com.killjoy00.goldrush.engine.ScoringCardCatalog
import com.killjoy00.goldrush.engine.ScoringCardId
import com.killjoy00.goldrush.engine.VisibleCard
import com.killjoy00.goldrush.settings.SetupPreferences
import com.killjoy00.goldrush.settings.SetupPreferencesRepository
import java.util.UUID
import kotlinx.coroutines.launch

private enum class AppScreen { MENU, RULES, CARDS, CAREER, GAME }

@Composable
fun GoldRushApp() {
    val context = LocalContext.current.applicationContext
    val careerRepository = remember(context) { CareerStatsRepository(context) }
    val careerStats by careerRepository.stats.collectAsState(initial = CareerStats())
    val setupRepository = remember(context) { SetupPreferencesRepository(context) }
    val setup by setupRepository.preferences.collectAsState(initial = SetupPreferences())
    val scope = rememberCoroutineScope()

    var screen by remember { mutableStateOf(AppScreen.MENU) }
    val drafted = setup.scoringDraft
    val together = setup.simultaneousSplit
    var prospector by remember { mutableStateOf(ProspectorFidelity.RUTHLESS) }
    var game by remember { mutableStateOf<GameState?>(null) }
    var gameId by remember { mutableStateOf<String?>(null) }
    var visibleSeat by remember { mutableStateOf<PlayerId?>(null) }
    var solo by remember { mutableStateOf(false) }
    var prospectorController by remember { mutableStateOf<ProspectorController?>(null) }
    val leaveConfirmation = remember { LeaveConfirmationController() }

    fun newGameState(): GameState = GameState.newGame(
        config = GameConfig(scoringDraft = drafted, simultaneousSplit = together),
        seed = System.nanoTime().toULong(),
    )

    fun startPassAndPlay() {
        solo = false
        prospectorController = null
        gameId = UUID.randomUUID().toString()
        game = newGameState()
        visibleSeat = null
        screen = AppScreen.GAME
    }

    fun startProspector() {
        val controller = ProspectorController(
            humanSeat = PlayerId.P1,
            agent = ProspectorAgent(prospector),
        )
        solo = true
        prospectorController = controller
        gameId = UUID.randomUUID().toString()
        game = controller.start(newGameState())
        visibleSeat = PlayerId.P1
        screen = AppScreen.GAME
    }

    fun leaveGame() {
        game = null
        gameId = null
        visibleSeat = null
        solo = false
        prospectorController = null
        screen = AppScreen.MENU
    }

    fun submit(action: Action) {
        val current = game ?: return
        val seatHoldingPhone = visibleSeat
        val next = if (solo) {
            prospectorController?.submit(current, action) ?: current.apply(action)
        } else {
            current.apply(action)
        }
        if (next === current) return
        game = next

        if (next.isFinished) {
            val completed = gameId?.let { id ->
                CareerStatsRecorder.completedGame(id, next, PlayerId.P1)
            }
            if (completed != null) {
                scope.launch { careerRepository.record(completed) }
            }
        }

        visibleSeat = if (solo) {
            if (next.isFinished) null else PlayerId.P1
        } else {
            if (next.actingPlayer == seatHoldingPhone) seatHoldingPhone else null
        }
    }

    GoldRushTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(GoldRushColors.DirtWarm, GoldRushColors.DirtDeep),
                        radius = 1200f,
                    )
                )
                .statusBarsPadding()
                .navigationBarsPadding()
        ) {
            when (screen) {
                AppScreen.MENU -> MenuScreen(
                    drafted = drafted,
                    together = together,
                    prospector = prospector,
                    onDraftedChange = { enabled ->
                        scope.launch { setupRepository.setScoringDraft(enabled) }
                    },
                    onTogetherChange = { enabled ->
                        scope.launch { setupRepository.setSimultaneousSplit(enabled) }
                    },
                    onProspectorChange = { prospector = it },
                    onPassAndPlay = ::startPassAndPlay,
                    onProspector = ::startProspector,
                    onRules = { screen = AppScreen.RULES },
                    onCards = { screen = AppScreen.CARDS },
                    onCareer = { screen = AppScreen.CAREER },
                )

                AppScreen.RULES -> RulesScreen(onBack = { screen = AppScreen.MENU })
                AppScreen.CARDS -> CardCompendiumScreen(onBack = { screen = AppScreen.MENU })
                AppScreen.CAREER -> CareerStatsScreen(
                    stats = careerStats,
                    onBack = { screen = AppScreen.MENU },
                )
                AppScreen.GAME -> {
                    val state = game
                    if (state == null) {
                        screen = AppScreen.MENU
                    } else if (state.isFinished) {
                        FinalScoreScreen(
                            state = state,
                            solo = solo,
                            onRematch = {
                                if (solo) startProspector() else startPassAndPlay()
                            },
                            onMenu = ::leaveGame,
                        )
                    } else {
                        val actor = state.actingPlayer
                        if (solo) {
                            if (actor == PlayerId.P1) {
                                GameScreen(
                                    state = state,
                                    player = PlayerId.P1,
                                    onAction = ::submit,
                                    onExit = leaveConfirmation::request,
                                )
                            }
                        } else if (actor != null && visibleSeat != actor) {
                            HandoffScreen(
                                player = actor,
                                phase = state.phase,
                                round = state.round,
                                onReady = { visibleSeat = actor },
                                onExit = leaveConfirmation::request,
                            )
                        } else if (actor != null) {
                            GameScreen(
                                state = state,
                                player = actor,
                                onAction = ::submit,
                                onExit = leaveConfirmation::request,
                            )
                        }
                    }
                }
            }
        }

        LeaveConfirmationGuard(
            active = screen == AppScreen.GAME && game?.isFinished == false,
            controller = leaveConfirmation,
            onLeave = ::leaveGame,
        )
    }
}

@Composable
private fun MenuScreen(
    drafted: Boolean,
    together: Boolean,
    prospector: ProspectorFidelity,
    onDraftedChange: (Boolean) -> Unit,
    onTogetherChange: (Boolean) -> Unit,
    onProspectorChange: (ProspectorFidelity) -> Unit,
    onPassAndPlay: () -> Unit,
    onProspector: () -> Unit,
    onRules: () -> Unit,
    onCards: () -> Unit,
    onCareer: () -> Unit,
) {
    ScreenColumn {
        Spacer(Modifier.height(12.dp))
        Text(
            "GOLD RUSH",
            color = GoldRushColors.GoldBright,
            fontSize = 38.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 3.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )
        Text(
            "SPLIT THE CLAIM",
            color = GoldRushColors.Parchment.copy(alpha = .68f),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 2.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(26.dp))
        SetupChooser(
            title = "SCORING CARDS",
            left = "Dealt",
            right = "Drafted",
            rightSelected = drafted,
            onChange = onDraftedChange,
        )
        Text(
            if (drafted) {
                "Open 7: take 1, then 2, then 2. Keep one of the last two and burn the other."
            } else {
                "Six dealt at random. Three public, three secret."
            },
            color = GoldRushColors.Parchment.copy(alpha = .55f),
            fontSize = 11.sp,
            lineHeight = 15.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(vertical = 7.dp),
        )

        SetupChooser(
            title = "SPLITTING",
            left = "Take turns",
            right = "Together",
            rightSelected = together,
            onChange = onTogetherChange,
        )
        Text(
            if (together) {
                "Both split, then both choose. Four rounds; 60 mining cards total."
            } else {
                "One splits and the other chooses, then swap. Eight rounds; 60 mining cards total."
            },
            color = GoldRushColors.Parchment.copy(alpha = .55f),
            fontSize = 11.sp,
            lineHeight = 15.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(vertical = 7.dp),
        )

        ProspectorChooser(
            selected = prospector,
            onChange = onProspectorChange,
        )
        Text(
            prospectorBlurb(prospector),
            color = GoldRushColors.Parchment.copy(alpha = .55f),
            fontSize = 11.sp,
            lineHeight = 15.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(vertical = 7.dp),
        )

        Spacer(Modifier.height(14.dp))
        Button(
            onClick = onPassAndPlay,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(
                containerColor = GoldRushColors.Gold,
                contentColor = GoldRushColors.DirtDeep,
            ),
            shape = RoundedCornerShape(12.dp),
        ) {
            Column(Modifier.fillMaxWidth()) {
                Text("Pass and play", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text("Two players · one device", fontSize = 11.sp)
            }
        }

        Spacer(Modifier.height(10.dp))
        OutlinedButton(
            onClick = onProspector,
            modifier = Modifier.fillMaxWidth(),
            border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .45f)),
        ) {
            Column(Modifier.fillMaxWidth()) {
                Text("Play the prospector", fontWeight = FontWeight.Bold, color = GoldRushColors.GoldBright)
                Text("Single player · ${prospector.displayName}", fontSize = 11.sp, color = GoldRushColors.Parchment.copy(alpha = .72f))
            }
        }

        Spacer(Modifier.height(18.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
        ) {
            TextButton(onClick = onRules) { Text("HOW TO PLAY", color = GoldRushColors.Parchment) }
            TextButton(onClick = onCards) { Text("CARDS", color = GoldRushColors.Parchment) }
            TextButton(onClick = onCareer) { Text("CAREER", color = GoldRushColors.Parchment) }
        }
    }
}

@Composable
private fun ProspectorChooser(
    selected: ProspectorFidelity,
    onChange: (ProspectorFidelity) -> Unit,
) {
    Text(
        "PROSPECTOR",
        color = GoldRushColors.Gold.copy(alpha = .82f),
        fontWeight = FontWeight.Bold,
        fontSize = 10.sp,
        letterSpacing = 1.sp,
        modifier = Modifier.fillMaxWidth(),
        textAlign = TextAlign.Center,
    )
    Spacer(Modifier.height(5.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        ProspectorFidelity.entries.forEach { option ->
            SetupButton(
                text = option.displayName,
                selected = option == selected,
                modifier = Modifier.weight(1f),
            ) { onChange(option) }
        }
    }
}

private fun prospectorBlurb(fidelity: ProspectorFidelity): String = when (fidelity) {
    ProspectorFidelity.STEADY -> "Splits evenly and takes the better pile. Does not try to mislead you."
    ProspectorFidelity.CUNNING -> "Also hides the card that will cost you most to guess wrong."
    ProspectorFidelity.RUTHLESS -> "Also works out what you will do with a split before offering it."
}

@Composable
private fun SetupChooser(
    title: String,
    left: String,
    right: String,
    rightSelected: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Text(
        title,
        color = GoldRushColors.Gold.copy(alpha = .82f),
        fontWeight = FontWeight.Bold,
        fontSize = 10.sp,
        letterSpacing = 1.sp,
        modifier = Modifier.fillMaxWidth(),
        textAlign = TextAlign.Center,
    )
    Spacer(Modifier.height(5.dp))
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SetupButton(left, selected = !rightSelected, modifier = Modifier.weight(1f)) { onChange(false) }
        SetupButton(right, selected = rightSelected, modifier = Modifier.weight(1f)) { onChange(true) }
    }
}

@Composable
private fun SetupButton(
    text: String,
    selected: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    if (selected) {
        Button(
            onClick = onClick,
            modifier = modifier,
            colors = ButtonDefaults.buttonColors(
                containerColor = GoldRushColors.Gold,
                contentColor = GoldRushColors.DirtDeep,
            ),
        ) { Text(text, fontWeight = FontWeight.Bold) }
    } else {
        OutlinedButton(
            onClick = onClick,
            modifier = modifier,
            border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .35f)),
        ) { Text(text, color = GoldRushColors.Parchment) }
    }
}

@Composable
private fun HandoffScreen(
    player: PlayerId,
    phase: Phase,
    round: Int,
    onReady: () -> Unit,
    onExit: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            "HAND OFF",
            color = GoldRushColors.Gold,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.4.sp,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            player.label,
            color = GoldRushColors.GoldBright,
            fontSize = 31.sp,
            fontWeight = FontWeight.Black,
        )
        Text(
            handoffDetail(phase, round),
            color = GoldRushColors.Parchment.copy(alpha = .68f),
            textAlign = TextAlign.Center,
            lineHeight = 19.sp,
            modifier = Modifier.padding(vertical = 18.dp),
        )
        Button(
            onClick = onReady,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(
                containerColor = GoldRushColors.Gold,
                contentColor = GoldRushColors.DirtDeep,
            ),
        ) { Text("I'M ${player.label.uppercase()} — CONTINUE", fontWeight = FontWeight.Bold) }
        TextButton(onClick = onExit) {
            Text("Leave game", color = GoldRushColors.Parchment.copy(alpha = .45f))
        }
    }
}

private fun handoffDetail(phase: Phase, round: Int): String = when (phase) {
    Phase.REVEAL_SELECTION -> "Choose which three of your scoring cards to make public. Keep the screen private until you're ready."
    Phase.ADDITIONAL_REVEAL -> "Choose one more scoring card to reveal."
    Phase.DRAFT -> "Your scoring-card pack is private until you finish this draft decision."
    Phase.DRAFT_DISCARD -> "Finish this older saved scoring-card draft privately."
    Phase.SPLIT -> "Round $round: your draw is private. Divide it into two piles before handing the phone over."
    Phase.CHOOSE -> "Round $round: your opponent's split is locked. Choose a pile without seeing the buried cards."
    Phase.FINISHED -> "Scoring is ready."
}

@Composable
private fun GameScreen(
    state: GameState,
    player: PlayerId,
    onAction: (Action) -> Unit,
    onExit: () -> Unit,
) {
    val view = state.view(player)
    var showJournal by remember(player) { mutableStateOf(false) }
    var showTableau by remember(player) { mutableStateOf(false) }

    when {
        showJournal -> ClaimJournalScreen(
            rounds = state.claimJournal(player),
            onBack = { showJournal = false },
        )
        showTableau -> TableauScreen(
            view = view,
            onBack = { showTableau = false },
        )
        else -> ScreenColumn {
            GameHeader(view = view, onExit = onExit)
            when (state.phase) {
                Phase.REVEAL_SELECTION -> RevealSelectionPhase(view, onAction)
                Phase.ADDITIONAL_REVEAL -> AdditionalRevealPhase(view, onAction)
                Phase.DRAFT -> DraftPhase(view, onAction)
                Phase.DRAFT_DISCARD -> LegacyDraftDiscardPhase(view, onAction)
                Phase.SPLIT -> SplitPhase(view, onAction)
                Phase.CHOOSE -> ChoosePhase(view, onAction)
                Phase.FINISHED -> Unit
            }
            CurrentHand(view)
            LastRoundSummary(view)
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TextButton(
                    onClick = { showTableau = true },
                    modifier = Modifier.weight(1f),
                ) {
                    Text("MY CLAIM (${view.collectionCounts.total})", color = GoldRushColors.Gold)
                }
                TextButton(
                    onClick = { showJournal = true },
                    modifier = Modifier.weight(1f),
                ) {
                    Text("JOURNAL", color = GoldRushColors.Gold)
                }
            }
        }
    }
}

@Composable
private fun GameHeader(view: PlayerView, onExit: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                view.player.label.uppercase(),
                color = GoldRushColors.Gold,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp,
            )
            Text(
                "Round ${view.round} of ${view.config.roundCount}",
                color = GoldRushColors.GoldBright,
                fontSize = 20.sp,
                fontWeight = FontWeight.Black,
            )
            Text(
                "Claim ${view.collectionCounts.total} · Unseen ${view.unseenTotal}",
                color = GoldRushColors.Parchment.copy(alpha = .55f),
                fontSize = 11.sp,
            )
        }
        TextButton(onClick = onExit) {
            Text("LEAVE", color = GoldRushColors.Parchment.copy(alpha = .48f))
        }
    }
    HorizontalDivider(color = GoldRushColors.Gold.copy(alpha = .18f))
    Spacer(Modifier.height(12.dp))
}

@Composable
private fun RevealSelectionPhase(view: PlayerView, onAction: (Action) -> Unit) {
    var selected by remember(view.player, view.round) { mutableStateOf(emptySet<ScoringCardId>()) }
    PhaseTitle("Choose your public cards", "Reveal exactly ${view.config.initialRevealCount}. The rest stay secret.")
    view.hand.forEach { id ->
        SelectableScoringCard(
            card = ScoringCardCatalog[id],
            selected = id in selected,
            onClick = {
                selected = if (id in selected) selected - id
                else if (selected.size < view.config.initialRevealCount) selected + id else selected
            },
        )
    }
    Spacer(Modifier.height(8.dp))
    GoldButton(
        text = "REVEAL ${view.config.initialRevealCount}",
        enabled = selected.size == view.config.initialRevealCount,
    ) {
        onAction(Action.SelectRevealedScoringCards(view.hand.filter { it in selected }))
    }
}

@Composable
private fun AdditionalRevealPhase(view: PlayerView, onAction: (Action) -> Unit) {
    PhaseTitle("Reveal one more card", "Your final public scoring card for the second half.")
    view.hand.filter { it !in view.myRevealed }.forEach { id ->
        SelectableScoringCard(
            card = ScoringCardCatalog[id],
            selected = false,
            onClick = { onAction(Action.RevealAdditional(id)) },
        )
    }
}

@Composable
private fun DraftPhase(view: PlayerView, onAction: (Action) -> Unit) {
    val pack = view.draftPool
    var selected by remember(view.player, pack.map { it.index }) { mutableStateOf(emptySet<ScoringCardId>()) }
    val pairStep = pack.size in view.config.draftShape.pairedPackSizes

    when {
        view.config.draftShape.name == "SEVEN_PAIRED" && pack.size == 7 -> {
            PhaseTitle("Draft scoring cards", "From 7: take 1. The other 6 pass to your opponent.")
            pack.forEach { id ->
                SelectableScoringCard(ScoringCardCatalog[id], false) {
                    onAction(Action.DraftPick(id))
                }
            }
        }

        view.config.draftShape.name == "SEVEN_PAIRED" && pairStep -> {
            PhaseTitle("Take two", "From ${pack.size}: choose 2 together, then pass the rest.")
            pack.forEach { id ->
                SelectableScoringCard(
                    ScoringCardCatalog[id],
                    id in selected,
                ) {
                    selected = if (id in selected) selected - id
                    else if (selected.size < 2) selected + id else selected
                }
            }
            GoldButton("TAKE TWO", enabled = selected.size == 2) {
                val ordered = pack.filter { it in selected }
                onAction(Action.DraftTakePair(ordered[0], ordered[1]))
            }
        }

        view.config.draftShape.name == "SEVEN_PAIRED" && pack.size == 2 -> {
            PhaseTitle("Last two", "Keep one. The other is burned face up for both players to see.")
            pack.forEach { keep ->
                val discard = pack.first { it != keep }
                SelectableScoringCard(ScoringCardCatalog[keep], false) {
                    onAction(Action.DraftClose(keep, discard))
                }
            }
        }

        pack.size == GameConfig.DRAFT_OPENING_PACK_SIZE -> {
            PhaseTitle("Open the pack", "Compatibility draft: choose one keep and one public burn.")
            pack.forEach { id ->
                SelectableScoringCard(ScoringCardCatalog[id], id in selected) {
                    selected = if (id in selected) selected - id
                    else if (selected.size < 2) selected + id else selected
                }
            }
            GoldButton("KEEP FIRST · BURN SECOND", enabled = selected.size == 2) {
                val ordered = pack.filter { it in selected }
                onAction(Action.DraftOpen(ordered[0], ordered[1]))
            }
        }

        pack.size == 2 -> {
            PhaseTitle("Close the pack", "Keep one and burn one face up.")
            pack.forEach { keep ->
                val discard = pack.first { it != keep }
                SelectableScoringCard(ScoringCardCatalog[keep], false) {
                    onAction(Action.DraftClose(keep, discard))
                }
            }
        }

        else -> {
            PhaseTitle("Draft scoring cards", "Take one, then pass the pack.")
            pack.forEach { id ->
                SelectableScoringCard(ScoringCardCatalog[id], false) {
                    onAction(Action.DraftPick(id))
                }
            }
        }
    }

    if (view.draftDiscards.p1.isNotEmpty() || view.draftDiscards.p2.isNotEmpty()) {
        Text(
            "Public burns: ${publicBurns(view)}",
            color = GoldRushColors.Parchment.copy(alpha = .52f),
            fontSize = 10.sp,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}

@Composable
private fun LegacyDraftDiscardPhase(view: PlayerView, onAction: (Action) -> Unit) {
    PhaseTitle("Throw one away", "Older saved draft: keep six. Your discard is public.")
    view.hand.forEach { id ->
        SelectableScoringCard(ScoringCardCatalog[id], false) {
            onAction(Action.DraftDiscard(id))
        }
    }
}

@Composable
private fun SplitPhase(view: PlayerView, onAction: (Action) -> Unit) {
    val draw = view.currentDraw
    var pileA by remember(view.player, view.round, draw.map { it.id }) {
        mutableStateOf(draw.mapIndexedNotNull { index, card -> if (index % 2 == 0) card.id else null }.toSet())
    }
    var faceDown by remember(view.player, view.round, draw.map { it.id }) {
        mutableStateOf(emptySet<Int>())
    }
    val hiddenNeeded = view.config.faceDownCount(view.round)
    val pileB = draw.map { it.id }.filter { it !in pileA }.toSet()
    val valid = pileA.isNotEmpty() && pileB.isNotEmpty() && faceDown.size == hiddenNeeded

    PhaseTitle(
        if (view.config.isMotherlode(view.round)) "Motherlode split" else "Split the claim",
        "Divide all ${draw.size} cards into two non-empty piles. Turn exactly $hiddenNeeded ${if (hiddenNeeded == 1) "card" else "cards"} face down.",
    )

    Text("PILE A", color = GoldRushColors.Gold, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    draw.filter { it.id in pileA }.forEach { card ->
        MiningCardRow(
            card = card,
            hidden = card.id in faceDown,
            actionText = "Move to B",
            onAction = { pileA = pileA - card.id },
            onHide = {
                faceDown = toggleHidden(faceDown, card.id, hiddenNeeded)
            },
        )
    }

    Spacer(Modifier.height(10.dp))
    Text("PILE B", color = GoldRushColors.Gold, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    draw.filter { it.id in pileB }.forEach { card ->
        MiningCardRow(
            card = card,
            hidden = card.id in faceDown,
            actionText = "Move to A",
            onAction = { pileA = pileA + card.id },
            onHide = {
                faceDown = toggleHidden(faceDown, card.id, hiddenNeeded)
            },
        )
    }

    Text(
        if (valid) "Legal split · ${faceDown.size}/$hiddenNeeded buried" else "Need two non-empty piles and exactly $hiddenNeeded buried.",
        color = if (valid) GoldRushColors.Gold else GoldRushColors.Danger,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(vertical = 10.dp),
    )
    GoldButton("LOCK SPLIT", enabled = valid) {
        val ordered = draw.map { it.id }
        onAction(
            Action.Split(
                pileA = ordered.filter { it in pileA },
                pileB = ordered.filter { it !in pileA },
                faceDown = ordered.filter { it in faceDown },
            )
        )
    }
}

private fun toggleHidden(current: Set<Int>, id: Int, limit: Int): Set<Int> = when {
    id in current -> current - id
    current.size < limit -> current + id
    else -> current
}

@Composable
private fun ChoosePhase(view: PlayerView, onAction: (Action) -> Unit) {
    val piles = view.piles ?: return
    PhaseTitle(
        "Choose your claim",
        "Face-down cards stay unknown unless you take that pile. Your opponent keeps the pile you leave.",
    )

    ChoosePile("PILE A", piles.a) { onAction(Action.Choose(PileId.A)) }
    Spacer(Modifier.height(12.dp))
    ChoosePile("PILE B", piles.b) { onAction(Action.Choose(PileId.B)) }
}

@Composable
private fun ChoosePile(title: String, cards: List<VisibleCard>, onChoose: () -> Unit) {
    Surface(
        color = GoldRushColors.Dirt.copy(alpha = .82f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .26f)),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(title, color = GoldRushColors.GoldBright, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            cards.forEach { card ->
                if (card is VisibleCard.Known) {
                    Text(
                        "• ${card.type.displayName}",
                        color = GoldRushColors.tint(card.type),
                        fontSize = 13.sp,
                    )
                } else {
                    Text("• ?  Face down", color = GoldRushColors.Sluice, fontSize = 13.sp)
                }
            }
            Spacer(Modifier.height(8.dp))
            GoldButton("TAKE $title", enabled = true, onClick = onChoose)
        }
    }
}

@Composable
private fun MiningCardRow(
    card: VisibleCard,
    hidden: Boolean,
    actionText: String,
    onAction: () -> Unit,
    onHide: () -> Unit,
) {
    val type = card.type
    Surface(
        color = GoldRushColors.DirtLight.copy(alpha = .72f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .16f)),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                type?.displayName ?: "Hidden card",
                color = type?.let(GoldRushColors::tint) ?: GoldRushColors.Sluice,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = onHide) {
                Text(
                    if (hidden) "FACE DOWN" else "Hide",
                    color = if (hidden) GoldRushColors.Sluice else GoldRushColors.Parchment.copy(alpha = .62f),
                    fontSize = 10.sp,
                )
            }
            TextButton(onClick = onAction) {
                Text(actionText, color = GoldRushColors.Gold, fontSize = 10.sp)
            }
        }
    }
}

@Composable
private fun CurrentHand(view: PlayerView) {
    if (view.hand.isEmpty()) return
    Spacer(Modifier.height(18.dp))
    HorizontalDivider(color = GoldRushColors.Gold.copy(alpha = .18f))
    Spacer(Modifier.height(10.dp))
    Text("YOUR SCORING CARDS", color = GoldRushColors.Gold, fontSize = 10.sp, fontWeight = FontWeight.Bold)
    Text(
        "Public: ${view.myRevealed.joinToString { it.code }.ifBlank { "none yet" }}",
        color = GoldRushColors.Parchment.copy(alpha = .48f),
        fontSize = 10.sp,
    )
    view.hand.forEach { id -> CompactScoringCard(ScoringCardCatalog[id]) }

    if (view.opponentRevealed.isNotEmpty()) {
        Spacer(Modifier.height(8.dp))
        Text(
            "Opponent public: ${view.opponentRevealed.joinToString { it.code }}",
            color = GoldRushColors.Parchment.copy(alpha = .55f),
            fontSize = 10.sp,
        )
    }
}

@Composable
private fun LastRoundSummary(view: PlayerView) {
    if (view.lastRound.isEmpty()) return
    Spacer(Modifier.height(14.dp))
    Text("LAST CLAIM", color = GoldRushColors.Gold, fontSize = 10.sp, fontWeight = FontWeight.Bold)
    view.lastRound.forEach { split ->
        val role = if (split.mine) "You split" else "Opponent split"
        Text(
            "$role · chooser took ${split.taken.name}",
            color = GoldRushColors.Parchment.copy(alpha = .55f),
            fontSize = 10.sp,
        )
    }
}

@Composable
private fun FinalScoreScreen(
    state: GameState,
    solo: Boolean,
    onRematch: () -> Unit,
    onMenu: () -> Unit,
) {
    val p1 = state.scorecard(PlayerId.P1)
    val p2 = state.scorecard(PlayerId.P2)
    val winner = state.winner()
    val winnerText = if (solo) {
        if (winner == PlayerId.P1) "You win" else "Prospector wins"
    } else {
        "${winner.label} wins"
    }

    ScreenColumn {
        Text(
            "CLAIM CLOSED",
            color = GoldRushColors.Gold,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.4.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )
        Text(
            winnerText,
            color = GoldRushColors.GoldBright,
            fontSize = 30.sp,
            fontWeight = FontWeight.Black,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )
        Text(
            "${p1.total} — ${p2.total}",
            color = GoldRushColors.Parchment,
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )
        Text(
            "Ties: most Gold Nuggets, then fewest Fool's Gold, then Player 2.",
            color = GoldRushColors.Parchment.copy(alpha = .48f),
            fontSize = 10.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(bottom = 18.dp),
        )

        ScoreBreakdown(if (solo) "YOU" else "PLAYER 1", state.hands.p1, p1.cards.associateBy { it.id })
        Spacer(Modifier.height(14.dp))
        ScoreBreakdown(if (solo) "PROSPECTOR" else "PLAYER 2", state.hands.p2, p2.cards.associateBy { it.id })

        Spacer(Modifier.height(18.dp))
        GoldButton("REMATCH", enabled = true, onClick = onRematch)
        TextButton(onClick = onMenu, modifier = Modifier.fillMaxWidth()) {
            Text("MAIN MENU", color = GoldRushColors.Parchment.copy(alpha = .68f))
        }
    }
}

@Composable
private fun ScoreBreakdown(
    title: String,
    hand: List<ScoringCardId>,
    scores: Map<ScoringCardId, com.killjoy00.goldrush.engine.CardScore>,
) {
    Text(title, color = GoldRushColors.Gold, fontWeight = FontWeight.Bold, fontSize = 11.sp)
    hand.forEach { id ->
        val card = ScoringCardCatalog[id]
        val score = scores[id]?.points ?: 0
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Text(id.code, color = GoldRushColors.GoldBright, fontWeight = FontWeight.Bold, modifier = Modifier.width(36.dp))
            Column(Modifier.weight(1f)) {
                Text(card.name, color = GoldRushColors.Parchment, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Text(card.text, color = GoldRushColors.Parchment.copy(alpha = .48f), fontSize = 10.sp)
            }
            Text(
                if (score >= 0) "+$score" else "$score",
                color = GoldRushColors.GoldBright,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Composable
private fun RulesScreen(onBack: () -> Unit) {
    ScreenColumn {
        ScreenHeader("HOW TO PLAY", "Gold Rush · Split the Claim", onBack)
        RuleSection(
            "1 · YOUR GOAL",
            "Collect mining cards that pay off your six scoring cards. The same 60 mining cards enter play in either format. After the final claim, all six scoring cards pay and the higher score wins.",
        )
        RuleSection(
            "2 · GET SIX SCORING CARDS",
            "Dealt: six random cards each, three public and three secret. Drafted: open 7; take 1/pass 6, take 2/pass 4, take 2/pass 2, then keep 1 and burn 1 face up. Only your opening draft pick stays secret.",
        )
        RuleSection(
            "3 · PLAY A ROUND",
            "Draw privately. Split every card between two non-empty piles. In a normal round turn exactly 1 card face down. Your opponent chooses a pile; you keep the other. A chooser learns buried cards only in the pile they take.",
        )
        RuleSection(
            "4 · TWO FORMATS",
            "Together: both players split, then both choose; 4 rounds. Take Turns: one splits and the other chooses, then swap; 8 rounds. Either way each player splits four times, chooses four times, and 60 mining cards are claimed.",
        )
        RuleSection(
            "5 · SETS AND PACK MULES",
            "Ore + Shovel and Gravel + Pan form sets. A Pack Mule can replace the tool half of one set and always counts as a Tool. At scoring, Mules are assigned to the arrangement that gives that player the highest total score.",
        )
        RuleSection(
            "6 · WHAT STAYS HIDDEN",
            "Face-down cards in a pile you decline remain unknown to you for the rest of the game. They stay hidden in your opponent's claim, recaps, and the Claim Journal. The Unseen count includes those cards plus cards never dealt.",
        )
        RuleSection(
            "7 · THE MOTHERLODE",
            "The final 18 mining cards arrive in larger draws. Together: round 4 gives each player 9 cards and 2 buried. Take Turns: rounds 7 and 8 draw 9 with 2 buried. All other split rules stay the same.",
        )
        RuleSection(
            "8 · WINNING",
            "Highest final score wins. Ties go to most Gold Nuggets, then fewest Fool's Gold, then Player 2 if still tied.",
        )
        RuleSection(
            "SCORING FAMILIES",
            "Strike rewards Gold Nuggets. Dig rewards Ore + Shovel sets. Sluice rewards Gravel + Pan sets. Vein rewards Quartz. Outfit rewards Tools. Prospect rewards unusual angles such as junk, breadth, comparisons, and total volume. There are 8 cards per family, 48 total.",
        )
    }
}

@Composable
private fun CardCompendiumScreen(onBack: () -> Unit) {
    ScreenColumn {
        ScreenHeader("SCORING CARDS", "All 48 current cards", onBack)
        ScoringCardCatalog.all.forEach { card -> CompactScoringCard(card) }
    }
}

@Composable
private fun RuleSection(title: String, body: String) {
    Surface(
        color = GoldRushColors.DirtLight.copy(alpha = .55f),
        border = BorderStroke(1.dp, GoldRushColors.Gold.copy(alpha = .15f)),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(title, color = GoldRushColors.GoldBright, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text(body, color = GoldRushColors.Parchment.copy(alpha = .70f), fontSize = 12.sp, lineHeight = 17.sp)
        }
    }
}

@Composable
private fun PhaseTitle(title: String, detail: String) {
    Text(title, color = GoldRushColors.GoldBright, fontSize = 21.sp, fontWeight = FontWeight.Black)
    Text(
        detail,
        color = GoldRushColors.Parchment.copy(alpha = .64f),
        fontSize = 12.sp,
        lineHeight = 17.sp,
        modifier = Modifier.padding(bottom = 10.dp),
    )
}

@Composable
private fun SelectableScoringCard(card: ScoringCard, selected: Boolean, onClick: () -> Unit) {
    Surface(
        color = if (selected) GoldRushColors.Ember.copy(alpha = .9f) else GoldRushColors.Dirt.copy(alpha = .8f),
        border = BorderStroke(
            1.dp,
            GoldRushColors.Gold.copy(alpha = if (selected) .8f else .22f),
        ),
        shape = RoundedCornerShape(11.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .clickable(onClick = onClick),
    ) {
        Row(Modifier.padding(11.dp), verticalAlignment = Alignment.Top) {
            Text(
                card.id.code,
                color = GoldRushColors.GoldBright,
                fontWeight = FontWeight.Black,
                modifier = Modifier.width(38.dp),
            )
            Column(Modifier.weight(1f)) {
                Text(card.name, color = GoldRushColors.Parchment, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                Text(card.text, color = GoldRushColors.Parchment.copy(alpha = .58f), fontSize = 11.sp, lineHeight = 15.sp)
            }
            if (selected) Text("✓", color = GoldRushColors.GoldBright, fontWeight = FontWeight.Black)
        }
    }
}

@Composable
private fun CompactScoringCard(card: ScoringCard) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            card.id.code,
            color = GoldRushColors.GoldBright,
            fontWeight = FontWeight.Black,
            fontSize = 11.sp,
            modifier = Modifier.width(34.dp),
        )
        Column(Modifier.weight(1f)) {
            Text(card.name, color = GoldRushColors.Parchment, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
            Text(card.text, color = GoldRushColors.Parchment.copy(alpha = .47f), fontSize = 9.sp, lineHeight = 12.sp)
        }
    }
}

@Composable
private fun ScreenColumn(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 18.dp, vertical = 14.dp),
    ) {
        content()
    }
}

@Composable
private fun ScreenHeader(kicker: String, title: String, onBack: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(kicker, color = GoldRushColors.Gold, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            Text(title, color = GoldRushColors.GoldBright, fontSize = 20.sp, fontWeight = FontWeight.Black)
        }
        TextButton(onClick = onBack) { Text("BACK", color = GoldRushColors.Parchment.copy(alpha = .65f)) }
    }
    HorizontalDivider(color = GoldRushColors.Gold.copy(alpha = .18f))
    Spacer(Modifier.height(10.dp))
}

@Composable
private fun GoldButton(text: String, enabled: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(
            containerColor = GoldRushColors.Gold,
            contentColor = GoldRushColors.DirtDeep,
            disabledContainerColor = GoldRushColors.Gold.copy(alpha = .18f),
            disabledContentColor = GoldRushColors.Parchment.copy(alpha = .28f),
        ),
        shape = RoundedCornerShape(10.dp),
    ) {
        Text(text, fontWeight = FontWeight.Bold)
    }
}

private fun publicBurns(view: PlayerView): String {
    val burns = (view.draftDiscards.p1 + view.draftDiscards.p2).sorted()
    return burns.joinToString { it.code }.ifBlank { "none" }
}

private val PlayerId.label: String
    get() = if (this == PlayerId.P1) "Player 1" else "Player 2"
