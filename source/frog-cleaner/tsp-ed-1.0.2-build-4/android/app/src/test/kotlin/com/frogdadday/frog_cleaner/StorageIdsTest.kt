package com.frogdadday.frog_cleaner

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StorageIdsTest {
    @Test
    fun canonicalIdsRemainStableAcrossRestarts() {
        val saved = StorageIds.canonical("primary:Pictures/Keep")
        assertEquals("storage:primary:Pictures/Keep", saved)
        assertEquals(saved, StorageIds.canonical(saved))
        assertEquals(saved, StorageIds.canonical("storage:$saved"))
    }

    @Test
    fun folderExclusionsMatchSafAndRawScansButNotSiblingNames() {
        val exclusion = "primary:Pictures/Keep"
        assertTrue(StorageIds.within("primary:Pictures/Keep/photo.jpg", exclusion))
        assertTrue(StorageIds.within("raw:/storage/emulated/0/Pictures/Keep/photo.jpg", exclusion))
        assertFalse(StorageIds.within("primary:Pictures/Keeper/photo.jpg", exclusion))
    }

    @Test
    fun removableStorageUsesTheSameVolumeIdentity() {
        val exclusion = "1234-5678:Download/Old"
        assertTrue(StorageIds.within("raw:/storage/1234-5678/Download/Old/file.zip", exclusion))
    }
}
