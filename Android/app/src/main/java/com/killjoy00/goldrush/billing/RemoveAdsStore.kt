package com.killjoy00.goldrush.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Android counterpart to iOS RemoveAdsStore.
 *
 * Ownership is rebuilt from Google Play every time billing connects rather than
 * cached in local preferences. A refund/revocation therefore removes the local
 * entitlement the next time Play reports the active purchases.
 */
class RemoveAdsStore(context: Context) : PurchasesUpdatedListener {
    data class State(
        val isPurchased: Boolean = false,
        val price: String? = null,
        val isReady: Boolean = false,
        val isWorking: Boolean = false,
        val failure: String? = null,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    private var productDetails: ProductDetails? = null
    private var started = false

    private val billingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener(this)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder()
                .enableOneTimeProducts()
                .build()
        )
        .enableAutoServiceReconnection()
        .build()

    fun start() {
        if (started) return
        started = true
        _state.value = _state.value.copy(isWorking = true, failure = null)
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    _state.value = _state.value.copy(
                        isWorking = false,
                        failure = billingFailure(result),
                    )
                    return
                }
                _state.value = _state.value.copy(isReady = true)
                refreshEntitlement()
                loadProduct()
            }

            override fun onBillingServiceDisconnected() {
                _state.value = _state.value.copy(isReady = false)
                // Automatic service reconnection is enabled. The next BillingClient
                // operation will reconnect without creating a second client.
            }
        })
    }

    fun close() {
        if (billingClient.isReady) billingClient.endConnection()
        started = false
    }

    fun refreshEntitlement(onComplete: (() -> Unit)? = null) {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()
        billingClient.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                val matching = purchases.filter { PRODUCT_ID in it.products }
                matching.forEach(::processPurchase)
                val owned = matching.any {
                    it.purchaseState == Purchase.PurchaseState.PURCHASED
                }
                _state.value = _state.value.copy(
                    isPurchased = owned,
                    isWorking = false,
                    failure = null,
                )
            } else {
                _state.value = _state.value.copy(
                    isWorking = false,
                    failure = billingFailure(result),
                )
            }
            onComplete?.invoke()
        }
    }

    fun restore() {
        if (_state.value.isWorking) return
        _state.value = _state.value.copy(isWorking = true, failure = null)
        refreshEntitlement {
            if (!_state.value.isPurchased && _state.value.failure == null) {
                _state.value = _state.value.copy(
                    failure = "No previous purchase found on this Google Play account."
                )
            }
        }
    }

    fun purchase(activity: Activity) {
        val product = productDetails ?: run {
            _state.value = _state.value.copy(
                failure = "This purchase isn't available right now."
            )
            return
        }
        if (_state.value.isWorking || _state.value.isPurchased) return

        val productParamsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(product)

        // Billing Library 9 supports multiple one-time purchase offers. Gold Rush
        // currently expects one permanent purchase option; if Play supplies an
        // explicit eligible offer, pass its token through to the billing flow.
        product.oneTimePurchaseOfferDetailsList
            ?.firstOrNull()
            ?.offerToken
            ?.takeIf { it.isNotBlank() }
            ?.let(productParamsBuilder::setOfferToken)

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParamsBuilder.build()))
            .build()

        _state.value = _state.value.copy(isWorking = true, failure = null)
        val result = billingClient.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            _state.value = _state.value.copy(
                isWorking = false,
                failure = billingFailure(result),
            )
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                val matching = purchases.orEmpty().filter { PRODUCT_ID in it.products }
                matching.forEach(::processPurchase)
                when {
                    matching.any { it.purchaseState == Purchase.PurchaseState.PURCHASED } -> {
                        _state.value = _state.value.copy(
                            isPurchased = true,
                            isWorking = false,
                            failure = null,
                        )
                    }
                    matching.any { it.purchaseState == Purchase.PurchaseState.PENDING } -> {
                        _state.value = _state.value.copy(
                            isWorking = false,
                            failure = "Waiting for payment approval. Ads will be removed after Google Play completes the purchase.",
                        )
                    }
                    else -> _state.value = _state.value.copy(isWorking = false)
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                _state.value = _state.value.copy(isWorking = false, failure = null)
            }
            else -> {
                _state.value = _state.value.copy(
                    isWorking = false,
                    failure = billingFailure(result),
                )
            }
        }
    }

    private fun loadProduct() {
        val product = QueryProductDetailsParams.Product.newBuilder()
            .setProductId(PRODUCT_ID)
            .setProductType(BillingClient.ProductType.INAPP)
            .build()
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(listOf(product))
            .build()

        billingClient.queryProductDetailsAsync(params) { result, detailsResult ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                productDetails = detailsResult.productDetailsList.firstOrNull {
                    it.productId == PRODUCT_ID
                }
                val details = productDetails
                val price = details?.oneTimePurchaseOfferDetailsList
                    ?.firstOrNull()
                    ?.formattedPrice
                    ?: details?.oneTimePurchaseOfferDetails?.formattedPrice
                _state.value = _state.value.copy(
                    price = price,
                    failure = if (details == null && !_state.value.isPurchased) {
                        "This purchase isn't available right now."
                    } else {
                        _state.value.failure
                    },
                )
            } else if (!_state.value.isPurchased) {
                _state.value = _state.value.copy(failure = billingFailure(result))
            }
        }
    }

    private fun processPurchase(purchase: Purchase) {
        if (PRODUCT_ID !in purchase.products) return
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return
        if (purchase.isAcknowledged) return

        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        billingClient.acknowledgePurchase(params) { result ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                _state.value = _state.value.copy(failure = billingFailure(result))
            }
        }
    }

    private fun billingFailure(result: BillingResult): String =
        result.debugMessage.takeIf { it.isNotBlank() }
            ?: "Google Play billing is unavailable right now."

    companion object {
        /** Keep aligned with the non-consumable created in the Play Console. */
        const val PRODUCT_ID = "com.killjoy00.goldrush.removeads"
    }
}
