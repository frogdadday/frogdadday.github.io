package com.frogdadday.cosmicchores

// /////Block One/////////////////////////////////////////////////////////////
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.edit
import androidx.core.net.toUri
import org.json.JSONObject
import org.json.JSONArray
import java.util.Calendar
import java.util.Locale

object ReminderScheduler {
    private const val preferencesName = "cosmic_chores_reminders"
    private const val payloadPrefix = "payload_"
    const val channelId = "daily_chore_reminders"

    fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val cosmicMode = context.getSharedPreferences("cosmic_chores", Context.MODE_PRIVATE)
                .getBoolean("cosmic_mode", false)
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(
                    NotificationChannel(
                        channelId,
                        if (cosmicMode) "Daily mission reminders" else "Daily chore reminders",
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ).apply {
                        description = if (cosmicMode) {
                            "Reminds you when today's mission message is ready"
                        } else {
                            "Reminds you when today's chore message is ready"
                        }
                    },
                )
        }
    }

    fun notificationsEnabled(context: Context): Boolean {
        ensureNotificationChannel(context)
        if (!androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = context.getSystemService(NotificationManager::class.java)
                .getNotificationChannel(channelId)
            if (channel?.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    fun saveAndSchedule(context: Context, id: String, payload: String) {
        cancel(context, id)
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit { putString(payloadPrefix + id, payload) }
        schedule(context, id, JSONObject(payload))
    }

    fun schedule(context: Context, id: String, payload: JSONObject) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, ReminderReceiver::class.java).putExtra("list_id", id)
            .setData("cosmicchores://reminder/${Uri.encode(id)}".toUri())
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, payload.getInt("hour"))
            set(Calendar.MINUTE, payload.getInt("minute"))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pendingIntent)
    }

    fun payload(context: Context, id: String): JSONObject? {
        val raw = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getString(payloadPrefix + id, null) ?: return null
        return try { JSONObject(raw) } catch (_: Exception) { null }
    }

    fun rescheduleAll(context: Context) {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        for ((key, value) in preferences.all) {
            if (!key.startsWith(payloadPrefix) || value !is String) continue
            val id = key.removePrefix(payloadPrefix)
            try { schedule(context, id, JSONObject(value)) } catch (_: Exception) { }
        }
    }

    fun cancel(context: Context, id: String) {
        // Cancel both the original app's identity and the collision-safe identity.
        for (data in listOf<Uri?>(null, "cosmicchores://reminder/${Uri.encode(id)}".toUri())) {
            val intent = Intent(context, ReminderReceiver::class.java).setData(data)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pendingIntent != null) {
                context.getSystemService(AlarmManager::class.java).cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }
        context.getSystemService(NotificationManager::class.java).cancel(id, 0)
        context.getSystemService(NotificationManager::class.java).cancel(id.hashCode())
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit { remove(payloadPrefix + id) }
    }
}

// /////Block Two/////////////////////////////////////////////////////////////
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("list_id") ?: return
        val payload = ReminderScheduler.payload(context, id) ?: return
        try {
        val saved = context.getSharedPreferences("cosmic_chores", Context.MODE_PRIVATE)
            .getString("app_state", null) ?: return
        val lists = JSONArray(saved)
        if ((0 until lists.length()).none { lists.getJSONObject(it).getString("id") == id }) {
            ReminderScheduler.cancel(context, id)
            return
        }
        val matrix = payload.optJSONArray("messagesByRotation")
        val legacyMessages = payload.optJSONArray("messages")
        val dayCount = when {
            matrix != null && matrix.length() > 0 -> matrix.getJSONArray(0).length()
            legacyMessages != null -> legacyMessages.length()
            else -> 0
        }
        if (dayCount == 0) return
        val today = Calendar.getInstance()
        val dayIndex = when (payload.optString("template", "week")) {
            "month" -> today.get(Calendar.DAY_OF_MONTH) - 1
            "workWeek" -> {
                val calendarDay = today.get(Calendar.DAY_OF_WEEK)
                if (calendarDay == Calendar.SATURDAY || calendarDay == Calendar.SUNDAY) -1
                else calendarDay - Calendar.MONDAY
            }
            else -> today.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY
        }
        if (dayIndex in 0 until dayCount) {
            showNotification(context, id, today)
        }
        } catch (_: Exception) {
            // Revoked notification access or damaged legacy data must not crash Android.
        } finally {
            if (ReminderScheduler.payload(context, id) != null) {
                try { ReminderScheduler.schedule(context, id, payload) } catch (_: Exception) { }
            }
        }
    }

    private fun showNotification(
        context: Context,
        id: String,
        today: Calendar,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java)
        ReminderScheduler.ensureNotificationChannel(context)
        val reminderDate = String.format(
            Locale.US,
            "%04d-%02d-%02d",
            today.get(Calendar.YEAR),
            today.get(Calendar.MONTH) + 1,
            today.get(Calendar.DAY_OF_MONTH),
        )
        val openIntent = Intent(context, MainActivity::class.java)
            .setData("cosmicchores://list/${Uri.encode(id)}".toUri())
            .putExtra("list_id", id)
            .putExtra("reminder_date", reminderDate)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val contentIntent = PendingIntent.getActivity(
            context,
            id.hashCode(),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val publicVersion = NotificationCompat.Builder(context, ReminderScheduler.channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (cosmicMode(context)) "Mission reminder" else "Chore reminder")
            .setContentText(
                if (cosmicMode(context)) "Tap to review your missions."
                else "Tap to review your chores.",
            )
            .setAutoCancel(true)
            .build()
        manager.notify(
            id, 0,
            NotificationCompat.Builder(context, ReminderScheduler.channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(
                    if (cosmicMode(context)) "Your mission reminder is ready"
                    else "Your chore reminder is ready",
                )
                .setContentText(
                    if (cosmicMode(context)) "Tap to review and prepare today's missions."
                    else "Tap to review and prepare today's chores.",
                )
                .setStyle(
                    NotificationCompat.BigTextStyle().bigText(
                        if (cosmicMode(context)) {
                            "Your missions are ready to review. You choose whether to send the prepared message."
                        } else {
                            "Your chores are ready to review. You choose whether to send the prepared message."
                        },
                    ),
                )
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setPublicVersion(publicVersion)
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .build(),
        )
    }

    private fun cosmicMode(context: Context): Boolean =
        context.getSharedPreferences("cosmic_chores", Context.MODE_PRIVATE)
            .getBoolean("cosmic_mode", false)
}

// /////Block Three///////////////////////////////////////////////////////////
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            ReminderScheduler.rescheduleAll(context)
        }
    }
}
