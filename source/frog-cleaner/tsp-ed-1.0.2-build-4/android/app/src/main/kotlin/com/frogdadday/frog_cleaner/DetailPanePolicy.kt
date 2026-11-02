package com.frogdadday.frog_cleaner

/** Pure hierarchy rules: screen coordinates and device size never establish app identity. */
internal object DetailPanePolicy {
    data class Node(val parent: Int, val resourceId: String?, val text: String?, val visible: Boolean)
    private val containers = setOf("recycler_view", "list", "prefs_container", "main_content", "content_frame")
    private val headers = setOf("entity_header", "entity_header_content")

    fun contains(nodes: List<Node>, scope: Int, child: Int): Boolean {
        var index = child
        repeat(nodes.size) {
            if (index == scope) return true
            if (index !in nodes.indices) return false
            index = nodes[index].parent
        }
        return false
    }

    fun scope(
        nodes: List<Node>,
        label: String,
        appPackage: String,
        settingsPackage: String,
        idlessRequiredLabels: Set<String> = emptySet(),
    ): Int? {
        fun id(index: Int): String? {
            val value = nodes[index].resourceId ?: return null
            if (!value.startsWith("$settingsPackage:id/") && !value.startsWith("android:id/")) return null
            return value.substringAfter(":id/")
        }
        val titles = nodes.indices.filter { nodes[it].visible && id(it) == "entity_header_title" }
        val expected = setOf(label.trim(), appPackage)
        val candidates = titles.filter { nodes[it].text?.trim() in expected }.mapNotNull { title ->
            var ancestor = nodes[title].parent
            var foundHeader = false
            var scope: Int? = null
            repeat(nodes.size) {
                if (ancestor !in nodes.indices || scope != null) return@repeat
                val name = id(ancestor)
                if (name in headers) foundHeader = true
                if (foundHeader && name in containers) scope = ancestor
                ancestor = nodes[ancestor].parent
            }
            scope?.takeIf { panel -> titles.count { contains(nodes, panel, it) } == 1 }
        }.distinct()
        candidates.singleOrNull()?.let { return it }

        // Android 16's Compose-based App Info screen can expose no Settings
        // resource IDs at all. Permit that exact hierarchy only when it has a
        // single trusted android:id/content root, one exact target-app label,
        // and one expected App Info action. The next Storage screen exposes
        // normal IDs again and continues through the stricter path above.
        if (idlessRequiredLabels.isEmpty()) return null
        if (nodes.any { it.resourceId?.startsWith("$settingsPackage:id/") == true }) return null
        val contentScopes = nodes.indices.filter { id(it) == "content" }
        val contentScope = contentScopes.singleOrNull() ?: return null
        val matchingTitles = nodes.indices.filter {
            nodes[it].visible && contains(nodes, contentScope, it) && nodes[it].text?.trim() in expected
        }
        if (matchingTitles.size != 1) return null
        val normalizedActions = idlessRequiredLabels.map { it.trim().lowercase() }.toSet()
        val matchingActions = nodes.indices.filter {
            nodes[it].visible &&
                contains(nodes, contentScope, it) &&
                nodes[it].text?.trim()?.lowercase() in normalizedActions
        }
        return contentScope.takeIf { matchingActions.size == 1 }
    }
}
