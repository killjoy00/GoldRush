package com.killjoy00.goldrush.ads

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.killjoy00.goldrush.BuildConfig

@Composable
fun AdMobBanner(
    canRequestAds: Boolean,
    modifier: Modifier = Modifier,
) {
    if (!canRequestAds) return

    val context = LocalContext.current
    val adUnitId = if (BuildConfig.DEBUG) {
        TEST_BANNER_AD_UNIT_ID
    } else {
        BuildConfig.ADMOB_BANNER_AD_UNIT_ID
    }
    val adView = remember(context, adUnitId) {
        AdView(context).apply {
            setAdSize(AdSize.BANNER)
            this.adUnitId = adUnitId
        }
    }

    LaunchedEffect(adView) {
        adView.loadAd(AdRequest.Builder().build())
    }

    DisposableEffect(adView) {
        onDispose { adView.destroy() }
    }

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        AndroidView(
            factory = { adView },
            modifier = Modifier.width(320.dp).height(50.dp),
        )
    }
}

private const val TEST_BANNER_AD_UNIT_ID = "ca-app-pub-3940256099942544/6300978111"
