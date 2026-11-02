package com.frogdadday.android_toolkit

import android.Manifest
import android.app.WallpaperManager
import android.content.ContentValues
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.pm.PackageManager
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraAccessException
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.SystemClock
import android.net.Uri
import android.provider.Settings
import android.provider.AlarmClock
import android.provider.ContactsContract
import android.provider.MediaStore
import android.media.RingtoneManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private data class SavedPhoto(val name: String, val uri: String)
    private class PartialWallpaperException(cause: Throwable) : Exception(cause)

    companion object {
        private const val RECOVERY_PREFERENCES = "recovery"
        private const val MAX_STOPWATCH_MILLIS = 3153600000000L
    }

    private var torchId: String? = null
    private var ringtoneResult: MethodChannel.Result? = null
    private var storagePermissionResult: MethodChannel.Result? = null
    private val photoExecutor = Executors.newSingleThreadExecutor()
    private val ringtoneRequestCode = 8421
    private val storagePermissionRequestCode = 8422

    private fun boundedInt(call: io.flutter.plugin.common.MethodCall, name: String, default: Int, range: IntRange): Int {
        val raw = (call.arguments as? Map<*, *>)?.get(name) as? Number
        return (raw?.toInt() ?: default).coerceIn(range)
    }

    private fun launchFirst(intents: List<Intent>): Int {
        intents.forEachIndexed { index, intent ->
            try {
                startActivity(intent)
                return index
            } catch (_: RuntimeException) {
                // Phone makers do not all provide or permit the same screens.
                // Continue to the next public, less-specific destination.
            }
        }
        throw ActivityNotFoundException()
    }

    private fun setting(action: String) = Intent(action)

    private fun launcherSettings(): List<Intent> = listOf(
        Intent().setComponent(ComponentName("com.motorola.launcher3", "com.android.launcher3.settings.SettingsActivity")),
        Intent().setComponent(ComponentName("com.google.android.apps.nexuslauncher", "com.google.android.apps.nexuslauncher.settings.SettingsActivity")),
        Intent().setComponent(ComponentName("com.android.launcher3", "com.android.launcher3.settings.SettingsActivity")),
        Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.frogdadday.android_toolkit/tools").setMethodCallHandler { call, result ->
            when (call.method) {
                "loadStopwatch" -> {
                    val preferences = getSharedPreferences(RECOVERY_PREFERENCES, MODE_PRIVATE)
                    val savedElapsed = preferences.getLong("elapsedMillis", 0L)
                        .coerceIn(0L, MAX_STOPWATCH_MILLIS)
                    val wasRunning = preferences.getBoolean("running", false)
                    val savedAtRealtime = preferences.getLong("savedAtElapsedRealtimeMillis", 0L)
                    val recoveredElapsed = if (wasRunning && savedAtRealtime > 0L) {
                        (savedElapsed + (SystemClock.elapsedRealtime() - savedAtRealtime).coerceAtLeast(0L))
                            .coerceIn(0L, MAX_STOPWATCH_MILLIS)
                    } else {
                        savedElapsed
                    }
                    result.success(mapOf(
                        "elapsedMillis" to recoveredElapsed,
                        "running" to wasRunning,
                    ))
                    return@setMethodCallHandler
                }
                "saveStopwatch" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val elapsed = ((arguments?.get("elapsedMillis") as? Number)?.toLong() ?: 0L)
                        .coerceIn(0L, MAX_STOPWATCH_MILLIS)
                    val running = arguments?.get("running") == true
                    getSharedPreferences(RECOVERY_PREFERENCES, MODE_PRIVATE)
                        .edit()
                        .putLong("elapsedMillis", elapsed)
                        .putBoolean("running", running)
                        .putLong("savedAtElapsedRealtimeMillis", SystemClock.elapsedRealtime())
                        .apply()
                    result.success(null)
                    return@setMethodCallHandler
                }
                "preparePhotoStorage" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ||
                        checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else if (storagePermissionResult != null) {
                        result.error("busy", null, null)
                    } else {
                        storagePermissionResult = result
                        requestPermissions(
                            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            storagePermissionRequestCode,
                        )
                    }
                    return@setMethodCallHandler
                }
                "setKeepScreenAwake" -> {
                    val keepAwake = call.argument<Boolean>("keepAwake") == true
                    if (keepAwake) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                    return@setMethodCallHandler
                }
                "savePhoto" -> {
                    val sourcePath = call.argument<String>("path")
                    if (sourcePath.isNullOrBlank()) {
                        result.error("storage_failed", null, null)
                        return@setMethodCallHandler
                    }
                    photoExecutor.execute {
                        try {
                            val savedPhoto = savePhotoToGallery(sourcePath)
                            runOnUiThread {
                                try {
                                    result.success(mapOf(
                                        "name" to savedPhoto.name,
                                        "uri" to savedPhoto.uri,
                                    ))
                                } catch (_: RuntimeException) {
                                    // The picture is safely stored even if Flutter was interrupted.
                                }
                            }
                        } catch (_: SecurityException) {
                            runOnUiThread {
                                try {
                                    result.error("storage_denied", null, null)
                                } catch (_: RuntimeException) {}
                            }
                        } catch (_: IOException) {
                            runOnUiThread {
                                try {
                                    result.error("storage_full", null, null)
                                } catch (_: RuntimeException) {}
                            }
                        } catch (_: RuntimeException) {
                            runOnUiThread {
                                try {
                                    result.error("storage_failed", null, null)
                                } catch (_: RuntimeException) {}
                            }
                        }
                    }
                    return@setMethodCallHandler
                }
                "loadPhotoPreview" -> {
                    val uri = call.argument<String>("uri")
                    if (uri.isNullOrBlank()) {
                        result.error("preview_failed", null, null)
                        return@setMethodCallHandler
                    }
                    photoExecutor.execute {
                        try {
                            val bytes = readSavedPhoto(uri)
                            runOnUiThread {
                                try {
                                    result.success(bytes)
                                } catch (_: RuntimeException) {}
                            }
                        } catch (_: Exception) {
                            runOnUiThread {
                                try {
                                    result.error("preview_failed", null, null)
                                } catch (_: RuntimeException) {}
                            }
                        }
                    }
                    return@setMethodCallHandler
                }
                "applyWallpaper" -> {
                    val uri = call.argument<String>("uri")
                    val target = call.argument<String>("target")
                    if (uri.isNullOrBlank() || target !in setOf("home", "lock", "both")) {
                        result.error("wallpaper_failed", null, null)
                        return@setMethodCallHandler
                    }
                    photoExecutor.execute {
                        try {
                            if (!applyPhotoAsWallpaper(uri, target!!)) {
                                runOnUiThread {
                                    try {
                                        result.error("wallpaper_not_allowed", null, null)
                                    } catch (_: RuntimeException) {}
                                }
                            } else {
                                runOnUiThread {
                                    try {
                                        result.success(null)
                                    } catch (_: RuntimeException) {}
                                }
                            }
                        } catch (_: PartialWallpaperException) {
                            runOnUiThread {
                                try {
                                    result.error("wallpaper_partially_applied", null, null)
                                } catch (_: RuntimeException) {}
                            }
                        } catch (_: SecurityException) {
                            runOnUiThread {
                                try {
                                    result.error("wallpaper_not_allowed", null, null)
                                } catch (_: RuntimeException) {}
                            }
                        } catch (_: Exception) {
                            runOnUiThread {
                                try {
                                    result.error("wallpaper_failed", null, null)
                                } catch (_: RuntimeException) {}
                            }
                        }
                    }
                    return@setMethodCallHandler
                }
                "openPrivacyPolicy" -> {
                    try {
                        startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://frogdadday.github.io/cosmic-easy-phone-privacy/"),
                            ),
                        )
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("unavailable", null, null)
                    }
                    return@setMethodCallHandler
                }
                "openSupport" -> {
                    try {
                        startActivity(
                            Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://buymeacoffee.com/frogdadday"),
                            ),
                        )
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("unavailable", null, null)
                    }
                    return@setMethodCallHandler
                }
                "perform" -> Unit
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            try {
                val id = call.argument<String>("id")
                if (id == "ringtone") {
                    if (!Settings.System.canWrite(this)) {
                        try {
                            val packageUri = Uri.Builder().scheme("package").opaquePart(packageName).build()
                            startActivity(Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, packageUri))
                            result.success("To let Cosmic Easy Phone apply the ringtone you choose, turn on Allow modifying system settings. Then come back and tap Choose a ringtone again.")
                        } catch (_: ActivityNotFoundException) {
                            startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                            result.success("Your phone does not offer the ringtone permission screen, so we opened Sound settings instead.")
                        }
                        return@setMethodCallHandler
                    }
                    if (ringtoneResult != null) {
                        result.error("busy", null, null)
                        return@setMethodCallHandler
                    }
                    val current = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_RINGTONE)
                    val picker = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                        .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_RINGTONE)
                        .putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Choose your ringtone")
                        .putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, current)
                        .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                    ringtoneResult = result
                    try {
                        startActivityForResult(picker, ringtoneRequestCode)
                    } catch (_: RuntimeException) {
                        ringtoneResult = null
                        try {
                            startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                            result.success("Your phone could not open its ringtone picker, so we opened Sound settings instead.")
                        } catch (_: RuntimeException) {
                            result.error("ringtone_unavailable", null, null)
                        }
                    }
                    return@setMethodCallHandler
                }
                if (id == "torchOn" || id == "torchOff") {
                    val manager = getSystemService(CAMERA_SERVICE) as CameraManager
                    val camera = manager.cameraIdList.firstOrNull { manager.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true }
                    if (camera == null) {
                        result.error("unsupported", null, null)
                    } else {
                        try {
                            manager.setTorchMode(camera, id == "torchOn")
                            torchId = if (id == "torchOn") camera else null
                            result.success("Flashlight request sent. If the light is unavailable, close other camera apps and try again.")
                        } catch (_: CameraAccessException) {
                            result.error("camera_busy", null, null)
                        } catch (_: IllegalArgumentException) {
                            result.error("unsupported", null, null)
                        }
                    }
                    return@setMethodCallHandler
                }
                val destinations = when (id) {
                    "messages" -> listOf(Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_MESSAGING))
                    "volume" -> if (Build.VERSION.SDK_INT >= 29) listOf(Intent(Settings.Panel.ACTION_VOLUME), Intent(Settings.ACTION_SOUND_SETTINGS)) else listOf(Intent(Settings.ACTION_SOUND_SETTINGS))
                    "sound" -> listOf(Intent(Settings.ACTION_SOUND_SETTINGS))
                    "dnd" -> listOf(setting("android.settings.ZEN_MODE_SETTINGS"), Intent(Settings.ACTION_SOUND_SETTINGS))
                    "text" -> listOf(setting("android.settings.TEXT_READING_SETTINGS"), setting("android.settings.FONT_SIZE_SETTINGS"), Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), Intent(Settings.ACTION_DISPLAY_SETTINGS))
                    "display" -> listOf(setting("android.settings.TEXT_READING_SETTINGS"), setting("android.settings.SCREEN_ZOOM_SETTINGS"), Intent(Settings.ACTION_DISPLAY_SETTINGS))
                    "brightness" -> listOf(setting("android.settings.BRIGHTNESS_SETTINGS"), Intent(Settings.ACTION_DISPLAY_SETTINGS))
                    "timeout" -> listOf(setting("android.settings.SCREEN_TIMEOUT_SETTINGS"), Intent(Settings.ACTION_DISPLAY_SETTINGS))
                    "rotate" -> listOf(setting("android.settings.AUTO_ROTATE_SETTINGS"), Intent(Settings.ACTION_DISPLAY_SETTINGS))
                    "keyboard" -> listOf(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
                    "apps" -> listOf(Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS))
                    "storage" -> listOf(Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS), setting("android.settings.STORAGE_SETTINGS"))
                    "battery" -> listOf(Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS), setting("android.settings.BATTERY_SETTINGS"))
                    "wallpaper" -> listOf(setting("android.settings.WALLPAPER_SETTINGS"), Intent(Intent.ACTION_SET_WALLPAPER))
                    "camera" -> listOf(Intent("android.media.action.STILL_IMAGE_CAMERA"))
                    "contacts" -> listOf(Intent(Intent.ACTION_VIEW, ContactsContract.Contacts.CONTENT_URI))
                    "home" -> launcherSettings()
                    "timer" -> listOf(Intent(AlarmClock.ACTION_SET_TIMER).putExtra(AlarmClock.EXTRA_LENGTH, boundedInt(call, "minutes", 5, 1..1440) * 60).putExtra(AlarmClock.EXTRA_SKIP_UI, false))
                    "alarm" -> listOf(Intent(AlarmClock.ACTION_SET_ALARM).putExtra(AlarmClock.EXTRA_HOUR, boundedInt(call, "hour", 7, 0..23)).putExtra(AlarmClock.EXTRA_MINUTES, boundedInt(call, "minute", 0, 0..59)).putExtra(AlarmClock.EXTRA_SKIP_UI, false))
                    "settings" -> listOf(Intent(Settings.ACTION_SETTINGS))
                    else -> { result.error("unavailable", null, null); return@setMethodCallHandler }
                }
                val usedFallback = launchFirst(destinations) > 0
                result.success(if (usedFallback) "Your phone does not provide the exact page to apps, so we opened the closest available screen." else null)
            } catch (_: SecurityException) { result.error("denied", null, null)
            } catch (_: ActivityNotFoundException) { result.error("unavailable", null, null)
            } catch (_: Exception) { result.error("failed", null, null) }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ringtoneRequestCode) return
        val pending = ringtoneResult ?: return
        ringtoneResult = null
        if (resultCode != RESULT_OK || data == null) {
            pending.success("No ringtone was changed.")
            return
        }
        try {
            val chosen = if (Build.VERSION.SDK_INT >= 33) {
                data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            }
            if (chosen == null) {
                pending.success("No ringtone was changed.")
                return
            }
            if (!Settings.System.canWrite(this)) {
                pending.error("denied", null, null)
                return
            }
            RingtoneManager.setActualDefaultRingtoneUri(this, RingtoneManager.TYPE_RINGTONE, chosen)
            pending.success("Your ringtone was changed.")
        } catch (_: SecurityException) {
            pending.error("denied", null, null)
        } catch (_: RuntimeException) {
            pending.error("ringtone_failed", null, null)
        }
    }

    override fun onDestroy() {
        if (isFinishing) {
            try {
                ringtoneResult?.error("cancelled", null, null)
            } catch (_: RuntimeException) {
                // The Flutter engine may already be detached while finishing.
            }
            ringtoneResult = null
            try {
                storagePermissionResult?.error("cancelled", null, null)
            } catch (_: RuntimeException) {
                // The Flutter engine may already be detached while finishing.
            }
            storagePermissionResult = null
        }
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        photoExecutor.shutdown()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != storagePermissionRequestCode) return
        val pending = storagePermissionResult ?: return
        storagePermissionResult = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            pending.success(true)
        } else {
            pending.error("storage_denied", null, null)
        }
    }

    private fun savePhotoToGallery(sourcePath: String): SavedPhoto {
        val source = File(sourcePath)
        if (!source.isFile || source.length() <= 0L || source.length() > 100L * 1024L * 1024L) {
            throw IOException("Invalid photo")
        }
        val displayName = "CEP_${SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())}.jpg"
        val savedUri: Uri
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/Cosmic Easy Phone",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("Could not create photo")
            try {
                resolver.openOutputStream(uri)?.use { output ->
                    source.inputStream().use { input -> input.copyTo(output) }
                } ?: throw IOException("Could not open photo")
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                if (resolver.update(uri, values, null, null) <= 0) {
                    throw IOException("Could not finish photo")
                }
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
            savedUri = uri
        } else {
            if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                throw SecurityException("Photo storage permission denied")
            }
            @Suppress("DEPRECATION")
            val album = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                "Cosmic Easy Phone",
            )
            if (!album.exists() && !album.mkdirs()) throw IOException("Could not create album")
            val destination = File(album, displayName)
            try {
                source.inputStream().use { input ->
                    destination.outputStream().use { output -> input.copyTo(output) }
                }
            } catch (error: Exception) {
                destination.delete()
                throw error
            }
            MediaScannerConnection.scanFile(
                this,
                arrayOf(destination.absolutePath),
                arrayOf("image/jpeg"),
                null,
            )
            savedUri = Uri.fromFile(destination)
        }
        source.delete()
        return SavedPhoto(displayName, savedUri.toString())
    }

    private fun openSavedPhoto(uriString: String): InputStream {
        val uri = Uri.parse(uriString)
        return if (uri.scheme == "content") {
            contentResolver.openInputStream(uri) ?: throw IOException("Could not open photo")
        } else if (uri.scheme == "file") {
            File(uri.path ?: throw IOException("Missing photo path")).inputStream()
        } else {
            throw IOException("Unsupported photo location")
        }
    }

    private fun readSavedPhoto(uriString: String): ByteArray {
        openSavedPhoto(uriString).use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                if (total > 32 * 1024 * 1024) throw IOException("Photo is too large to preview")
                output.write(buffer, 0, count)
            }
            return output.toByteArray()
        }
    }

    private fun applyPhotoAsWallpaper(uriString: String, target: String): Boolean {
        val wallpaper = WallpaperManager.getInstance(this)
        if (!wallpaper.isWallpaperSupported || !wallpaper.isSetWallpaperAllowed) return false
        fun apply(which: Int) {
            openSavedPhoto(uriString).use { input ->
                wallpaper.setStream(input, null, false, which)
            }
        }
        when (target) {
            "home" -> apply(WallpaperManager.FLAG_SYSTEM)
            "lock" -> apply(WallpaperManager.FLAG_LOCK)
            "both" -> {
                apply(WallpaperManager.FLAG_SYSTEM)
                try {
                    apply(WallpaperManager.FLAG_LOCK)
                } catch (error: Exception) {
                    throw PartialWallpaperException(error)
                }
            }
            else -> return false
        }
        return true
    }
    override fun onPause() {
        super.onPause()
        torchId?.let { try { (getSystemService(CAMERA_SERVICE) as CameraManager).setTorchMode(it, false) } catch (_: Exception) {} }
        torchId = null
    }
}


