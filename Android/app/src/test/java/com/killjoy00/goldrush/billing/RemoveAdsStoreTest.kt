package com.killjoy00.goldrush.billing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class RemoveAdsStoreTest {
    @Test
    fun productIdMatchesShippingIosEntitlement() {
        assertEquals(
            "com.killjoy00.goldrush.removeads",
            RemoveAdsStore.PRODUCT_ID,
        )
    }

    @Test
    fun initialStateDoesNotInventAnEntitlementOrPrice() {
        val state = RemoveAdsStore.State()
        assertFalse(state.isPurchased)
        assertFalse(state.isReady)
        assertFalse(state.isWorking)
        assertNull(state.price)
        assertNull(state.failure)
    }
}
