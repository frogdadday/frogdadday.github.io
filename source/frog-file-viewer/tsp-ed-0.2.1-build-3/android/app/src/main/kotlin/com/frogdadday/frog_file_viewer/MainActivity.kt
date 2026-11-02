package com.frogdadday.frog_file_viewer

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingCameraPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "frog_file_viewer/link")
            .setMethodCallHandler { call, result ->
                val address = when (call.method) {
                    "openSupport" -> "https://buymeacoffee.com/frogdadday"
                    "openPrivacyPolicy" ->
                        "https://frogdadday.com/Frog-File-Viewer-Privacy-Policy/"
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                try {
                    startActivity(
                        Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse(address),
                        ),
                    )
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "frog_file_viewer/storage")
            .setMethodCallHandler { call, result ->
                if (call.method != "availableTempBytes") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    result.success(StatFs(cacheDir.absolutePath).availableBytes)
                } catch (_: Exception) {
                    result.success(null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "frog_file_viewer/camera")
            .setMethodCallHandler { call, result ->
                if (call.method != "requestPermission") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                    checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(true)
                    return@setMethodCallHandler
                }
                if (pendingCameraPermissionResult != null) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                pendingCameraPermissionResult = result
                requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_REQUEST)
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_PERMISSION_REQUEST) return
        val result = pendingCameraPermissionResult ?: return
        pendingCameraPermissionResult = null
        result.success(
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
    }

    companion object {
        private const val CAMERA_PERMISSION_REQUEST = 7301
    }
}
