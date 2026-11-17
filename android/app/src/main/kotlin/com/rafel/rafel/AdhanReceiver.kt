package com.rafel.rafel

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AdhanScheduler.ACTION_FIRE) return
        val id = intent.getIntExtra(AdhanScheduler.EXTRA_ID, Int.MIN_VALUE)
        if (id == Int.MIN_VALUE) return
        val alarm = AdhanStore.load(context).firstOrNull { it.id == id } ?: return
        AdhanScheduler.remove(context, id)
        AdhanService.start(context, alarm)
    }
}
