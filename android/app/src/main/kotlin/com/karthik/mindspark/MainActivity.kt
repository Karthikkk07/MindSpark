package com.karthik.mindspark

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

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
}
