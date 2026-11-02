package com.frogdadday.frog_cleaner

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button

internal fun countedApps(count: Int): String = "$count ${if (count == 1) "app" else "apps"}"

/**
 * A narrow, user-started script that presses only Android Settings' Clear cache control.
 *
 * Do not broaden this automation to Clear storage, Clear data, uninstall, or other
 * controls without a fresh safety, disclosure, privacy, and Play policy review.
 */
class AutoCacheCleanerService : AccessibilityService() {
    companion object {
        private const val PREFS = "cache_automation"
        private var activeService: AutoCacheCleanerService? = null
        private var targets: List<String> = emptyList()
        private var targetIndex = 0
        private var state = State.IDLE

        fun isConnected() = activeService != null
        fun isRunning() = state != State.IDLE

        fun start(packages: List<String>): Boolean {
            val service = activeService ?: return false
            val safePackages = packages.distinct().filter { it != service.packageName }
            if (safePackages.isEmpty() || state != State.IDLE) return false
            targets = safePackages
            targetIndex = 0
            service.requestedCount = 0
            service.skippedCount = 0
            if (!service.showStopControl()) {
                targets = emptyList()
                targetIndex = 0
                state = State.IDLE
                service.persistStatus(
                    running = false,
                    message = "Automatic cache cleaning could not start because its Stop control was unavailable.",
                )
                return false
            }
            service.persistStatus(running = true, message = null)
            service.openCurrentApp()
            return true
        }

        fun stop() {
            activeService?.finishRun("Automatic cache cleaning stopped.", returnToApp = false)
                ?: run {
                    targets = emptyList()
                    targetIndex = 0
                    state = State.IDLE
                }
        }

        fun status(context: Context): Map<String, Any?> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val message = prefs.getString("message", null)
            if (message != null) prefs.edit().remove("message").apply()
            return mapOf(
                "running" to isRunning(),
                "requested" to prefs.getInt("requested", 0),
                "skipped" to prefs.getInt("skipped", 0),
                "total" to prefs.getInt("total", 0),
                "message" to message,
            )
        }

