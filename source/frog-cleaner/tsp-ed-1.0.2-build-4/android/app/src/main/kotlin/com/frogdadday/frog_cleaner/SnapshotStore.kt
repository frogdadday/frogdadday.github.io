package com.frogdadday.frog_cleaner

import androidx.core.util.AtomicFile
import java.io.File
import java.io.Writer
import java.io.Reader

/** Call only from the serialized storage worker. An interrupted write keeps the old scan. */
internal class SnapshotStore(file: File) {
    private val atomic = AtomicFile(file)

    fun write(block: (Writer) -> Unit) {
        val output = atomic.startWrite()
        try {
            val writer = output.bufferedWriter(Charsets.UTF_8)
            block(writer)
            writer.flush()
            atomic.finishWrite(output)
        } catch (error: Exception) {
            atomic.failWrite(output)
            throw error
        }
    }

    fun read(block: (Reader) -> Unit) {
        atomic.openRead().bufferedReader(Charsets.UTF_8).use(block)
    }
}
