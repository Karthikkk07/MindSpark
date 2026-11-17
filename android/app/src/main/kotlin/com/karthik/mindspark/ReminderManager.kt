package com.karthik.mindspark

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import org.json.JSONArray
import java.util.Calendar

/** Daily reminder notifications, driven by an inexact repeating alarm. */
object ReminderManager {
    private const val CHANNEL_ID = "daily_reminder"
    private const val NOTIFICATION_ID = 1001
    private const val PREFS = "reminder"
    private const val KEY_HOUR = "hour"
    private const val KEY_MINUTE = "minute"
    private const val KEY_MESSAGES = "messages"
    private const val DEFAULT_MESSAGE = "Your daily motivation is ready."

    fun notificationsAllowed(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        return manager.areNotificationsEnabled()
    }

    /** True when the notification permission is already granted (or not needed). */
    fun hasPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun schedule(context: Context, hour: Int, minute: Int, messages: List<String>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt(KEY_HOUR, hour)
            .putInt(KEY_MINUTE, minute)
            .putString(KEY_MESSAGES, JSONArray(messages).toString())
            .apply()
        setAlarm(context, hour, minute)
    }

    /** Sets the alarm again from the saved time, for example after a reboot. */
    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_HOUR)) return
        setAlarm(context, prefs.getInt(KEY_HOUR, 8), prefs.getInt(KEY_MINUTE, 0))
    }

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(alarmIntent(context))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    /** Shows the notification now. Returns false when notifications are blocked. */
    fun show(context: Context, message: String): Boolean {
        if (!notificationsAllowed(context)) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        ensureChannel(manager)

        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle("MindSpark")
            .setContentText(message)
            .setStyle(android.app.Notification.BigTextStyle().bigText(message))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
        return true
    }

    /** Called by the alarm: shows today's quote, rotating through the saved ones. */
    fun showDaily(context: Context) {
        val saved = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_MESSAGES, null)
        val messages = mutableListOf<String>()
        if (saved != null) {
            val array = JSONArray(saved)
            for (i in 0 until array.length()) messages.add(array.getString(i))
        }
        val day = System.currentTimeMillis() / (24L * 60 * 60 * 1000)
        val message = if (messages.isEmpty()) DEFAULT_MESSAGE
        else messages[(day % messages.size).toInt()]
        show(context, message)
    }

    fun openNotificationSettings(context: Context) {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun setAlarm(context: Context, hour: Int, minute: Int) {
        val first = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        // Inexact on purpose: no special permission, and the system may batch it.
        context.getSystemService(AlarmManager::class.java).setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            first.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            alarmIntent(context),
        )
    }

    private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, ReminderReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Daily reminder", NotificationManager.IMPORTANCE_DEFAULT)
                .apply { description = "A motivational quote at the time you choose" },
        )
    }
}