        fun componentName(context: Context) =
            ComponentName(context, AutoCacheCleanerService::class.java)
    }

    private data class Target(val packageName: String, val label: String)
    private enum class State { IDLE, WAITING_FOR_STORAGE, WAITING_FOR_CACHE, ADVANCING }

    private val handler = Handler(Looper.getMainLooper())
    private var currentTarget: Target? = null
    private var settingsPackage: String? = null
    private var scrollAttempts = 0
    private var requestedCount = 0
    private var skippedCount = 0
    private var stopButton: Button? = null

    private val storageLabels = setOf(
        "storage & cache", "storage", "storage usage",
        "speicher und cache", "speicher", "almacenamiento y caché", "almacenamiento",
        "stockage et cache", "stockage", "spazio di archiviazione e cache",
        "spazio di archiviazione", "armazenamento e cache", "armazenamento",
        "opslag en cache", "opslag", "pamięć i pamięć podręczna", "pamięć",
        "хранилище и кеш", "хранилище", "ストレージとキャッシュ", "ストレージ",
        "저장공간 및 캐시", "저장공간", "存储和缓存", "存储空间",
    )
    private val clearCacheLabels = setOf(
        "clear cache", "empty cache", "cache leeren", "borrar caché", "limpiar caché",
        "vider le cache", "cancella cache", "limpar cache", "cache wissen",
        "wyczyść pamięć podręczną", "очистить кеш", "キャッシュを削除",
        "캐시 삭제", "清除缓存",
    )
    private val cacheButtonIds = setOf(
        "com.android.settings:id/clear_cache_button",
        "com.samsung.android.settings:id/clear_cache",
        "com.motorola.android.settings:id/clear_cache",
        "com.miui.securitycenter:id/clear_cache",
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        activeService = this
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 150
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (state == State.IDLE || targets.isEmpty() || !isExpectedSettingsEvent(event)) return
        inspectCurrentSettingsWindow()
    }

    private fun inspectCurrentSettingsWindow() {
        if (state != State.WAITING_FOR_STORAGE && state != State.WAITING_FOR_CACHE) return
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != settingsPackage) return
        val panel = verifiedDetailPanel(root) ?: return
        when (state) {
            State.WAITING_FOR_STORAGE -> {
                if (clickMatching(panel, storageLabels)) {
                    state = State.WAITING_FOR_CACHE
                    scrollAttempts = 0
                    scheduleTimeout()
                } else {
                    tryScroll(panel)
                }
            }
            State.WAITING_FOR_CACHE -> {
                if (clickMatching(panel, clearCacheLabels) || clickMatchingId(panel, cacheButtonIds)) {
                    state = State.ADVANCING
                    requestedCount++
                    persistStatus(running = true, message = null)
                    handler.postDelayed({ advance(success = true) }, 800)
                } else {
                    tryScroll(panel)
                }
            }
            else -> Unit
        }
    }

    private fun pollCurrentSettingsWindow() {
        val stateBeforeInspection = state
        inspectCurrentSettingsWindow()
        if (state == stateBeforeInspection &&
            (state == State.WAITING_FOR_STORAGE || state == State.WAITING_FOR_CACHE)
        ) {
            handler.postDelayed({ pollCurrentSettingsWindow() }, 350)
        }
    }

    override fun onInterrupt() = finishRun("Automatic cache cleaning was interrupted.", true)

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        removeStopControl()
        if (activeService === this) activeService = null
        targets = emptyList()
        targetIndex = 0
        state = State.IDLE
        super.onDestroy()
    }

    private fun isExpectedSettingsEvent(event: AccessibilityEvent?) =
        event?.packageName?.toString() == settingsPackage

    private fun verifiedDetailPanel(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val expected = currentTarget ?: return null
        val owner = settingsPackage ?: return null
        val queue = java.util.ArrayDeque<Pair<AccessibilityNodeInfo, Int>>()
        val actual = mutableListOf<AccessibilityNodeInfo>()
        val nodes = mutableListOf<DetailPanePolicy.Node>()
        queue.add(root to -1)
        while (queue.isNotEmpty()) {
            if (nodes.size >= 600) return null // Incomplete trees cannot establish a unique panel.
            val (node, parent) = queue.removeFirst()
            val index = nodes.size
            actual.add(node)
            nodes.add(DetailPanePolicy.Node(parent, node.viewIdResourceName, node.text?.toString(), node.isVisibleToUser))
            for (child in 0 until node.childCount) {
                node.getChild(child)?.let { queue.add(it to index) }
            }
        }
        val idlessRequiredLabels = if (state == State.WAITING_FOR_STORAGE) storageLabels else emptySet()
        val scope = DetailPanePolicy.scope(
            nodes,
            expected.label,
            expected.packageName,
            owner,
            idlessRequiredLabels,
        ) ?: return null
        return actual[scope]
    }

    private fun clickMatching(root: AccessibilityNodeInfo, labels: Set<String>): Boolean {
        for (label in labels) {
            for (node in root.findAccessibilityNodeInfosByText(label)) {
                val text = node.text?.toString()?.trim()?.lowercase() ?: ""
                if (text == label && clickNodeOrParent(node, root)) return true
            }
        }
        return false
    }

    private fun clickMatchingId(root: AccessibilityNodeInfo, ids: Set<String>): Boolean {
        for (id in ids) {
            for (node in root.findAccessibilityNodeInfosByViewId(id)) {
                if (node.isEnabled && clickNodeOrParent(node, root)) return true
            }
        }
        return false
    }

    private fun clickNodeOrParent(node: AccessibilityNodeInfo?, panel: AccessibilityNodeInfo): Boolean {
        var current = node
        repeat(5) {
            val target = current ?: return false
            if (target == panel || !target.isVisibleToUser || !target.isEnabled) return false
            if (target.isClickable) {
                return target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            current = target.parent
        }
        return false
    }

    private fun tryScroll(root: AccessibilityNodeInfo) {
        if (scrollAttempts >= 3) return
        val queue = java.util.ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            if (node.isVisibleToUser && node.isScrollable && node.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)) {
                scrollAttempts++
                return
            }
            for (index in 0 until node.childCount) node.getChild(index)?.let(queue::add)
        }
    }

    private fun openCurrentApp() {
        handler.removeCallbacksAndMessages(null)
        if (targetIndex >= targets.size) {
            finishRun(
                "Cache cleaning finished: Clear cache pressed for ${countedApps(requestedCount)}, $skippedCount skipped.",
                returnToApp = true,
            )
            return
        }
        val packageName = targets[targetIndex]
        val appInfo = try {
            packageManager.getApplicationInfo(packageName, 0)
        } catch (_: Exception) {
            skippedCount++
            targetIndex++
            openCurrentApp()
            return
        }
        currentTarget = Target(packageName, packageManager.getApplicationLabel(appInfo).toString())
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        settingsPackage = intent.resolveActivity(packageManager)?.packageName
        if (settingsPackage == null) {
            skippedCount++
            targetIndex++
            openCurrentApp()
            return
        }
        state = State.WAITING_FOR_STORAGE
        scrollAttempts = 0
        startActivity(intent)
        scheduleTimeout()
    }

    private fun scheduleTimeout() {
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({
            if (state == State.WAITING_FOR_STORAGE || state == State.WAITING_FOR_CACHE) {
                skippedCount++
                advance(success = false)
            }
        }, 18000)
        // Android 16's Compose-based Settings screens can finish populating
        // after their last accessibility event. Reinspect the same strictly
        // verified hierarchy until the existing timeout instead of guessing.
        handler.postDelayed({ pollCurrentSettingsWindow() }, 350)
    }

    private fun advance(success: Boolean) {
        handler.removeCallbacksAndMessages(null)
        if (!success) persistStatus(running = true, message = null)
        targetIndex++
        openCurrentApp()
    }

    private fun persistStatus(running: Boolean, message: String?) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("running", running)
            .putInt("requested", requestedCount)
            .putInt("skipped", skippedCount)
            .putInt("total", targets.size)
            .apply {
                if (message == null) remove("message") else putString("message", message)
            }
            .apply()
    }

    private fun finishRun(message: String, returnToApp: Boolean) {
        if (state == State.IDLE && targets.isEmpty()) return
        handler.removeCallbacksAndMessages(null)
        state = State.IDLE
        persistStatus(running = false, message = message)
        targets = emptyList()
        targetIndex = 0
        currentTarget = null
        settingsPackage = null
        removeStopControl()
        if (returnToApp) {
            startActivity(Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            })
        }
    }

    private fun showStopControl(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return false
        if (stopButton != null) return true
        val button = Button(this).apply {
            text = "Stop Frog Cleaner"
            contentDescription = "Stop automatic cache cleaning"
            setOnClickListener { finishRun("Automatic cache cleaning stopped.", true) }
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 20
            y = 80
        }
        try {
            (getSystemService(WINDOW_SERVICE) as WindowManager).addView(button, params)
            stopButton = button
            return true
        } catch (_: Exception) {
            stopButton = null
            return false
        }
    }

    private fun removeStopControl() {
        val button = stopButton ?: return
        try {
            (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(button)
        } catch (_: Exception) {
            // The system may already have removed the accessibility overlay.
        }
        stopButton = null
    }
}
