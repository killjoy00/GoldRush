package com.killjoy00.goldrush.ads

import android.app.Activity
import android.content.Context
import com.google.android.gms.ads.MobileAds
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Runs Google's UMP consent flow before Mobile Ads is initialized or any ad is
 * requested. Gold Rush has no first-party consent database; UMP persists the
 * applicable privacy choice on-device and exposes whether ads may be requested.
 */
class AdsConsentManager(context: Context) {
    data class State(
        val canRequestAds: Boolean = false,
        val privacyOptionsRequired: Boolean = false,
        val isReady: Boolean = false,
        val mobileAdsReady: Boolean = false,
    )

    private val appContext = context.applicationContext
    private val consentInformation = UserMessagingPlatform.getConsentInformation(appContext)
    private val mobileAdsInitialized = AtomicBoolean(false)
    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    fun gatherConsent(activity: Activity) {
        val params = ConsentRequestParameters.Builder().build()
        consentInformation.requestConsentInfoUpdate(
            activity,
            params,
            {
                updateState()
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) {
                    updateState(isReady = true)
                    initializeMobileAdsIfAllowed()
                }
            },
            {
                // UMP may still have a valid prior-session choice even when the
                // refresh request fails, so respect canRequestAds() here.
                updateState(isReady = true)
                initializeMobileAdsIfAllowed()
            },
        )
    }

    fun showPrivacyOptions(activity: Activity) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) {
            updateState(isReady = true)
            initializeMobileAdsIfAllowed()
        }
    }

    private fun updateState(isReady: Boolean = _state.value.isReady) {
        _state.value = _state.value.copy(
            canRequestAds = consentInformation.canRequestAds(),
            privacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus ==
                ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED,
            isReady = isReady,
        )
    }

    private fun initializeMobileAdsIfAllowed() {
        if (!_state.value.canRequestAds) return
        if (!mobileAdsInitialized.compareAndSet(false, true)) return
        Thread {
            MobileAds.initialize(appContext) {
                _state.update { it.copy(mobileAdsReady = true) }
            }
        }.start()
    }
}
