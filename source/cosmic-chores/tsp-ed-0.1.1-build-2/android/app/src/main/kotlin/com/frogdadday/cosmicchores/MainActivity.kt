package com.frogdadday.cosmicchores

// /////Block One/////////////////////////////////////////////////////////////
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import androidx.core.net.toUri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val storageExecutor = Executors.newSingleThreadExecutor()
    private var permissionResult: MethodChannel.Result? = null
    private var reminderPermissionResult: MethodChannel.Result? = null
    private var pendingReminder: Map<*, *>? = null
    private var reminderListId: String? = null
    private var reminderDate: String? = null
    private var nativeChannel: MethodChannel? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        reminderListId = intent.getStringExtra("list_id")
        reminderDate = intent.getStringExtra("reminder_date")
        nativeChannel?.invokeMethod("reminderOpened", null)
    }

    companion object {
        private const val channelName = "cosmic_chores/native"
        private const val contactsRequestCode = 4102
        private const val notificationsRequestCode = 4103
    }

    // /////Block Two///////////////////////////////////////////////////////////
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        reminderListId = intent.getStringExtra("list_id")
        reminderDate = intent.getStringExtra("reminder_date")
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        nativeChannel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeReminder" -> {
                        val id = reminderListId
                        if (id == null) {
                            result.success(null)
                        } else {
                            result.success(mapOf("id" to id, "date" to reminderDate))
                            reminderListId = null
                            reminderDate = null
                            intent.removeExtra("list_id")
                            intent.removeExtra("reminder_date")
                        }
                    }
                    "takeReminderListId" -> {
                        result.success(reminderListId)
                        reminderListId = null
                        intent.removeExtra("list_id")
                    }
                    "readState" -> readState(result)
                    "readStateBackup" -> readStateBackup(result)
                    "restoreStateBackup" -> restoreStateBackup(result)
                    "writeState" -> writeState(call.arguments as? String, result)
                    "contactsPermission" -> result.success(contactsPermission())
                    "requestContacts" -> requestContacts(result)
                    "searchContacts" -> {
                        val query = call.argument<String>("query").orEmpty()
                        searchContacts(query, result)
                    }
                    "openSupport" -> result.success(openUrl("https://buymeacoffee.com/frogdadday"))
                    "openPrivacyPolicy" -> result.success(
                        openUrl("https://frogdadday.github.io/cosmic-chores-privacy/"),
                    )
                    "openNotificationSettings" -> result.success(openNotificationSettings())
                    "readCosmicMode" -> result.success(
                        getSharedPreferences("cosmic_chores", MODE_PRIVATE)
                            .getBoolean("cosmic_mode", false),
                    )
                    "writeCosmicMode" -> {
                        val enabled = call.arguments as? Boolean ?: false
                        getSharedPreferences("cosmic_chores", MODE_PRIVATE)
                            .edit { putBoolean("cosmic_mode", enabled) }
                        result.success(null)
                    }
                    "readMissionProgress" -> result.success(
                        getSharedPreferences("cosmic_chores", MODE_PRIVATE)
                            .getString("mission_progress", null),
                    )
                    "writeMissionProgress" -> {
                        val progress = call.arguments as? String
                        storageExecutor.execute {
                        try {
                        val saved = getSharedPreferences("cosmic_chores", MODE_PRIVATE)
                            .edit().putString("mission_progress", progress).commit()
                        runOnUiThread {
                            if (saved) result.success(null)
                            else result.error("STORAGE_WRITE", "Unable to save checkmarks", null)
                        }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("STORAGE_WRITE", "Unable to save checkmarks", null) }
                        }
                        }
                    }
                    "scheduleReminder" -> scheduleReminder(call.arguments as? Map<*, *>, result)
                    "ensureReminder" -> ensureReminder(call.arguments as? Map<*, *>, result)
                    "cancelReminder" -> {
                        val id = call.argument<String>("id").orEmpty()
                        ReminderScheduler.cancel(this, id)
                        result.success(null)
                    }
                    "shareMessage" -> {
                        val body = call.argument<String>("body").orEmpty()
                        val recipients = call.argument<List<String>>("recipients").orEmpty()
                        result.success(openMessage(body, recipients))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // /////Block Three/////////////////////////////////////////////////////////
    private fun readState(result: MethodChannel.Result) {
        storageExecutor.execute {
            try {
                val raw = getSharedPreferences("cosmic_chores", MODE_PRIVATE)
                    .getString("app_state", null)
                runOnUiThread { result.success(raw) }
            } catch (_: Exception) {
                runOnUiThread { result.error("STORAGE_READ", "Unable to read saved lists", null) }
            }
        }
    }

    private fun readStateBackup(result: MethodChannel.Result) {
        storageExecutor.execute {
            try {
                val raw = getSharedPreferences("cosmic_chores", MODE_PRIVATE)
                    .getString("app_state_backup", null)
                runOnUiThread { result.success(raw) }
            } catch (_: Exception) {
                runOnUiThread { result.error("STORAGE_READ", "Unable to read the saved backup", null) }
            }
        }
    }

    private fun restoreStateBackup(result: MethodChannel.Result) {
        storageExecutor.execute {
            try {
                val preferences = getSharedPreferences("cosmic_chores", MODE_PRIVATE)
                val backup = preferences.getString("app_state_backup", null)
                if (backup == null) {
                    runOnUiThread { result.error("NO_BACKUP", "No saved backup is available", null) }
                    return@execute
                }
                val restored = preferences.edit().putString("app_state", backup).commit()
                runOnUiThread {
                    if (restored) result.success(null)
                    else result.error("STORAGE_WRITE", "Unable to restore the saved backup", null)
                }
            } catch (_: Exception) {
                runOnUiThread { result.error("STORAGE_WRITE", "Unable to restore the saved backup", null) }
            }
        }
    }

    private fun writeState(raw: String?, result: MethodChannel.Result) {
        if (raw == null) {
            result.error("BAD_STATE", "Expected state JSON", null)
            return
        }
        storageExecutor.execute {
            try {
                val preferences = getSharedPreferences("cosmic_chores", MODE_PRIVATE)
                val previous = preferences.getString("app_state", null)
                val saved = preferences.edit()
                    .putString("app_state_backup", previous)
                    .putString("app_state", raw).commit()
                runOnUiThread {
                    if (saved) result.success(null)
                    else result.error("STORAGE_WRITE", "Unable to save chore lists", null)
                }
            } catch (_: Exception) {
                runOnUiThread { result.error("STORAGE_WRITE", "Unable to save chore lists", null) }
            }
        }
    }

    // /////Block Four//////////////////////////////////////////////////////////
    private fun contactsPermission(): String {
        return if (
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) ==
                PackageManager.PERMISSION_GRANTED
        ) "granted" else "denied"
    }

    private fun requestContacts(result: MethodChannel.Result) {
        if (contactsPermission() == "granted") {
            result.success(true)
            return
        }
        if (permissionResult != null || reminderPermissionResult != null) {
            result.error("PERMISSION_BUSY", "A contact permission request is already open", null)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_CONTACTS),
            contactsRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == contactsRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionResult?.success(granted)
            permissionResult = null
            return
        }
        if (requestCode == notificationsRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            val arguments = pendingReminder
            val result = reminderPermissionResult
            pendingReminder = null
            reminderPermissionResult = null
            if (arguments != null && result != null) {
                commitReminder(arguments, result, notificationsEnabled = granted)
            } else {
                result?.success(false)
            }
        }
    }

    private fun searchContacts(query: String, result: MethodChannel.Result) {
        if (contactsPermission() != "granted") {
            result.error("CONTACTS_PERMISSION", "Contact permission has not been granted", null)
            return
        }
        if (query.trim().length < 2) {
            result.success(emptyList<Map<String, String>>())
            return
        }
        storageExecutor.execute {
        try {
            val matches = linkedMapOf<String, Map<String, String>>()
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME_PRIMARY,
                ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            )
            val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME_PRIMARY} LIKE ?"
            val arguments = arrayOf("%${query.trim()}%")
            contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                selection,
                arguments,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME_PRIMARY} COLLATE NOCASE ASC",
            )?.use { cursor ->
                val nameIndex = cursor.getColumnIndexOrThrow(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME_PRIMARY,
                )
                val normalizedIndex = cursor.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.NORMALIZED_NUMBER,
                )
                val numberIndex = cursor.getColumnIndexOrThrow(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                )
                while (cursor.moveToNext() && matches.size < 12) {
                    val name = cursor.getString(nameIndex).orEmpty().trim()
                    val number = if (normalizedIndex >= 0) {
                        cursor.getString(normalizedIndex) ?: cursor.getString(numberIndex)
                    } else cursor.getString(numberIndex)
                    if (name.isNotEmpty() && number.isNotEmpty()) {
                        val key = "$name|$number"
                        matches[key] = mapOf("name" to name, "phone" to number)
                    }
                }
            }
            runOnUiThread { result.success(matches.values.toList()) }
        } catch (_: Exception) {
            runOnUiThread { result.error("CONTACTS_SEARCH", "Unable to search contacts", null) }
        }
        }
    }

    // /////Block Five//////////////////////////////////////////////////////////
    private fun openUrl(url: String): Boolean = try {
        startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
        true
    } catch (_: Exception) {
        false
    }

    private fun openNotificationSettings(): Boolean = try {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                putExtra(Settings.EXTRA_CHANNEL_ID, ReminderScheduler.channelId)
            }
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                "package:$packageName".toUri(),
            )
        }
        startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }

    // /////Block Six///////////////////////////////////////////////////////////
    private fun ensureReminder(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.error("BAD_REMINDER", "Expected reminder details", null)
            return
        }
        val id = arguments["id"] as? String
        if (id.isNullOrEmpty()) {
            result.error("BAD_REMINDER", "Missing list id", null)
            return
        }
        // A receiver re-schedules tomorrow only after today's notification is
        // handled. Do not replace a pending alarm just because the app opened:
        // an inexact Android alarm may still be waiting to deliver today.
        if (ReminderScheduler.payload(this, id) != null) {
            result.success(ReminderScheduler.notificationsEnabled(this))
            return
        }
        commitReminder(
            arguments,
            result,
            notificationsEnabled = ReminderScheduler.notificationsEnabled(this),
        )
    }

    private fun scheduleReminder(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.error("BAD_REMINDER", "Expected reminder details", null)
            return
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            if (arguments["requestPermission"] == false) {
                // Keep the latest payload so old assignments cannot reappear.
                commitReminder(arguments, result, notificationsEnabled = false)
                return
            }
            if (reminderPermissionResult != null || permissionResult != null) {
                result.error("PERMISSION_BUSY", "A permission request is already open", null)
                return
            }
            pendingReminder = arguments
            reminderPermissionResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationsRequestCode,
            )
            return
        }
        commitReminder(arguments, result)
    }

    private fun commitReminder(arguments: Map<*, *>, result: MethodChannel.Result, notificationsEnabled: Boolean = true) {
        try {
            val id = arguments["id"] as? String ?: error("Missing list id")
            val messagesByRotation =
                arguments["messagesByRotation"] as? List<*> ?: emptyList<Any>()
            val recipients = arguments["recipients"] as? List<*> ?: emptyList<Any>()
            val payload = JSONObject().apply {
                put("id", id)
                put("title", arguments["title"] as? String ?: "Cosmic Chores")
                put("hour", (arguments["hour"] as Number).toInt())
                put("minute", (arguments["minute"] as Number).toInt())
                put("template", arguments["template"] as? String ?: "week")
                put("rotationMode", arguments["rotationMode"] as? String ?: "daily")
                put("rotationAnchorDate", arguments["rotationAnchorDate"] as? String)
                put(
                    "rotationAnchorMillis",
                    (arguments["rotationAnchorMillis"] as Number).toLong(),
                )
                put("messagesByRotation", JSONArray(messagesByRotation))
                put("recipients", JSONArray(recipients))
            }.toString()
            ReminderScheduler.saveAndSchedule(this, id, payload)
            result.success(notificationsEnabled && ReminderScheduler.notificationsEnabled(this))
        } catch (_: Exception) {
            result.error("REMINDER", "Unable to schedule the daily reminder", null)
        }
    }

    private fun openMessage(body: String, recipients: List<String>): Boolean = try {
        val phoneNumbers = recipients.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
        val intent = if (phoneNumbers.isNotEmpty()) {
            // A comma-separated SMS URI is the standard form for more than one
            // addressee. Android Messages can then decide whether its regular
            // compose screen or a group conversation is appropriate; Cosmic
            // Chores does not force a "group text" mode for a one- or two-person list.
            Intent(
                Intent.ACTION_SENDTO,
                Uri.fromParts("smsto", phoneNumbers.joinToString(","), null),
            ).putExtra("sms_body", body)
                // Google Messages uses the standard share-text extra on some
                // current Android releases, while other SMS apps still use
                // sms_body. Supplying both keeps the draft intact.
                .putExtra(Intent.EXTRA_TEXT, body)
        } else {
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, body)
            }
        }
        val cosmicMode = getSharedPreferences("cosmic_chores", MODE_PRIVATE)
            .getBoolean("cosmic_mode", false)
        val chooserTitle = if (cosmicMode) "Send today's missions" else "Send today's chores"
        startActivity(Intent.createChooser(intent, chooserTitle))
        true
    } catch (_: Exception) {
        false
    }

    override fun onDestroy() {
        storageExecutor.shutdown()
        permissionResult = null
        reminderPermissionResult = null
        pendingReminder = null
        nativeChannel = null
        super.onDestroy()
    }
}
