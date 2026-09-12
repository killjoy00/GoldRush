package com.killjoy00.goldrush.ui

import androidx.activity.compose.BackHandler
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

internal class LeaveConfirmationController {
    var requested by mutableStateOf(false)
        private set

    fun request() {
        requested = true
    }

    fun dismiss() {
        requested = false
    }
}

@Composable
internal fun LeaveConfirmationGuard(
    active: Boolean,
    controller: LeaveConfirmationController,
    onLeave: () -> Unit,
) {
    BackHandler(enabled = active) {
        controller.request()
    }

    if (!active || !controller.requested) return

    AlertDialog(
        onDismissRequest = controller::dismiss,
        title = { Text("Leave this game?") },
        text = {
            Text("Pass-and-play and solo games can't be picked up again.")
        },
        confirmButton = {
            TextButton(
                onClick = {
                    controller.dismiss()
                    onLeave()
                }
            ) {
                Text("Leave game")
            }
        },
        dismissButton = {
            TextButton(onClick = controller::dismiss) {
                Text("Keep playing")
            }
        },
    )
}
