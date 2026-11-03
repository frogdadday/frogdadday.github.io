package com.frogdadday.easy_camera

import android.Manifest
import android.app.WallpaperManager
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.provider.MediaStore
import android.system.ErrnoException
import android.system.OsConstants
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

///// Block 1: Testable permission rules ///////////////////////////////////////

internal fun requiredPhotoStoragePermissions(sdkInt: Int): List<String> =
    if (sdkInt <= Build.VERSION_CODES.P) {
        listOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        )
    } else {
        emptyList()
    }

internal fun allPermissionResultsGranted(
    expectedCount: Int,
    grantResults: IntArray,
): Boolean = expectedCount > 0 &&
    grantResults.size == expectedCount &&
    grantResults.all { it == PackageManager.PERMISSION_GRANTED }

///// Block 2: Activity state and camera bridge ////////////////////////////////

class MainActivity : FlutterActivity() {
    private data class SavedPhoto(val name: String, val uri: String)
    private class PartialWallpaperException(cause: Throwable) : Exception(cause)
    private class OutOfStorageException : IOException("Not enough storage space")

    private val photoExecutor = Executors.newSingleThreadExecutor()
    private var storagePermissionResult: MethodChannel.Result? = null
    private var requestedStoragePermissionCount = 0
    private val storagePermissionRequestCode = 8422

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.frogdadday.easy_camera/tools",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "needsPhotoStoragePermission" -> result.success(needsPhotoStoragePermission())
                "preparePhotoStorage" -> preparePhotoStorage(result)
                "setKeepScreenAwake" -> setKeepScreenAwake(call, result)
                "savePhoto" -> savePhoto(call, result)
                "loadPhotoPreview" -> loadPhotoPreview(call, result)
                "applyWallpaper" -> applyWallpaper(call, result)
                "perform" -> openPhoneCamera(result)
                "openPrivacyPolicy" -> openUrl(
                    "https://frogdadday.github.io/Frog-Easy-Camera-Privacy-Policy/",
                    result,
                )
                "openSupport" -> openUrl("https://buymeacoffee.com/frogdadday", result)
                else -> result.notImplemented()
            }
        }
    }

    ///// Block 3: Permission and screen helpers ///////////////////////////////

    private fun missingPhotoStoragePermissions(): List<String> =
        requiredPhotoStoragePermissions(Build.VERSION.SDK_INT).filter { permission ->
            checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED
        }

    private fun needsPhotoStoragePermission(): Boolean =
        missingPhotoStoragePermissions().isNotEmpty()

    private fun preparePhotoStorage(result: MethodChannel.Result) {
        val missingPermissions = missingPhotoStoragePermissions()
        if (missingPermissions.isEmpty()) {
            result.success(true)
        } else if (storagePermissionResult != null) {
            result.error("busy", null, null)
        } else {
            storagePermissionResult = result
            requestedStoragePermissionCount = missingPermissions.size
            requestPermissions(
                missingPermissions.toTypedArray(),
                storagePermissionRequestCode,
            )
        }
    }

    private fun setKeepScreenAwake(call: MethodCall, result: MethodChannel.Result) {
        if (call.argument<Boolean>("keepAwake") == true) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        result.success(null)
    }

    private fun openPhoneCamera(result: MethodChannel.Result) {
        try {
            startActivity(Intent("android.media.action.STILL_IMAGE_CAMERA"))
            result.success(null)
        } catch (_: RuntimeException) {
            result.error("unavailable", null, null)
        }
    }

    private fun openUrl(url: String, result: MethodChannel.Result) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            result.success(true)
        } catch (_: RuntimeException) {
            result.error("unavailable", null, null)
        }
    }

    ///// Block 4: Photo save and preview ///////////////////////////////////////

    private fun savePhoto(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("path")
        if (sourcePath.isNullOrBlank()) {
            result.error("storage_failed", null, null)
            return
        }
        val source = File(sourcePath)
        photoExecutor.execute {
            try {
                val savedPhoto = savePhotoToGallery(source)
                reply { result.success(mapOf("name" to savedPhoto.name, "uri" to savedPhoto.uri)) }
            } catch (_: SecurityException) {
                reply { result.error("storage_denied", null, null) }
            } catch (error: IOException) {
                val code = if (isOutOfStorageFailure(error)) "storage_full" else "storage_failed"
                reply { result.error(code, null, null) }
            } catch (_: RuntimeException) {
                reply { result.error("storage_failed", null, null) }
            } finally {
                // Camera captures are temporary files. Never leave one behind,
                // even when Android refuses or fails the gallery save.
                source.delete()
            }
        }
    }

    private fun loadPhotoPreview(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")
        if (uri.isNullOrBlank()) {
            result.error("preview_failed", null, null)
            return
        }
        photoExecutor.execute {
            try {
                val bytes = readSavedPhoto(uri)
                reply { result.success(bytes) }
            } catch (_: Exception) {
                reply { result.error("preview_failed", null, null) }
            }
        }
    }

    private fun savePhotoToGallery(source: File): SavedPhoto {
        if (!source.isFile || source.length() <= 0L || source.length() > 100L * 1024L * 1024L) {
            throw IOException("Invalid photo")
        }
        ensureSpaceFor(source)
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())
        val displayName = "FEC_$timestamp.jpg"
        val savedUri: Uri
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Frog Easy Camera")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("Could not create photo")
            try {
                contentResolver.openOutputStream(uri)?.use { output ->
                    source.inputStream().use { input -> input.copyTo(output) }
                } ?: throw IOException("Could not open photo")
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                if (contentResolver.update(uri, values, null, null) <= 0) {
                    throw IOException("Could not finish photo")
                }
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
            savedUri = uri
        } else {
            if (missingPhotoStoragePermissions().isNotEmpty()) {
                throw SecurityException("Photo storage permission denied")
            }
            @Suppress("DEPRECATION")
            val album = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                "Frog Easy Camera",
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
        return SavedPhoto(displayName, savedUri.toString())
    }

    private fun ensureSpaceFor(source: File) {
        @Suppress("DEPRECATION")
        val storageRoot = Environment.getExternalStorageDirectory()
        val requiredBytes = source.length() + (1024L * 1024L)
        val availableBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val storageManager = getSystemService(StorageManager::class.java)
                storageManager.getAllocatableBytes(storageManager.getUuidForPath(storageRoot))
            } catch (_: IOException) {
                storageRoot.usableSpace
            }
        } else {
            storageRoot.usableSpace
        }
        if (availableBytes < requiredBytes) throw OutOfStorageException()
    }

    private fun isOutOfStorageFailure(error: Throwable): Boolean {
        var cause: Throwable? = error
        while (cause != null) {
            if (cause is OutOfStorageException) return true
            if (cause is ErrnoException && cause.errno == OsConstants.ENOSPC) return true
            if (cause.message?.contains("no space left", ignoreCase = true) == true) return true
            cause = cause.cause
        }
        return false
    }

    private fun openSavedPhoto(uriString: String): InputStream {
        val uri = Uri.parse(uriString)
        return when (uri.scheme) {
            "content" -> contentResolver.openInputStream(uri)
                ?: throw IOException("Could not open photo")
            "file" -> File(uri.path ?: throw IOException("Missing photo path")).inputStream()
            else -> throw IOException("Unsupported photo location")
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
                if (total > 32 * 1024 * 1024) throw IOException("Photo is too large")
                output.write(buffer, 0, count)
            }
            return output.toByteArray()
        }
    }

    ///// Block 5: Wallpaper support ///////////////////////////////////////////

    private fun applyWallpaper(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")
        val target = call.argument<String>("target")
        if (uri.isNullOrBlank() || target !in setOf("home", "lock", "both")) {
            result.error("wallpaper_failed", null, null)
            return
        }
        photoExecutor.execute {
            try {
                if (applyPhotoAsWallpaper(uri, target!!)) {
                    reply { result.success(null) }
                } else {
                    reply { result.error("wallpaper_not_allowed", null, null) }
                }
            } catch (_: PartialWallpaperException) {
                reply { result.error("wallpaper_partially_applied", null, null) }
            } catch (_: SecurityException) {
                reply { result.error("wallpaper_not_allowed", null, null) }
            } catch (_: Exception) {
                reply { result.error("wallpaper_failed", null, null) }
            }
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
        }
        return true
    }

    ///// Block 6: Lifecycle and permission results /////////////////////////////

    private fun reply(action: () -> Unit) {
        runOnUiThread {
            try {
                action()
            } catch (_: RuntimeException) {
                // Flutter may have detached after the photo was safely handled.
            }
        }
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
        val expectedCount = requestedStoragePermissionCount
        requestedStoragePermissionCount = 0
        if (allPermissionResultsGranted(expectedCount, grantResults) &&
            !needsPhotoStoragePermission()
        ) {
            pending.success(true)
        } else {
            pending.error("storage_denied", null, null)
        }
    }

    override fun onDestroy() {
        if (isFinishing) {
            try {
                storagePermissionResult?.error("cancelled", null, null)
            } catch (_: RuntimeException) {
                // Flutter may already be detached.
            }
            storagePermissionResult = null
            requestedStoragePermissionCount = 0
        }
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        photoExecutor.shutdown()
        super.onDestroy()
    }
}
