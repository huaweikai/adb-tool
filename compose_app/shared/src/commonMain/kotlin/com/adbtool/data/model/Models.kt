package com.adbtool.data.model

data class Device(
    val serial: String,
    val model: String = "",
    val manufacturer: String = "",
    val androidVersion: String = "",
    val sdk: Int = 0,
    val status: DeviceStatus = DeviceStatus.Unknown
) {
    val displayName: String
        get() = model.ifEmpty { serial.takeLast(8) }

    val isConnected: Boolean
        get() = status == DeviceStatus.Online
}

enum class DeviceStatus {
    Online, Offline, Unauthorized, Unknown
}

data class LogEntry(
    val time: String = "",
    val pid: String = "",
    val tid: String = "",
    val priority: String = "",
    val tag: String = "",
    val message: String = "",
    val raw: String = ""
) {
    val isContinuation: Boolean
        get() = time.isEmpty()
}

data class FileItem(
    val name: String,
    val path: String,
    val isDir: Boolean,
    val size: Long = 0,
    val modified: String = "",
    val permissions: String = ""
) {
    val sizeFormatted: String
        get() = when {
            isDir -> ""
            size < 1024 -> "$size B"
            size < 1024 * 1024 -> "${size / 1024} KB"
            size < 1024 * 1024 * 1024 -> "${size / (1024 * 1024)} MB"
            else -> "${size / (1024 * 1024 * 1024)} GB"
        }
}

data class AppInfo(
    val packageName: String,
    val label: String,
    val version: String,
    val isSystemApp: Boolean,
    val installTime: String,
    val updateTime: String,
    val size: Long
) {
    val sizeFormatted: String
        get() = when {
            size < 1024 -> "$size B"
            size < 1024 * 1024 -> "${size / 1024} KB"
            size < 1024 * 1024 * 1024 -> "%.1f MB".format(size / (1024.0 * 1024))
            else -> "%.2f GB".format(size / (1024.0 * 1024 * 1024))
        }
}

data class CommandHistory(
    val id: Long,
    val command: String,
    val output: String,
    val exitCode: Int,
    val duration: Long,
    val timestamp: Long
)

data class ClipboardEntry(
    val id: Long,
    val content: String,
    val timestamp: Long,
    val source: String = "Device"
)

data class DeviceProperty(
    val label: String,
    val value: String
)

data class HighlightRule(
    val id: String,
    val label: String,
    val pattern: String,
    val color: Long,
    val enabled: Boolean = true,
    val builtin: Boolean = false
)

enum class NavItem {
    Status, Logcat, Files, Apps, Info, Clipboard, Command, Session
}

data class QuickCommand(
    val id: String,
    val label: String,
    val command: String,
    val description: String = ""
)
