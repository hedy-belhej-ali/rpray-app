package com.rafel.rafel

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

/**
 * Schedules one-shot full-adhan alarms with AlarmManager. Exact delivery needs
 * the user-granted SCHEDULE_EXACT_ALARM permission on Android 12+; without it
 * the alarm falls back to an inexact while-idle alarm rather than being lost.
 */
object AdhanScheduler {
    const val ACTION_FIRE = "com.rafel.rafel.action.ADHAN_FIRE"
    const val EXTRA_ID = "rafel_alarm_id"

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return manager.canScheduleExactAlarms()
    }

    fun scheduleAll(context: Context, alarms: List<AdhanAlarm>) {
        cancelAll(context)
        val now = System.currentTimeMillis()
        val future = alarms
            .filter { it.triggerAtMillis > now }
            .distinctBy { it.id }
        AdhanStore.save(context, future)
        for (alarm in future) {
            schedule(context, alarm)
        }
    }

    fun rescheduleStored(context: Context) {
        val now = System.currentTimeMillis()
        val future = AdhanStore.load(context)
            .filter { it.triggerAtMillis > now }
            .distinctBy { it.id }
        AdhanStore.save(context, future)
        for (alarm in future) {
            schedule(context, alarm)
        }
    }

    fun cancelAll(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (alarm in AdhanStore.load(context)) {
            manager.cancel(pendingIntent(context, alarm.id))
        }
        AdhanStore.clear(context)
    }

    fun remove(context: Context, id: Int) {
        AdhanStore.save(context, AdhanStore.load(context).filterNot { it.id == id })
    }

    private fun schedule(context: Context, alarm: AdhanAlarm) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context, alarm.id)
        try {
            if (canScheduleExact(context)) {
                manager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    alarm.triggerAtMillis,
                    pending,
                )
            } else {
                manager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    alarm.triggerAtMillis,
                    pending,
                )
            }
        } catch (_: SecurityException) {
            // The permission can be revoked between the check and the call.
            manager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                alarm.triggerAtMillis,
                pending,
            )
        }
    }

    private fun pendingIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, AdhanReceiver::class.java).apply {
            action = ACTION_FIRE
            data = Uri.parse("rafel://adhan/$id")
            putExtra(EXTRA_ID, id)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
