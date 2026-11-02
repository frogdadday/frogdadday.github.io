package com.frogdadday.frog_cleaner

import org.junit.Assert.*
import org.junit.Test

class DetailPanePolicyTest {
    @Test fun appCountUsesCorrectGrammar() {
        assertEquals("0 apps", countedApps(0))
        assertEquals("1 app", countedApps(1))
        assertEquals("2 apps", countedApps(2))
    }

    private fun node(parent: Int, id: String = "", text: String? = null, visible: Boolean = true) =
        DetailPanePolicy.Node(parent, "com.android.settings:id/$id", text, visible)
    private fun scope(nodes: List<DetailPanePolicy.Node>) =
        DetailPanePolicy.scope(nodes, "Chosen app", "com.example.chosen", "com.android.settings")

    @Test fun labelInNavigationDoesNotAuthorizeAnotherAppsControls() {
        val tree = listOf(node(-1), node(0, "list"), node(1, "title", "Chosen app"),
            node(0, "main_content"), node(3, "entity_header_content"),
            node(4, "entity_header_title", "Other app"), node(3, "clear_cache_button", "Clear cache"))
        assertNull(scope(tree))
    }

    @Test fun correctPanelIsScopedByAncestryRegardlessOfScreenGeometry() {
        val tree = listOf(node(-1), node(0, "list"), node(1, "title", "Other app"),
            node(0, "main_content"), node(3, "entity_header_content"),
            node(4, "entity_header_title", "Chosen app"), node(3, "clear_cache_button", "Clear cache"))
        assertEquals(3, scope(tree))
        assertTrue(DetailPanePolicy.contains(tree, 3, 6))
        assertFalse(DetailPanePolicy.contains(tree, 3, 2))
    }

    @Test fun ambiguousOrUnrecognizedPanelsAreRejected() {
        val tree = listOf(node(-1, "main_content"), node(0, "entity_header_content"),
            node(1, "entity_header_title", "Chosen app"), node(0, "entity_header_content"),
            node(3, "entity_header_title", "Other app"))
        assertNull(scope(tree))
        assertNull(scope(listOf(node(-1), node(0, "title", "Chosen app"))))
    }

    @Test fun hiddenHeadersCannotAuthorizeClicks() {
        val tree = listOf(node(-1, "main_content"), node(0, "entity_header_content"),
            node(1, "entity_header_title", "Chosen app", false))
        assertNull(scope(tree))
    }

    @Test fun idlessAndroid16AppInfoRequiresOneTargetAndOneExpectedAction() {
        val tree = listOf(
            DetailPanePolicy.Node(-1, "android:id/content", null, true),
            DetailPanePolicy.Node(0, null, "Chosen app", true),
            DetailPanePolicy.Node(0, null, "Storage & cache", true),
            DetailPanePolicy.Node(0, null, "Force stop", true),
        )
        assertEquals(
            0,
            DetailPanePolicy.scope(
                tree,
                "Chosen app",
                "com.example.chosen",
                "com.android.settings",
                setOf("storage & cache", "storage"),
            ),
        )
    }

    @Test fun idlessFallbackRejectsMissingOrAmbiguousIdentityAndActions() {
        fun fallback(nodes: List<DetailPanePolicy.Node>) = DetailPanePolicy.scope(
            nodes,
            "Chosen app",
            "com.example.chosen",
            "com.android.settings",
            setOf("storage & cache", "storage"),
        )
        assertNull(fallback(listOf(
            DetailPanePolicy.Node(-1, "android:id/content", null, true),
            DetailPanePolicy.Node(0, null, "Chosen app", true),
        )))
        assertNull(fallback(listOf(
            DetailPanePolicy.Node(-1, "android:id/content", null, true),
            DetailPanePolicy.Node(0, null, "Chosen app", true),
            DetailPanePolicy.Node(0, null, "Chosen app", true),
            DetailPanePolicy.Node(0, null, "Storage & cache", true),
        )))
        assertNull(fallback(listOf(
            DetailPanePolicy.Node(-1, "android:id/content", null, true),
            DetailPanePolicy.Node(0, null, "Chosen app", true),
            DetailPanePolicy.Node(0, null, "Storage & cache", true),
            DetailPanePolicy.Node(0, null, "Storage", true),
        )))
    }

    @Test fun idlessFallbackNeverOverridesAnUnrecognizedStructuredPanel() {
        val tree = listOf(
            DetailPanePolicy.Node(-1, "android:id/content", null, true),
            DetailPanePolicy.Node(0, "com.android.settings:id/unknown_panel", null, true),
            DetailPanePolicy.Node(1, null, "Chosen app", true),
            DetailPanePolicy.Node(1, null, "Storage & cache", true),
        )
        assertNull(
            DetailPanePolicy.scope(
                tree,
                "Chosen app",
                "com.example.chosen",
                "com.android.settings",
                setOf("storage & cache", "storage"),
            ),
        )
    }
}
