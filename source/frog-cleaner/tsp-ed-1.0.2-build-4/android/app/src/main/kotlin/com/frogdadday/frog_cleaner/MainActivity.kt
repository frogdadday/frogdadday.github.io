package com.frogdadday.frog_cleaner

import android.app.Activity
import android.content.Intent
import android.content.ComponentName
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.ThumbnailUtils
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.DocumentsContract as DC
import android.provider.MediaStore
import android.provider.Settings
import android.util.Size
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.io.ByteArrayOutputStream
import java.io.FileNotFoundException
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val thumbnailWorker = Executors.newFixedThreadPool(3)
    private val running = AtomicBoolean(false)
    private val cancelled = AtomicBoolean(false)
    private var picker: MethodChannel.Result? = null
    private var pendingTrash: PendingTrash? = null
    private val prefs by lazy { getSharedPreferences("cleaner", MODE_PRIVATE) }
    private val snapshot = java.util.concurrent.ConcurrentHashMap<String, Entry>()
    private var snapshotLoaded = false
    private val snapshotFile by lazy { File(filesDir, "last_scan.jsonl") }
    private val snapshotStore by lazy { SnapshotStore(snapshotFile) }
    private var scanMetadata = JSONObject()
    private var hasScan = false
    private var snapshotWarning: String? = null
    private val trashedMediaName = Regex("^\\.trashed-\\d+-.+")
    private val authority = "com.android.externalstorage.documents"
    private val columns = arrayOf(DC.Document.COLUMN_DOCUMENT_ID, DC.Document.COLUMN_DISPLAY_NAME,
        DC.Document.COLUMN_MIME_TYPE, DC.Document.COLUMN_SIZE, DC.Document.COLUMN_LAST_MODIFIED,
        DC.Document.COLUMN_FLAGS)

    data class Entry(val id: String, val uri: Uri, val name: String, val mime: String,
        val size: Long?, val modified: Long?, val flags: Int, val location: String,
        val parentId: String, val writable: Boolean, val rawFile: File? = null) {
        val deletable get() = if (rawFile != null) {
            writable && rawFile.isFile && size != null && modified != null && modified > 0
        } else {
            writable && size != null && modified != null && modified > 0 &&
                mime != DC.Document.MIME_TYPE_DIR && flags and DC.Document.FLAG_SUPPORTS_DELETE != 0
        }
        fun map() = mapOf("id" to id, "name" to name, "location" to location,
            "size" to size, "modified" to modified, "parentId" to parentId, "canDelete" to deletable)
        fun json() = JSONObject().apply {
            put("id", id); put("uri", uri.toString()); put("name", name); put("mime", mime)
            put("size", size ?: JSONObject.NULL); put("modified", modified ?: JSONObject.NULL)
            put("flags", flags); put("location", location); put("parentId", parentId)
            put("writable", writable); put("rawPath", rawFile?.absolutePath ?: JSONObject.NULL)
        }
    }

    data class PendingTrash(
        val entries: List<Entry>,
        val failed: List<String>,
        val result: MethodChannel.Result,
    )

    private fun roots() = prefs.getStringSet("roots", emptySet())!!.toSet()
    private fun canonicalStorageId(id: String) = StorageIds.canonical(id)

    private fun clearSavedSnapshot() {
        snapshot.clear()
        snapshotLoaded = true
        hasScan = false
        scanMetadata = JSONObject()
        // Invalidate before touching disk so an interrupted invalidation cannot restore old files.
        prefs.edit().putBoolean("scanInvalidated", true).commit()
        persistSnapshot()
    }

    private fun beginPendingOperation(type: String, ids: Collection<String>) {
        prefs.edit()
            .putString("pendingOperationType", type)
            .putStringSet("pendingOperationIds", ids.toSet())
            .commit()
    }

    private fun clearPendingOperation() {
        prefs.edit()
            .remove("pendingOperationType")
            .remove("pendingOperationIds")
            .commit()
    }

    private fun reconcilePendingOperation() {
        val type = prefs.getString("pendingOperationType", null) ?: return
        val ids = prefs.getStringSet("pendingOperationIds", emptySet()) ?: emptySet()
        var removed = 0
        var stillPresent = 0
        for (id in ids) {
            val entry = snapshot[id] ?: continue
            if (entryStillMatches(entry)) {
                stillPresent++
            } else {
                snapshot.remove(id)
                removed++
            }
        }
        clearPendingOperation()
        if (removed > 0) persistSnapshot()
        snapshotWarning =
            "A previous $type was interrupted. $removed file entries were reconciled and $stillPresent remain unchanged. Scan again before taking more action."
    }

    private fun persistSnapshot() {
        try {
            snapshotStore.write { writer ->
                writer.write(JSONObject(scanMetadata.toString()).apply {
                    put("recordType", "scan"); put("version", 2); put("hasScan", hasScan)
                }.toString() + "\n")
                snapshot.values.forEach { entry ->
                    writer.write(entry.json().toString() + "\n")
                }
            }
            prefs.edit().putBoolean("scanInvalidated", false).commit()
            snapshotWarning = null
        } catch (_: Exception) {
            snapshotWarning = "Could not save the latest results. They may not be available after restarting."
        }
    }

    private fun ensureSnapshotLoaded() {
        if (snapshotLoaded) return
        snapshotLoaded = true
        if (prefs.getBoolean("scanInvalidated", false)) return
        try {
            val exclusions = ignored()
            snapshotStore.read { reader ->
                reader.buffered().lineSequence().filter { it.isNotBlank() }.forEach { line ->
                    val data = JSONObject(line)
                    if (data.optString("recordType") == "scan") {
                        scanMetadata = data
                        hasScan = data.optBoolean("hasScan", false)
                        return@forEach
                    }
                    // Legacy saves have no trustworthy original scan time or completion status.
                    hasScan = true
                    val rawPath = data.optString("rawPath").takeIf { it.isNotEmpty() && it != "null" }
                    if (rawPath != null && !hasAllFilesAccess()) return@forEach
                    val entry = Entry(
                        id = data.getString("id"),
                        uri = Uri.parse(data.optString("uri")),
                        name = data.getString("name"),
                        mime = data.getString("mime"),
                        size = if (data.isNull("size")) null else data.getLong("size"),
                        modified = if (data.isNull("modified")) null else data.getLong("modified"),
                        flags = data.getInt("flags"),
                        location = data.getString("location"),
                        parentId = data.getString("parentId"),
                        writable = data.getBoolean("writable"),
                        rawFile = rawPath?.let(::File),
                    )
                    if (!excluded(entry.id, exclusions)) snapshot[entry.id] = entry
                }
            }
        } catch (_: FileNotFoundException) {
            // No previous scan yet.
        } catch (_: Exception) {
            snapshot.clear()
            hasScan = false
            scanMetadata = JSONObject()
            snapshotWarning = "The previous scan could not be restored. Please scan again."
        }
        reconcilePendingOperation()
    }
    private fun ignored(): JSONObject {
        val saved = JSONObject(prefs.getString("ignored", "{}")!!)
        val normalized = JSONObject()
        saved.keys().forEach { key -> normalized.put(canonicalStorageId(key), saved.getString(key)) }
        return normalized
    }
    // Local provider document IDs contain volume:path. Boundaries avoid matching sibling prefixes.
    private fun within(id: String, parent: String): Boolean {
        return StorageIds.within(id, parent)
    }
    private fun excluded(id: String, exclusions: JSONObject) = exclusions.keys().asSequence().any { within(id, it) }
    private fun hasAllFilesAccess() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
        Environment.isExternalStorageManager()
    private fun cacheAutomationEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val service = ComponentName(this, AutoCacheCleanerService::class.java).flattenToString()
        return enabled.split(':').any { it.equals(service, ignoreCase = true) }
    }

    private fun cacheCandidates(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(intent, 0)
            .map { it.activityInfo.applicationInfo }
            .filter { it.packageName != packageName && it.flags and ApplicationInfo.FLAG_SYSTEM == 0 }
            .distinctBy { it.packageName }
            .map { app ->
                mapOf(
                    "package" to app.packageName,
                    "label" to packageManager.getApplicationLabel(app).toString(),
                )
            }
            .sortedBy { it["label"]?.lowercase() }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "frog_cleaner/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "cancel") { cancelled.set(true); result.success(emptyMap<String, Any>()); return@setMethodCallHandler }
                if (call.method == "pick") {
                    if (picker != null || running.get()) { result.error("busy", "An operation is running", null); return@setMethodCallHandler }
                    picker = result
                    try {
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                            putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                        }, 700)
                    } catch (e: Exception) { picker = null; result.error("picker", "Folder picker unavailable", null) }
                    return@setMethodCallHandler
                }
                if (call.method == "open") {
                    ensureSnapshotLoaded()
                    val entry = snapshot[call.argument<String>("id")]
                    if (entry == null) { result.error("missing", "Scan again", null); return@setMethodCallHandler }
                    try {
                        val openUri = entry.rawFile?.let { file ->
                            FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        } ?: entry.uri
                        startActivity(Intent.createChooser(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(openUri, entry.mime)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }, "Open file"))
                        result.success(emptyMap<String, Any>())
                    } catch (e: Exception) { result.success(mapOf("message" to "No installed app could open this file.")) }
                    return@setMethodCallHandler
                }
                if (call.method == "requestAllFilesAccess") {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                        result.success(mapOf("message" to "Full device analysis requires Android 11 or newer."))
                        return@setMethodCallHandler
                    }
                    try {
                        startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                            Uri.parse("package:$packageName")))
                        result.success(mapOf("message" to "Use Android's next screen to allow full device analysis, then return here."))
                    } catch (e: Exception) {
                        result.success(mapOf("message" to "Android could not open the all-files access setting."))
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "openManageApps") {
                    try {
                        startActivity(Intent(Settings.ACTION_MANAGE_ALL_APPLICATIONS_SETTINGS))
                        result.success(mapOf("message" to "Android's app controls are open. Frog Cleaner will not make changes there."))
                    } catch (e: Exception) {
                        result.success(mapOf("message" to "Android's app controls are not available on this device."))
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "cacheCandidates") {
                    result.success(mapOf("apps" to cacheCandidates()))
                    return@setMethodCallHandler
                }
                if (call.method == "cacheAutomationStatus") {
                    result.success(
                        AutoCacheCleanerService.status(this) + mapOf(
                            "enabled" to cacheAutomationEnabled(),
                            "connected" to AutoCacheCleanerService.isConnected(),
                        ),
                    )
                    return@setMethodCallHandler
                }
                if (call.method == "openCacheAccessibilitySettings") {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(mapOf("opened" to true))
                    } catch (e: Exception) {
                        result.success(mapOf("opened" to false))
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "startCacheAutomation") {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val started = cacheAutomationEnabled() && AutoCacheCleanerService.start(packages)
                    val response = mutableMapOf<String, Any?>("started" to started)
                    if (!started) {
                        val message = AutoCacheCleanerService.status(this)["message"]
                        if (message != null) response["message"] = message
                    }
                    result.success(response)
                    return@setMethodCallHandler
                }
                if (call.method == "stopCacheAutomation") {
                    AutoCacheCleanerService.stop()
                    result.success(emptyMap<String, Any>())
                    return@setMethodCallHandler
                }
                if (call.method == "openSupport") {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW,
                            Uri.parse("https://buymeacoffee.com/frogdadday")))
                        result.success(mapOf("opened" to true))
                    } catch (e: Exception) {
                        result.success(mapOf("opened" to false))
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "openPrivacyPolicy") {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW,
                            Uri.parse("https://frogdadday.github.io/frog-cleaner-privacy-policy/")))
                        result.success(mapOf("opened" to true))
                    } catch (e: Exception) {
                        result.success(mapOf("opened" to false))
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "trash") {
                    if (!running.compareAndSet(false, true)) {
                        result.error("busy", "An operation is running", null)
                        return@setMethodCallHandler
                    }
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    val duplicateRetainedGroups =
                        call.argument<List<List<String>>>("duplicateRetainedGroups") ?: emptyList()
                    worker.execute {
                        try {
                            ensureSnapshotLoaded()
                            requestTrash(ids, duplicateRetainedGroups, result)
                        } catch (_: Exception) {
                            finishTrash(result, mapOf("message" to "Android Trash could not be prepared. Your files were kept."))
                        }
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "thumbnail") {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("thumbnail", "Missing file identifier", null)
                        return@setMethodCallHandler
                    }
                    val maxDimension = (call.argument<Int>("maxDimension") ?: 160).coerceIn(64, 1200)
                    thumbnailWorker.execute {
                        try {
                            val response = thumbnail(id, maxDimension)
                            runOnUiThread { result.success(response) }
                        } catch (_: Exception) {
                            runOnUiThread { result.success(emptyMap<String, Any>()) }
                        }
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "state") {
                    worker.execute {
                        try {
                            val response = state()
                            runOnUiThread { result.success(response) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("storage", "Storage state could not be read", null) }
                        }
                    }
                    return@setMethodCallHandler
                }
                if (!running.compareAndSet(false, true)) { result.error("busy", "An operation is running", null); return@setMethodCallHandler }
                cancelled.set(false)
                worker.execute {
                    try {
                        val response: Any = when (call.method) {
                            "state" -> state()
                            "scan" -> scan()
                            "duplicates" -> { ensureSnapshotLoaded(); findDuplicates() }
                            "clearCache" -> clearAppCache()
                            "delete" -> delete(
                                call.argument<List<String>>("ids") ?: emptyList(),
                                call.argument<List<List<String>>>("duplicateRetainedGroups") ?: emptyList(),
                            )
                            "ignore" -> {
                                val exclusions = ignored()
                                exclusions.put(canonicalStorageId(call.argument<String>("id")!!), call.argument<String>("label")!!)
                                prefs.edit().putString("ignored", exclusions.toString()).commit()
                                clearSavedSnapshot()
                                mapOf("saveWarning" to snapshotWarning)
                            }
                            "unignore" -> {
                                val exclusions = ignored(); exclusions.remove(canonicalStorageId(call.argument<String>("id")!!))
                                prefs.edit().putString("ignored", exclusions.toString()).commit()
                                clearSavedSnapshot()
                                mapOf("saveWarning" to snapshotWarning)
                            }
                            "forget" -> {
                                val uri = Uri.parse(call.argument<String>("uri")!!)
                                val grant = contentResolver.persistedUriPermissions.find { it.uri == uri }
                                if (grant != null) contentResolver.releasePersistableUriPermission(uri,
                                    (if (grant.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
                                    (if (grant.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0))
                                prefs.edit().putStringSet("roots", roots() - uri.toString()).commit()
                                clearSavedSnapshot(); mapOf("saveWarning" to snapshotWarning)
                            }
                            else -> throw IllegalArgumentException("Unknown operation")
                        }
                        runOnUiThread { running.set(false); result.success(response) }
                    } catch (e: Exception) {
                        runOnUiThread { running.set(false); result.error("storage", "Storage operation could not finish", null) }
                    }
                }
            }
    }

    @Deprecated("Android activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 701) {
            val pending = pendingTrash ?: return
            pendingTrash = null
            worker.execute {
                if (resultCode == Activity.RESULT_OK) {
                    val trashed = pending.entries.map { it.id }
                    val bytes = pending.entries.sumOf { it.size ?: 0L }
                    trashed.forEach { snapshot.remove(it) }
                    persistSnapshot()
                    if (snapshotWarning == null) clearPendingOperation()
                    finishTrash(pending.result, mapOf(
                        "trashed" to trashed, "failed" to pending.failed, "bytes" to bytes,
                        "saveWarning" to snapshotWarning,
                    ))
                } else {
                    clearPendingOperation()
                    finishTrash(pending.result, mapOf(
                        "trashed" to emptyList<String>(),
                        "failed" to pending.entries.map { "${it.location}: Android Trash was not confirmed" } + pending.failed,
                        "bytes" to 0L,
                    ))
                }
            }
            return
        }
        if (requestCode != 700) return
        val result = picker ?: return; picker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(emptyMap<String, Any>()); return }
        // Restrict chosen folders to the platform local-storage provider, not cloud services.
        if (uri.authority != authority) {
            result.success(mapOf("message" to "Choose a folder in internal storage or an SD card. Cloud and other providers are not supported in this build.")); return
        }
        try {
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            when (flags) {
                Intent.FLAG_GRANT_READ_URI_PERMISSION ->
                    contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION ->
                    contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION ->
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    )
                else -> {
                    result.error("access", "Android did not grant lasting folder access", null)
                    return
                }
            }
            prefs.edit().putStringSet("roots", roots() + uri.toString()).commit()
            result.success(mapOf("message" to "Folder added. Scan when you are ready."))
        } catch (e: Exception) { result.error("access", "Could not keep folder access", null) }
    }

    private fun state(): Map<String, Any?> {
        ensureSnapshotLoaded()
        val grants = contentResolver.persistedUriPermissions
        val disk = StatFs(Environment.getDataDirectory().absolutePath)
        val exclusions = ignored()
        return mapOf("total" to disk.totalBytes, "free" to disk.availableBytes,
            "allFilesAccess" to hasAllFilesAccess(),
            "files" to snapshot.values.map { it.map() },
            "hasScan" to hasScan,
            "scanSavedAt" to if (scanMetadata.has("scannedAt")) scanMetadata.getLong("scannedAt") else null,
            "scanStatusKnown" to scanMetadata.has("cancelled"),
            "scanCancelled" to scanMetadata.optBoolean("cancelled"),
            "scanLimited" to scanMetadata.optBoolean("limited"),
            "scanErrors" to scanMetadata.optInt("errors"),
            "saveWarning" to snapshotWarning,
            "roots" to roots().map { text ->
                val uri = Uri.parse(text)
                mapOf("uri" to text, "label" to DC.getTreeDocumentId(uri),
                    "readable" to grants.any { it.uri == uri && it.isReadPermission })
            }, "ignored" to exclusions.keys().asSequence().map { mapOf("id" to it, "label" to exclusions.getString(it)) }.toList())
    }

    private fun readEntry(uri: Uri, location: String, parentId: String, writable: Boolean): Entry? =
        contentResolver.query(uri, columns, null, null, null)?.use { c ->
            if (!c.moveToFirst()) null else Entry(c.getString(0), uri, c.getString(1), c.getString(2),
                if (c.isNull(3)) null else c.getLong(3).takeIf { it >= 0 },
                if (c.isNull(4)) null else c.getLong(4), c.getInt(5), location, parentId, writable)
        }

    private fun scan(): Map<String, Any?> {
        snapshotLoaded = true
        val result = if (hasAllFilesAccess()) scanAllFiles() else scanChosenFolders()
        hasScan = true
        scanMetadata = JSONObject().apply {
            put("scannedAt", System.currentTimeMillis())
            put("cancelled", result["cancelled"] == true)
            put("limited", result["limited"] == true)
            put("errors", result["errors"] ?: 0)
            put("skipped", result["skipped"] ?: 0)
        }
        persistSnapshot()
        return result + mapOf("saveWarning" to snapshotWarning)
    }

    private fun scanChosenFolders(): Map<String, Any> {
        snapshot.clear()
        val exclusions = ignored()
        val seen = mutableSetOf<String>()
        var errors = 0; var skipped = 0; var limited = false; var visited = 0
        data class Folder(val tree: Uri, val id: String, val path: String, val writable: Boolean)
        val queue = java.util.ArrayDeque<Folder>()
        val grants = contentResolver.persistedUriPermissions
        roots().forEach { text ->
            val tree = Uri.parse(text); val id = DC.getTreeDocumentId(tree)
            val grant = grants.find { it.uri == tree && it.isReadPermission }
            if (grant == null) errors++ else queue.add(Folder(tree, id, id, grant.isWritePermission))
        }
        while (queue.isNotEmpty() && !cancelled.get() && !limited) {
            val folder = queue.removeFirst()
            if (excluded(folder.id, exclusions)) { skipped++; continue }
            if (!seen.add(folder.id)) continue
            try {
                val children = DC.buildChildDocumentsUriUsingTree(folder.tree, folder.id)
                val cursor = contentResolver.query(children, columns, null, null, null)
                if (cursor == null) { errors++; continue }
                cursor.use { c ->
                    while (!cancelled.get() && c.moveToNext()) {
                        if (++visited > 20000) { limited = true; break }
                        val id = c.getString(0)
                        if (excluded(id, exclusions)) { skipped++; continue }
                        val name = c.getString(1) ?: "Unnamed file"
                        val mime = c.getString(2) ?: "application/octet-stream"
                        val path = "${folder.path}/$name"
                        if (mime == DC.Document.MIME_TYPE_DIR) {
                            queue.add(Folder(folder.tree, id, path, folder.writable))
                        } else if (!snapshot.containsKey(id)) {
                            snapshot[id] = Entry(id, DC.buildDocumentUriUsingTree(folder.tree, id), name, mime,
                                if (c.isNull(3)) null else c.getLong(3).takeIf { it >= 0 },
                                if (c.isNull(4)) null else c.getLong(4), c.getInt(5), path, folder.id, folder.writable)
                        }
                    }
                }
            } catch (e: Exception) { errors++ }
        }
        return mapOf("files" to snapshot.values.map { it.map() }, "errors" to errors,
            "skipped" to skipped, "cancelled" to cancelled.get(), "limited" to limited)
    }

    private fun isProtectedAppDirectory(file: File, root: File): Boolean {
        val relative = file.absolutePath.removePrefix(root.absolutePath).trimStart(File.separatorChar)
        return relative == "Android/data" || relative.startsWith("Android/data${File.separator}") ||
            relative == "Android/obb" || relative.startsWith("Android/obb${File.separator}")
    }

    private fun isAndroidTrashArtifact(file: File) =
        trashedMediaName.matches(file.name)

    private fun rawEntry(file: File): Entry {
        val extension = file.extension.lowercase()
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
        val canonical = file.canonicalFile
        val path = canonical.absolutePath
        return Entry("raw:$path", Uri.EMPTY, canonical.name, mime, canonical.length(),
            canonical.lastModified(), 0, path, "raw:${canonical.parent ?: path}", canonical.canWrite(), canonical)
    }

    private fun mediaUriFor(file: File): Uri? {
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        return contentResolver.query(
            collection,
            arrayOf(MediaStore.Files.FileColumns._ID),
            "${MediaStore.MediaColumns.DATA} = ?",
            arrayOf(file.absolutePath),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                Uri.withAppendedPath(collection, cursor.getLong(0).toString())
            } else {
                null
            }
        }
    }

    private fun finishTrash(result: MethodChannel.Result, response: Map<String, Any?>) {
        runOnUiThread {
            running.set(false)
            result.success(response)
        }
    }

    // The storage worker prepares and reconciles requests; only the system UI launch is on main.
    private fun protectedDuplicateGroupsAreIntact(
        groups: List<List<String>>,
        exclusions: JSONObject,
    ): List<String> = groups.mapIndexedNotNull { index, group ->
        val retained = group.any { id ->
            snapshot[id]?.let { entry -> !excluded(id, exclusions) && entryStillMatches(entry) } == true
        }
        if (retained) null else "Duplicate group ${index + 1} no longer has a verified kept copy"
    }

    private fun requestTrash(
        ids: List<String>,
        duplicateRetainedGroups: List<List<String>>,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || !hasAllFilesAccess()) {
            finishTrash(result, mapOf("message" to "Android Trash is available after full device analysis is enabled on Android 11 or newer."))
            return
        }
        val exclusions = ignored()
        val unprotectedGroups = protectedDuplicateGroupsAreIntact(duplicateRetainedGroups, exclusions)
        if (unprotectedGroups.isNotEmpty()) {
            finishTrash(result, mapOf(
                "trashed" to emptyList<String>(),
                "failed" to unprotectedGroups,
                "bytes" to 0L,
                "message" to "No files were moved. Scan again because a duplicate group changed.",
            ))
            return
        }
        val entries = mutableListOf<Entry>()
        val failed = mutableListOf<String>()
        val uris = mutableListOf<Uri>()
        for (id in ids.distinct()) {
            val entry = snapshot[id]
            val file = entry?.rawFile
            if (entry == null || file == null ||
                (!entry.mime.startsWith("image/") && !entry.mime.startsWith("video/") && !entry.mime.startsWith("audio/")) ||
                excluded(id, exclusions) || !file.exists() || !file.isFile ||
                file.length() != entry.size || file.lastModified() != entry.modified) {
                failed.add("${entry?.location ?: id}: changed, excluded, or not eligible for Android Trash")
                continue
            }
            val uri = try { mediaUriFor(file) } catch (_: Exception) { null }
            if (uri == null) {
                failed.add("${entry.location}: Android does not list this as a trashable media file")
                continue
            }
            entries.add(entry)
            uris.add(uri)
        }
        if (entries.size > 2000) {
            entries.drop(2000).forEach {
                failed.add("${it.location}: select this file in a smaller Android Trash batch")
            }
            entries.subList(2000, entries.size).clear()
            uris.subList(2000, uris.size).clear()
        }
        if (entries.isEmpty()) {
            finishTrash(result, mapOf("trashed" to emptyList<String>(), "failed" to failed, "bytes" to 0L))
            return
        }
        try {
            val request = MediaStore.createTrashRequest(contentResolver, uris, true)
            runOnUiThread {
                try {
                    if (isFinishing || isDestroyed) throw IllegalStateException("Activity closed")
                    beginPendingOperation("Android Trash request", entries.map { it.id })
                    pendingTrash = PendingTrash(entries, failed, result)
                    startIntentSenderForResult(request.intentSender, 701, null, 0, 0, 0)
                } catch (_: Exception) {
                    pendingTrash = null
                    clearPendingOperation()
                    finishTrash(result, mapOf(
                        "trashed" to emptyList<String>(),
                        "failed" to entries.map { "${it.location}: Android Trash could not be opened" } + failed,
                        "bytes" to 0L,
                    ))
                }
            }
        } catch (_: Exception) {
            finishTrash(result, mapOf(
                "trashed" to emptyList<String>(),
                "failed" to entries.map { "${it.location}: Android Trash could not be opened" } + failed,
                "bytes" to 0L,
            ))
        }
    }

    private fun sharedStorageRoots(): List<File> {
        val result = linkedSetOf<File>()
        result.add(Environment.getExternalStorageDirectory().canonicalFile)
        for (appDirectory in getExternalFilesDirs(null)) {
            if (appDirectory == null) continue
            val normalized = appDirectory.absolutePath.replace('\\', '/')
            val marker = "/Android/data/"
            if (normalized.contains(marker)) {
                try { result.add(File(normalized.substringBefore(marker)).canonicalFile) } catch (_: Exception) { }
            }
        }
        return result.filter { it.exists() && it.isDirectory }
    }

    private fun scanAllFiles(): Map<String, Any> {
        snapshot.clear()
        val exclusions = ignored()
        data class PendingFolder(val folder: File, val storageRoot: File)
        val queue = java.util.ArrayDeque<PendingFolder>()
        val seen = mutableSetOf<String>()
        sharedStorageRoots().forEach { queue.add(PendingFolder(it, it)) }
        var errors = 0; var skipped = 0; var limited = false; var visited = 0
        while (queue.isNotEmpty() && !cancelled.get() && !limited) {
            val pending = queue.removeFirst()
            val canonical = try { pending.folder.canonicalFile } catch (_: Exception) { pending.folder.absoluteFile }
            val folderId = "raw:${canonical.absolutePath}"
            if (isProtectedAppDirectory(canonical, pending.storageRoot) || excluded(folderId, exclusions)) { skipped++; continue }
            if (!seen.add(canonical.absolutePath)) continue
            val children = try { canonical.listFiles() } catch (_: Exception) { null }
            if (children == null) { errors++; continue }
            for (child in children) {
                if (cancelled.get()) break
                if (++visited > 80000) { limited = true; break }
                val item = try { child.canonicalFile } catch (_: Exception) { child.absoluteFile }
                val id = "raw:${item.absolutePath}"
                if (isProtectedAppDirectory(item, pending.storageRoot) ||
                    isAndroidTrashArtifact(item) || excluded(id, exclusions)) {
                    skipped++
                    continue
                }
                if (item.isDirectory) {
                    queue.add(PendingFolder(item, pending.storageRoot))
                } else if (item.isFile && !snapshot.containsKey(id)) {
                    try { snapshot[id] = rawEntry(item) } catch (_: Exception) { errors++ }
                }
            }
        }
        return mapOf("files" to snapshot.values.map { it.map() }, "errors" to errors,
            "skipped" to skipped, "cancelled" to cancelled.get(), "limited" to limited)
    }

    private fun openEntry(entry: Entry): InputStream? = entry.rawFile?.inputStream()
        ?: contentResolver.openInputStream(entry.uri)

    private fun entryStillMatches(entry: Entry): Boolean {
        val file = entry.rawFile
        if (file != null) {
            return file.exists() && file.isFile && file.length() == entry.size &&
                file.lastModified() == entry.modified
        }
        val current = readEntry(entry.uri, entry.location, entry.parentId, entry.writable)
        return current != null && current.id == entry.id && current.name == entry.name &&
            current.size == entry.size && current.modified == entry.modified
    }

    private fun contentFingerprint(entry: Entry): String? {
        if (!entryStillMatches(entry)) return null
        val expectedSize = entry.size ?: return null
        val digest = MessageDigest.getInstance("SHA-256")
        var readTotal = 0L
        val buffer = ByteArray(1024 * 1024)
        openEntry(entry)?.use { input ->
            while (true) {
                if (cancelled.get()) return null
                val count = input.read(buffer)
                if (count < 0) break
                if (count == 0) continue
                digest.update(buffer, 0, count)
                readTotal += count
            }
        } ?: return null
        if (readTotal != expectedSize || !entryStillMatches(entry)) return null
        return digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    private fun findDuplicates(): Map<String, Any> {
        val sameSize = snapshot.values
            .filter { it.size != null && it.size > 0 }
            .groupBy { it.size!! }
            .values
            .filter { it.size > 1 }
        val fingerprints = mutableMapOf<String, MutableList<Entry>>()
        var errors = 0
        var hashed = 0
        for (sizeGroup in sameSize) {
            for (entry in sizeGroup) {
                if (cancelled.get()) break
                val fingerprint = try { contentFingerprint(entry) } catch (_: Exception) { null }
                if (fingerprint == null) {
                    if (!cancelled.get()) errors++
                    continue
                }
                hashed++
                fingerprints.getOrPut("${entry.size}:$fingerprint") { mutableListOf() }.add(entry)
            }
            if (cancelled.get()) break
        }
        val groups = fingerprints.values
            .filter { it.size > 1 }
            .sortedByDescending { (it.first().size ?: 0L) * (it.size - 1) }
            .map { group -> group.map { it.map() } }
        return mapOf(
            "groups" to groups,
            "hashed" to hashed,
            "errors" to errors,
            "cancelled" to cancelled.get(),
        )
    }

    private fun thumbnail(id: String, maxDimension: Int): Map<String, Any> {
        val entry = snapshot[id] ?: return emptyMap()
        val bitmap = try {
            when {
                entry.mime.startsWith("image/") -> decodeImageThumbnail(entry, maxDimension)
                entry.mime.startsWith("video/") -> decodeVideoThumbnail(entry, maxDimension)
                else -> null
            }
        } catch (_: Exception) { null } ?: return emptyMap()
        return try {
            val output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)
            mapOf("bytes" to output.toByteArray())
        } finally {
            bitmap.recycle()
        }
    }

    private data class CacheClearResult(val bytes: Long, val failures: Int)

    private fun clearCacheEntry(entry: File): CacheClearResult {
        if (entry.isDirectory) {
            var bytes = 0L
            var failures = 0
            val children = entry.listFiles()
            if (children == null) {
                failures++
            } else {
                for (child in children) {
                    val result = clearCacheEntry(child)
                    bytes += result.bytes
                    failures += result.failures
                }
            }
            if (!entry.delete() && entry.exists()) failures++
            return CacheClearResult(bytes, failures)
        }
        val bytes = entry.length()
        return if (entry.delete()) CacheClearResult(bytes, 0) else CacheClearResult(0, 1)
    }

    private fun clearAppCache(): Map<String, Any> {
        var clearedBytes = 0L
        var failures = 0
        val directories = listOfNotNull(cacheDir, externalCacheDir)
        for (directory in directories) {
            for (child in directory.listFiles() ?: emptyArray()) {
                val result = clearCacheEntry(child)
                clearedBytes += result.bytes
                failures += result.failures
            }
        }
        return mapOf("bytes" to clearedBytes, "failures" to failures)
    }

    private fun decodeImageThumbnail(entry: Entry, maxDimension: Int): Bitmap? {
        fun open() = entry.rawFile?.inputStream() ?: contentResolver.openInputStream(entry.uri)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        val boundsInput = open() ?: return null
        boundsInput.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / sample > maxDimension * 2 ||
            bounds.outHeight / sample > maxDimension * 2) sample *= 2
        return open()?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        }
    }

    private fun scaleThumbnail(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val scale = min(1.0, maxDimension.toDouble() / maxOf(bitmap.width, bitmap.height))
        if (scale >= 1.0) return bitmap
        val scaled = Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * scale).toInt().coerceAtLeast(1),
            (bitmap.height * scale).toInt().coerceAtLeast(1),
            true,
        )
        if (scaled !== bitmap) bitmap.recycle()
        return scaled
    }

    private fun decodeVideoThumbnail(entry: Entry, maxDimension: Int): Bitmap? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && entry.rawFile != null) {
            return ThumbnailUtils.createVideoThumbnail(entry.rawFile, Size(maxDimension, maxDimension), null)
        }
        val retriever = MediaMetadataRetriever()
        return try {
            if (entry.rawFile != null) retriever.setDataSource(entry.rawFile.absolutePath)
            else retriever.setDataSource(this, entry.uri)
            retriever.getFrameAtTime(-1)?.let { scaleThumbnail(it, maxDimension) }
        } finally {
            retriever.release()
        }
    }

    private fun delete(
        ids: List<String>,
        duplicateRetainedGroups: List<List<String>>,
    ): Map<String, Any?> {
        val deleted = mutableListOf<String>(); val failed = mutableListOf<String>(); var bytes = 0L
        val exclusions = ignored()
        val requested = ids.distinct()
        val unprotectedGroups = protectedDuplicateGroupsAreIntact(duplicateRetainedGroups, exclusions)
        if (unprotectedGroups.isNotEmpty()) {
            return mapOf(
                "deleted" to emptyList<String>(),
                "failed" to unprotectedGroups,
                "bytes" to 0L,
                "saveWarning" to snapshotWarning,
            )
        }
        beginPendingOperation("permanent deletion", requested)
        for (id in requested) {
            val before = snapshot[id]
            if (before == null) { failed.add("File no longer in scan: $id"); continue }
            try {
                if (before.rawFile != null) {
                    val file = before.rawFile
                    if (excluded(id, exclusions) || !before.deletable || !file.exists() || !file.isFile ||
                        file.length() != before.size || file.lastModified() != before.modified) {
                        failed.add("${before.location}: changed, excluded, or no longer deletable"); continue
                    }
                    if (file.delete()) {
                        deleted.add(id); bytes += before.size ?: 0; snapshot.remove(id)
                    } else failed.add("${before.location}: deletion failed or access was denied")
                    continue
                }
                val now = readEntry(before.uri, before.location, before.parentId, before.writable)
                if (excluded(id, exclusions) || !before.deletable || now == null || !now.deletable ||
                    now.id != before.id || now.name != before.name || now.mime != before.mime ||
                    now.size != before.size || now.modified != before.modified) {
                    failed.add("${before.location}: changed, excluded, or no longer deletable"); continue
                }
                if (DC.deleteDocument(contentResolver, before.uri)) {
                    deleted.add(id); bytes += before.size ?: 0; snapshot.remove(id)
                } else failed.add("${before.location}: provider declined deletion")
            } catch (e: Exception) { failed.add("${before.location}: deletion failed or access lost") }
        }
        persistSnapshot()
        if (snapshotWarning == null) clearPendingOperation()
        return mapOf("deleted" to deleted, "failed" to failed, "bytes" to bytes, "saveWarning" to snapshotWarning)
    }

    override fun onDestroy() {
        cancelled.set(true)
        worker.shutdown()
        thumbnailWorker.shutdown()
        picker?.error("interrupted", "Folder selection interrupted", null)
        picker = null
        pendingTrash?.result?.error("interrupted", "Android Trash request interrupted", null)
        pendingTrash = null
        super.onDestroy()
    }
}
