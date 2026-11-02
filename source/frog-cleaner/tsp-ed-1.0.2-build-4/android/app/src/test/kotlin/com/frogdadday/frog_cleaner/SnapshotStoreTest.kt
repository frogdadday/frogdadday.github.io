package com.frogdadday.frog_cleaner

import androidx.core.util.AtomicFile
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException

class SnapshotStoreTest {
    @get:Rule val temporary = TemporaryFolder()
    private fun read(file: File): String {
        var text = ""
        SnapshotStore(file).read { text = it.readText() }
        return text
    }

    @Test fun failedReplacementPreservesThePreviousScan() {
        val file = File(temporary.root, "scan")
        val store = SnapshotStore(file)
        store.write { it.write("original scan") }
        try {
            store.write { it.write("incomplete replacement"); throw IOException("simulated full disk") }
            fail("Failure must be reported to the caller")
        } catch (_: IOException) { }
        assertEquals("original scan", read(file))
    }

    @Test fun interruptedWriteIsRecoveredOnReopening() {
        val file = File(temporary.root, "scan")
        SnapshotStore(file).write { it.write("previous scan") }
        // Simulate process death after writing part of the new file but before committing.
        AtomicFile(file).startWrite().use { it.write("partial".toByteArray()) }
        assertEquals("previous scan", read(file))
    }

    @Test fun metadataAndFilesCommitTogetherAndKeepTheOriginalDate() {
        val file = File(temporary.root, "scan")
        val header = "{\"scannedAt\":12345,\"cancelled\":true,\"limited\":false}\n"
        SnapshotStore(file).write { it.write(header + "one\ntwo\n") }
        SnapshotStore(file).write { it.write(header + "two\n") }
        assertEquals(header + "two\n", read(file))
    }
}
