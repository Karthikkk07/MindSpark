package com.karthik.mindspark

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fires when the daily alarm goes off. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderManager.showDaily(context)
    }
}

/** Alarms are cleared by a reboot, so the saved reminder is set again. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) ReminderManager.restore(context)
    }
}
