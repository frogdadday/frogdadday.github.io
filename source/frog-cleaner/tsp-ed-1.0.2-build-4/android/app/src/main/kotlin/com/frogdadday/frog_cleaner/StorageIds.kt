package com.frogdadday.frog_cleaner

internal object StorageIds {
    fun canonical(id: String): String {
        var value = id.replace('\\', '/')
        while (value.startsWith("storage:storage:")) value = value.removePrefix("storage:")
        if (value.startsWith("storage:")) {
            val remainder = value.removePrefix("storage:")
            val volume = remainder.substringBefore(':')
            val relative = remainder.substringAfter(':', "").trimStart('/')
            return "storage:$volume:$relative"
        }
        val path = value.removePrefix("raw:")
        if (value.startsWith("raw:/storage/emulated/0")) {
            return "storage:primary:${path.removePrefix("/storage/emulated/0").trimStart('/')}"
        }
        if (value.startsWith("raw:/storage/")) {
            val relative = path.removePrefix("/storage/")
            val volume = relative.substringBefore('/')
            return "storage:$volume:${relative.substringAfter('/', "")}"
        }
        if (!value.startsWith("raw:") && value.contains(':')) {
            return "storage:${value.substringBefore(':')}:${value.substringAfter(':').trimStart('/')}"
        }
        return value
    }

    fun within(id: String, parent: String): Boolean {
        val item = canonical(id)
        val folder = canonical(parent)
        return item == folder || item.startsWith(if (folder.endsWith(":")) folder else "$folder/")
    }
}
