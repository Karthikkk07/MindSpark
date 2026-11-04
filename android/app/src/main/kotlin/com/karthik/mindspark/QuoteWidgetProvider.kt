package com.karthik.mindspark

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews

class QuoteWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // The system calls this at most about every 30 minutes, and may delay it.
        WidgetStore.advance(context)
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_NEXT) {
            WidgetStore.advance(context)
            refreshAll(context)
        }
    }

    companion object {
        const val ACTION_NEXT = "com.karthik.mindspark.widget.NEXT"
        private const val MEDIUM_MIN_WIDTH_DP = 200
        private const val MEDIUM_MIN_HEIGHT_DP = 90
        private const val FLAGS =
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, QuoteWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { updateWidget(context, manager, it) }
        }

        fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
            val options = manager.getAppWidgetOptions(id)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val medium = minWidth >= MEDIUM_MIN_WIDTH_DP && minHeight >= MEDIUM_MIN_HEIGHT_DP

            val views = RemoteViews(
                context.packageName,
                if (medium) R.layout.widget_medium else R.layout.widget_small
            )

            val quote = WidgetStore.currentQuote(context)
            if (quote == null) {
                views.setTextViewText(R.id.widget_quote, context.getString(R.string.widget_empty))
                views.setTextViewText(R.id.widget_author, "")
                views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context, null))
            } else {
                views.setTextViewText(R.id.widget_quote, quote.text)
                views.setTextViewText(R.id.widget_author, quote.author)
                views.setContentDescription(R.id.widget_root, "${quote.text} - ${quote.author}")
                views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context, quote.id))
            }
            if (medium) {
                views.setOnClickPendingIntent(R.id.widget_next, nextIntent(context))
            }
            manager.updateAppWidget(id, views)
        }

        private fun openAppIntent(context: Context, quoteId: String?): PendingIntent {
            val intent = if (quoteId == null) {
                context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
            } else {
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("mindspark:///quote/" + Uri.encode(quoteId)),
                    context,
                    MainActivity::class.java
                )
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            return PendingIntent.getActivity(context, 0, intent, FLAGS)
        }

        private fun nextIntent(context: Context): PendingIntent {
            val intent = Intent(context, QuoteWidgetProvider::class.java).setAction(ACTION_NEXT)
            return PendingIntent.getBroadcast(context, 0, intent, FLAGS)
        }
    }
}
