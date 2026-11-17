package com.karthik.mindspark

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermission?.success(granted)
            pendingPermission = null
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (ReminderManager.hasPermission(this)) {
            result.success(ReminderManager.notificationsAllowed(this))
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_CODE,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "com.karthik.mindspark/reminder")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "notificationsAllowed" ->
                        result.success(ReminderManager.notificationsAllowed(this))
                    "requestPermission" -> requestNotificationPermission(result)
                    "schedule" -> {
                        val hour = call.argument<Int>("hour")
                        val minute = call.argument<Int>("minute")
                        val messages = call.argument<List<String>>("messages") ?: emptyList()
                        if (hour == null || minute == null) {
                            result.error("invalid_time", "Hour and minute are required", null)
                        } else {
                            ReminderManager.schedule(this, hour, minute, messages)
                            result.success(true)
                        }
                    }
                    "cancel" -> {
                        ReminderManager.cancel(this)
                        result.success(true)
                    }
                    "showNow" -> {
                        val message = call.argument<String>("message").orEmpty()
                        result.success(ReminderManager.show(this, message))
                    }
                    "openNotificationSettings" -> {
                        ReminderManager.openNotificationSettings(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, "com.karthik.mindspark/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = call.argument<String>("text")
                        if (text.isNullOrBlank()) {
                            result.error("invalid_text", "Nothing to share", null)
                        } else {
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(send, "Share quote"))
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, "com.karthik.mindspark/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateQuotes" -> {
                        val json = call.argument<String>("quotes")
                        if (json == null) {
                            result.error("invalid_quotes", "No quotes provided", null)
                        } else {
                            WidgetStore.saveQuotes(applicationContext, json)
                            QuoteWidgetProvider.refreshAll(applicationContext)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val NOTIFICATION_PERMISSION_CODE = 4101
    }
}
