package com.killjoy00.goldrush

import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.fetchSemanticsNodes
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodes
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.killjoy00.goldrush.ui.GoldRushApp
import java.io.File
import java.io.FileOutputStream
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Captures real Compose UI states for the Google Play phone screenshot set.
 *
 * This deliberately drives the shipping GoldRushApp instead of rendering a
 * parallel marketing-only mock. The output is pulled from the emulator by the
 * dedicated Play screenshot workflow and visually inspected before upload.
 */
@RunWith(AndroidJUnit4::class)
class StoreScreenshotTest {
    @get:Rule
    val composeRule = createComposeRule()

    private val scoringCardMatcher = SemanticsMatcher("clickable scoring card") { node ->
        val clickable = node.config.getOrNull(SemanticsActions.OnClick) != null
        val texts = node.config.getOrNull(SemanticsProperties.Text).orEmpty()
        clickable && texts.any { SCORING_CODE.matches(it.text) }
    }

    @Test
    fun capturePlayStorePhoneScreenshots() {
        composeRule.setContent { GoldRushApp() }
        waitForText("GOLD RUSH")

        capture("01-play-your-way")

        composeRule.onNodeWithText("Drafted").performClick()
        waitForText("Open 7: take 1, then 2, then 2. Keep one of the last two and burn the other.")
        composeRule.onNodeWithText("Play the prospector").performClick()
        waitForText("Draft scoring cards")
        composeRule.onNodeWithText("Draft scoring cards").performScrollTo()
        capture("02-draft-scoring-plan")

        advanceDraftAndRevealToSplit()
        waitForText("Split the claim")

        val hideButtons = composeRule.onAllNodesWithText("Hide")
        assertTrue("Expected at least one card that can be turned face down", hideButtons.fetchSemanticsNodes().isNotEmpty())
        hideButtons[0].performScrollTo().performClick()
        composeRule.onNodeWithText("Split the claim").performScrollTo()
        capture("03-split-the-claim")

        composeRule.onNodeWithText("LOCK SPLIT").performScrollTo().performClick()
        waitForText("Choose your claim")
        composeRule.onNodeWithText("Choose your claim").performScrollTo()
        capture("04-choose-a-pile")
    }

    private fun advanceDraftAndRevealToSplit() {
        repeat(20) {
            composeRule.waitForIdle()
            when {
                textExists("Split the claim") -> return
                textExists("Take two") -> {
                    clickScoringCard(0)
                    clickScoringCard(1)
                    composeRule.onNodeWithText("TAKE TWO").performScrollTo().performClick()
                }
                textExists("Last two") -> clickScoringCard(0)
                textExists("Choose your public cards") -> {
                    clickScoringCard(0)
                    clickScoringCard(1)
                    clickScoringCard(2)
                    composeRule.onNodeWithText("REVEAL 3").performScrollTo().performClick()
                }
                textExists("Draft scoring cards") -> clickScoringCard(0)
                else -> error("Unexpected game state while advancing screenshot fixture")
            }
        }
        error("Did not reach the split phase while building screenshot fixture")
    }

    private fun clickScoringCard(index: Int) {
        composeRule.waitForIdle()
        val cards = composeRule.onAllNodes(scoringCardMatcher)
        val count = cards.fetchSemanticsNodes().size
        assertTrue("Expected scoring card index $index but only found $count clickable scoring cards", count > index)
        cards[index].performScrollTo().performClick()
    }

    private fun textExists(text: String): Boolean =
        composeRule.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()

    private fun waitForText(text: String) {
        composeRule.waitUntil(timeoutMillis = 10_000) { textExists(text) }
    }

    private fun capture(name: String) {
        composeRule.waitForIdle()
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.getExternalFilesDir(null), "play-store")
        check(directory.exists() || directory.mkdirs()) { "Could not create screenshot directory $directory" }

        val output = File(directory, "$name.png")
        val bitmap = composeRule.onRoot().captureToImage().asAndroidBitmap()
        FileOutputStream(output).use { stream ->
            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                "Could not encode screenshot $output"
            }
        }
        check(output.isFile && output.length() > 0L) { "Screenshot was not written: $output" }
    }

    private companion object {
        val SCORING_CODE = Regex("^[A-Z][1-8]$")
    }
}
