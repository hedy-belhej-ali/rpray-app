package com.rafel.rafel

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restores native adhan alarms after a reboot, package replacement, or a
 * manual clock change. Past alarms are dropped rather than fired late.
 */
class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_TIME_CHANGED,
            -> AdhanScheduler.rescheduleStored(context)
        }
    }
}
