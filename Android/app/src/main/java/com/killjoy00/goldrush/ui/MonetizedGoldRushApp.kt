package com.killjoy00.goldrush.ui

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.killjoy00.goldrush.BuildConfig
import com.killjoy00.goldrush.ads.AdMobBanner
import com.killjoy00.goldrush.ads.AdsConsentManager
import com.killjoy00.goldrush.billing.RemoveAdsStore
import com.killjoy00.goldrush.session.ActiveGameSessionRepository

private const val PRIVACY_POLICY_URL = "https://killjoy00.github.io/GoldRush/privacy.html"

/**
 * Android-only shell around the game UI. Monetization stays outside the game
 * reducer and PlayerView, and the footer disappears while a game is active.
 */
@Composable
fun MonetizedGoldRushApp(adsConsentManager: AdsConsentManager) {
    val localContext = LocalContext.current
    val activity = localContext as? Activity
    val context = localContext.applicationContext
    val removeAdsStore = remember(context) { RemoveAdsStore(context) }
    val removeAdsState by removeAdsStore.state.collectAsState()
    val adsConsentState by adsConsentManager.state.collectAsState()
    val sessionRepository = remember(context) { ActiveGameSessionRepository(context) }
    val activeSession by sessionRepository.encoded.collectAsState(initial = null)
    var showRemoveAds by rememberSaveable { mutableStateOf(false) }

    DisposableEffect(removeAdsStore) {
        removeAdsStore.start()
        onDispose { removeAdsStore.close() }
    }

    val canShowAds = adsConsentState.canRequestAds &&
        adsConsentState.mobileAdsReady &&
        !removeAdsState.isPurchased &&
        (BuildConfig.DEBUG || removeAdsState.isEntitlementResolved)
    val canShowFooter = activeSession == null && !showRemoveAds

    GoldRushTheme {
        Surface(modifier = Modifier.fillMaxSize(), color = GoldRushColors.DirtDeep) {
            if (showRemoveAds) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(GoldRushColors.DirtDeep)
                        .statusBarsPadding()
                        .navigationBarsPadding()
                ) {
                    RemoveAdsScreen(
                        state = removeAdsState,
                        onPurchase = { activity?.let(removeAdsStore::purchase) },
                        onRestore = removeAdsStore::restore,
                        onDone = { showRemoveAds = false },
                    )
                }
            } else {
                Column(modifier = Modifier.fillMaxSize()) {
                    Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                        GoldRushApp()
                    }

                    if (canShowFooter) {
                        if (canShowAds) {
                            AdMobBanner(
                                canRequestAds = true,
                                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                            )
                        }

                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .navigationBarsPadding(),
                            horizontalArrangement = Arrangement.Center,
                        ) {
                            if (!removeAdsState.isPurchased && removeAdsState.price != null) {
                                TextButton(onClick = { showRemoveAds = true }) {
                                    Text(
                                        "REMOVE ADS",
                                        color = GoldRushColors.Parchment.copy(alpha = .72f),
                                    )
                                }
                            }
                            TextButton(
                                onClick = {
                                    activity?.startActivity(
                                        Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY_URL))
                                    )
                                }
                            ) {
                                Text(
                                    "PRIVACY POLICY",
                                    color = GoldRushColors.Parchment.copy(alpha = .72f),
                                )
                            }
                            if (adsConsentState.privacyOptionsRequired) {
                                TextButton(
                                    onClick = { activity?.let(adsConsentManager::showPrivacyOptions) }
                                ) {
                                    Text(
                                        "PRIVACY CHOICES",
                                        color = GoldRushColors.Parchment.copy(alpha = .72f),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
