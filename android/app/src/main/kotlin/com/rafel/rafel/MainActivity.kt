package com.rafel.rafel

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "rafel/adhan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            handleAdhanCall(call, result)
        }
    }

    private fun handleAdhanCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "scheduleAdhan" -> {
                try {
                    val alarms = parseAlarms(call.arguments)
                    AdhanScheduler.scheduleAll(applicationContext, alarms)
                    result.success(alarms.size)
                } catch (error: Exception) {
                    result.error(
                        "schedule_failed",
                        error.message ?: "Could not schedule adhan alarms.",
                        null,
                    )
                }
            }
            "cancelAllAdhan" -> {
                try {
                    AdhanScheduler.cancelAll(applicationContext)
                    result.success(null)
                } catch (error: Exception) {
                    result.error(
                        "cancel_failed",
                        error.message ?: "Could not cancel adhan alarms.",
                        null,
                    )
                }
            }
            "stopAdhan" -> {
                AdhanService.stop(applicationContext)
                result.success(null)
            }
            "canScheduleExactAlarms" ->
                result.success(AdhanScheduler.canScheduleExact(applicationContext))
            else -> result.notImplemented()
        }
    }

    private fun parseAlarms(arguments: Any?): List<AdhanAlarm> {
        val list = arguments as? List<*> ?: return emptyList()
        return list.mapNotNull { raw ->
            val map = raw as? Map<*, *> ?: return@mapNotNull null
            val id = (map["id"] as? Number)?.toInt() ?: return@mapNotNull null
            val trigger =
                (map["triggerAtMillis"] as? Number)?.toLong() ?: return@mapNotNull null
            if (trigger <= 0L) return@mapNotNull null
            AdhanAlarm(
                id = id,
                triggerAtMillis = trigger,
                prayer = map["prayer"] as? String ?: "",
                title = map["title"] as? String ?: "Adhan",
                body = map["body"] as? String ?: "",
            )
        }
    }
}
