package com.example.postureguard

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "postureguard/device_screen_time"
        const val EVENT_LOOKBACK_MILLIS = 24L * 60L * 60L * 1000L
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isUsageAccessSupported" ->
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" ->
                        result.success(openUsageAccessSettings())
                    "getDeviceScreenTimeSeconds" -> {
                        val start = call.argument<Number>("startMillis")?.toLong()
                        val end = call.argument<Number>("endMillis")?.toLong()
                        if (start == null || end == null || end < start) {
                            result.error("invalid_range", "A valid local time range is required.", null)
                        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                            result.success(null)
                        } else if (!hasUsageAccess()) {
                            result.error("usage_access_denied", "Android Usage Access is not granted.", null)
                        } else {
                            try {
                                result.success(queryInteractiveSeconds(start, end))
                            } catch (error: Throwable) {
                                result.error("usage_query_failed", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        if (intent.resolveActivity(packageManager) == null) return false
        startActivity(intent)
        return true
    }

    // Returns only an aggregate duration. Package names and per-app events never
    // leave this method or cross the Flutter channel.
    private fun queryInteractiveSeconds(start: Long, end: Long): Long {
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events =
            manager.queryEvents(max(0L, start - EVENT_LOOKBACK_MILLIS), end)
                ?: return 0L
        val event = UsageEvents.Event()
        var interactive = false
        var interactiveSince = start
        var totalMillis = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType != UsageEvents.Event.SCREEN_INTERACTIVE &&
                event.eventType != UsageEvents.Event.SCREEN_NON_INTERACTIVE
            ) {
                continue
            }

            if (event.timeStamp < start) {
                interactive = event.eventType == UsageEvents.Event.SCREEN_INTERACTIVE
                interactiveSince = start
                continue
            }

            if (event.eventType == UsageEvents.Event.SCREEN_INTERACTIVE) {
                if (!interactive) {
                    interactive = true
                    interactiveSince = max(start, event.timeStamp)
                }
            } else if (interactive) {
                totalMillis += max(0L, event.timeStamp - interactiveSince)
                interactive = false
            }
        }

        if (interactive) totalMillis += max(0L, end - interactiveSince)
        return totalMillis / 1000L
    }
}
