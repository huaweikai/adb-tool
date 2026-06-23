package com.adbtool.data.remote

import kotlinx.serialization.Serializable

@Serializable
data class ApiResponse<T>(
    val ok: Boolean,
    val data: T? = null,
    val error: String = ""
)

@Serializable
data class BackendDeviceDto(
    val serial: String,
    val state: String = "",
    val model: String = "",
    val brand: String = "",
    val sdk: String = ""
)

@Serializable
data class DeviceDto(
    val serial: String,
    val model: String = "",
    val manufacturer: String = "",
    val androidVersion: String = "",
    val sdk: Int = 0,
    val status: String = "Unknown"
) {
    companion object {
        fun fromBackend(dto: BackendDeviceDto): DeviceDto {
            return DeviceDto(
                serial = dto.serial,
                model = dto.model,
                manufacturer = dto.brand,
                sdk = dto.sdk.toIntOrNull() ?: 0,
                status = when (dto.state) {
                    "device" -> "online"
                    "offline" -> "offline"
                    "unauthorized" -> "unauthorized"
                    else -> "unknown"
                }
            )
        }
    }
}

@Serializable
data class DeviceDetailDataDto(
    val props: Map<String, String> = emptyMap()
)

@Serializable
data class LogEntryDto(
    val time: String = "",
    val pid: String = "",
    val tid: String = "",
    val priority: String = "",
    val tag: String = "",
    val message: String = "",
    val raw: String = ""
)

@Serializable
data class FilesDataDto(
    val files: List<FileItemDto> = emptyList()
)

@Serializable
data class FileItemDto(
    val name: String,
    val path: String,
    val isDir: Boolean,
    val size: Long = 0,
    val modified: String = "",
    val permissions: String = ""
)

@Serializable
data class PackagesDataDto(
    val packages: List<BackendPackageDto> = emptyList()
)

@Serializable
data class BackendPackageDto(
    val packageName: String,
    val sourceDir: String = ""
)

@Serializable
data class AppInfoDto(
    val packageName: String,
    val sourceDir: String = "",
    val label: String = packageName,
    val version: String = "",
    val isSystemApp: Boolean = sourceDir.startsWith("/system"),
    val installTime: String = "",
    val updateTime: String = "",
    val size: Long = 0
) {
    companion object {
        fun fromBackend(dto: BackendPackageDto): AppInfoDto {
            val label = dto.packageName.substringAfterLast('.', dto.packageName)
            return AppInfoDto(
                packageName = dto.packageName,
                sourceDir = dto.sourceDir,
                label = label,
                isSystemApp = dto.sourceDir.startsWith("/system") || dto.sourceDir.startsWith("/product")
            )
        }
    }
}

@Serializable
data class CommandResultDto(
    val command: String,
    val output: String,
    val exitCode: Int,
    val duration: Long
)

@Serializable
data class AdbExecRequest(
    val args: List<String>
)

@Serializable
data class AdbExecDataDto(
    val ok: Boolean = true,
    val output: String = ""
)

@Serializable
data class DeviceInfoDto(
    val serial: String,
    val model: String,
    val manufacturer: String,
    val androidVersion: String,
    val sdk: Int,
    val status: String,
    val properties: Map<String, String> = emptyMap()
) {
    companion object {
        fun fromBackend(serial: String, props: Map<String, String>): DeviceInfoDto {
            return DeviceInfoDto(
                serial = serial,
                model = props["ro.product.model"].orEmpty(),
                manufacturer = props["ro.product.manufacturer"].orEmpty(),
                androidVersion = props["ro.build.version.release"].orEmpty(),
                sdk = props["ro.build.version.sdk"]?.toIntOrNull() ?: 0,
                status = "online",
                properties = props
            )
        }
    }
}

@Serializable
data class LogcatRequest(
    val deviceSerial: String,
    val tag: String = "",
    val priority: String = "D",
    val keyword: String = "",
    val packageName: String = ""
)

@Serializable
data class AdbCommandRequest(
    val deviceSerial: String,
    val command: String
)

data class BackendRequest(
    val method: String,
    val path: String,
    val query: Map<String, String> = emptyMap(),
    val args: List<String> = emptyList()
)

object AdbToolApiContract {
    fun devices(): BackendRequest = BackendRequest(
        method = "GET",
        path = "/api/devices"
    )

    fun deviceDetail(serial: String): BackendRequest = BackendRequest(
        method = "GET",
        path = "/api/device-detail",
        query = mapOf("serial" to serial)
    )

    fun files(serial: String, path: String): BackendRequest = BackendRequest(
        method = "GET",
        path = "/api/files",
        query = mapOf("serial" to serial, "path" to path)
    )

    fun packages(serial: String): BackendRequest = BackendRequest(
        method = "GET",
        path = "/api/packages",
        query = mapOf("serial" to serial)
    )

    fun executeCommand(serial: String, command: String): BackendRequest = BackendRequest(
        method = "POST",
        path = "/api/adb-exec",
        query = mapOf("serial" to serial),
        args = splitCommand(command)
    )

    fun screenshot(serial: String): BackendRequest = BackendRequest(
        method = "GET",
        path = "/api/screenshot",
        query = mapOf("serial" to serial)
    )

    fun readiness(): BackendRequest = BackendRequest(
        method = "GET",
        path = "/api/adb-path"
    )

    private fun splitCommand(command: String): List<String> {
        return command.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
    }
}
