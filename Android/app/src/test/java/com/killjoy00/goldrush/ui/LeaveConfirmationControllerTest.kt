package com.killjoy00.goldrush.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LeaveConfirmationControllerTest {
    @Test
    fun requestAndDismissAreExplicit() {
        val controller = LeaveConfirmationController()

        assertFalse(controller.requested)
        controller.request()
        assertTrue(controller.requested)
        controller.dismiss()
        assertFalse(controller.requested)
    }
}
