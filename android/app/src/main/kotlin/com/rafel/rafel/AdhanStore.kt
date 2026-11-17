package com.rafel.rafel

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class AdhanAlarm(
    val id: Int,
    val triggerAtMillis: Long,
    val prayer: String,
    val title: String,
    val body: String,
)

/**
 * Persists the native adhan alarms so they can be restored after a reboot or
 * an app update. Flutter local notifications keeps its own separate schedule.
 */
object AdhanStore {
    private const val PREFS = "rafel_native_adhan"
    private const val KEY = "alarms"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun load(context: Context): List<AdhanAlarm> {
        val raw = prefs(context).getString(KEY, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val id = item.optInt("id", Int.MIN_VALUE)
                    val trigger = item.optLong("triggerAtMillis", 0L)
                    if (id == Int.MIN_VALUE || trigger <= 0L) continue
                    add(
                        AdhanAlarm(
                            id = id,
                            triggerAtMillis = trigger,
                            prayer = item.optString("prayer", ""),
                            title = item.optString("title", "Adhan"),
                            body = item.optString("body", ""),
                        ),
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    @Synchronized
    fun save(context: Context, alarms: List<AdhanAlarm>) {
        val array = JSONArray()
        for (alarm in alarms) {
            array.put(
                JSONObject().apply {
                    put("id", alarm.id)
                    put("triggerAtMillis", alarm.triggerAtMillis)
                    put("prayer", alarm.prayer)
                    put("title", alarm.title)
                    put("body", alarm.body)
                },
            )
        }
        // commit() is intentional: a reboot can follow immediately after the
        // app schedules, and the native list must already be on disk.
        prefs(context).edit().putString(KEY, array.toString()).commit()
    }

    @Synchronized
    fun clear(context: Context) {
        prefs(context).edit().remove(KEY).commit()
    }
}
