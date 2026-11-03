package com.frogdadday.easy_camera

import android.Manifest
import android.content.pm.PackageManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

///// Block 1: Legacy Android storage permission rules /////////////////////////

class StoragePermissionRulesTest {
    @Test
    fun androidNineRequiresReadAndWriteForLegacyGallerySaving() {
        assertEquals(
            listOf(
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ),
            requiredPhotoStoragePermissions(28),
        )
    }

    @Test
    fun androidTenAndNewerNeedNoBroadStoragePermission() {
        assertTrue(requiredPhotoStoragePermissions(29).isEmpty())
        assertTrue(requiredPhotoStoragePermissions(36).isEmpty())
    }

    @Test
    fun everyRequestedPermissionMustBeGranted() {
        assertTrue(
            allPermissionResultsGranted(
                2,
                intArrayOf(
                    PackageManager.PERMISSION_GRANTED,
                    PackageManager.PERMISSION_GRANTED,
                ),
            ),
        )
        assertFalse(
            allPermissionResultsGranted(
                2,
                intArrayOf(
                    PackageManager.PERMISSION_GRANTED,
                    PackageManager.PERMISSION_DENIED,
                ),
            ),
        )
        assertFalse(
            allPermissionResultsGranted(
                2,
                intArrayOf(PackageManager.PERMISSION_GRANTED),
            ),
        )
    }
}
