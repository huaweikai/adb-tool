package com.adbtool.data.repository

import com.adbtool.data.db.AdbToolDatabase
import com.adbtool.data.db.entity.*
import com.adbtool.data.model.*
import com.adbtool.data.remote.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class DeviceRepository(
    private val api: AdbToolApiClient,
    private val database: AdbToolDatabase
) {
    suspend fun isBackendReady(): Boolean {
        return api.checkHealth().isSuccess
    }

    suspend fun getDevices(): Result<List<Device>> {
        return api.getDevices().map { dtos ->
            dtos.map { dto ->
                Device(
                    serial = dto.serial,
                    model = dto.model,
                    manufacturer = dto.manufacturer,
                    androidVersion = dto.androidVersion,
                    sdk = dto.sdk,
                    status = when (dto.status) {
                        "online" -> DeviceStatus.Online
                        "offline" -> DeviceStatus.Offline
                        "unauthorized" -> DeviceStatus.Unauthorized
                        else -> DeviceStatus.Unknown
                    }
                )
            }
        }
    }

    suspend fun getDeviceInfo(serial: String): Result<Pair<Device, List<DeviceProperty>>> {
        return api.getDeviceInfo(serial).map { dto ->
            val device = Device(
                serial = dto.serial,
                model = dto.model,
                manufacturer = dto.manufacturer,
                androidVersion = dto.androidVersion,
                sdk = dto.sdk,
                status = when (dto.status) {
                    "online" -> DeviceStatus.Online
                    else -> DeviceStatus.Offline
                }
            )
            val properties = dto.properties.map { (key, value) ->
                DeviceProperty(label = key, value = value)
            }
            device to properties
        }
    }

    suspend fun screenshot(serial: String): Result<ByteArray> {
        return api.screenshot(serial)
    }
}

class FileRepository(
    private val api: AdbToolApiClient
) {
    suspend fun getFiles(serial: String, path: String): Result<List<FileItem>> {
        return api.getFiles(serial, path).map { dtos ->
            dtos.map { dto ->
                FileItem(
                    name = dto.name,
                    path = dto.path,
                    isDir = dto.isDir,
                    size = dto.size,
                    modified = dto.modified,
                    permissions = dto.permissions
                )
            }
        }
    }
}

class AppRepository(
    private val api: AdbToolApiClient
) {
    suspend fun getApps(serial: String): Result<List<AppInfo>> {
        return api.getApps(serial).map { dtos ->
            dtos.map { dto ->
                AppInfo(
                    packageName = dto.packageName,
                    label = dto.label,
                    version = dto.version,
                    isSystemApp = dto.isSystemApp,
                    installTime = dto.installTime,
                    updateTime = dto.updateTime,
                    size = dto.size
                )
            }
        }
    }

    suspend fun launchApp(serial: String, packageName: String): Result<Unit> {
        return api.launchApp(serial, packageName)
    }

    suspend fun stopApp(serial: String, packageName: String): Result<Unit> {
        return api.stopApp(serial, packageName)
    }

    suspend fun uninstallApp(serial: String, packageName: String): Result<Unit> {
        return api.uninstallApp(serial, packageName)
    }
}

class CommandRepository(
    private val api: AdbToolApiClient,
    private val database: AdbToolDatabase
) {
    fun getHistory(serial: String): Flow<List<CommandHistory>> {
        return database.commandHistoryDao().getHistoryByDevice(serial).map { entities ->
            entities.map { entity ->
                CommandHistory(
                    id = entity.id,
                    command = entity.command,
                    output = entity.output,
                    exitCode = entity.exitCode,
                    duration = entity.duration,
                    timestamp = entity.timestamp
                )
            }
        }
    }

    suspend fun executeAndSave(serial: String, command: String): Result<CommandHistory> {
        val result = api.executeCommand(serial, command)
        return result.map { dto ->
            val entity = CommandHistoryEntity(
                deviceSerial = serial,
                command = dto.command,
                output = dto.output,
                exitCode = dto.exitCode,
                duration = dto.duration
            )
            val id = database.commandHistoryDao().insert(entity)
            CommandHistory(
                id = id,
                command = dto.command,
                output = dto.output,
                exitCode = dto.exitCode,
                duration = dto.duration,
                timestamp = System.currentTimeMillis()
            )
        }
    }

    suspend fun deleteHistory(history: CommandHistory) {
        database.commandHistoryDao().delete(
            CommandHistoryEntity(
                id = history.id,
                deviceSerial = "",
                command = history.command,
                output = history.output,
                exitCode = history.exitCode,
                duration = history.duration,
                timestamp = history.timestamp
            )
        )
    }

    suspend fun clearHistory() {
        database.commandHistoryDao().deleteAll()
    }
}

class ClipboardRepository(
    private val api: AdbToolApiClient,
    private val database: AdbToolDatabase
) {
    fun getHistory(serial: String): Flow<List<ClipboardEntry>> {
        return database.clipboardHistoryDao().getHistoryByDevice(serial).map { entities ->
            entities.map { entity ->
                ClipboardEntry(
                    id = entity.id,
                    content = entity.content,
                    timestamp = entity.timestamp,
                    source = entity.source
                )
            }
        }
    }

    suspend fun pushToDevice(serial: String, text: String): Result<Unit> {
        val result = api.pushClipboard(serial, text)
        if (result.isSuccess) {
            database.clipboardHistoryDao().insert(
                ClipboardHistoryEntity(
                    deviceSerial = serial,
                    content = text,
                    source = "Computer"
                )
            )
        }
        return result
    }

    suspend fun pullFromDevice(serial: String): Result<String> {
        return api.pullClipboard(serial)
    }

    suspend fun deleteEntry(entry: ClipboardEntry) {
        database.clipboardHistoryDao().delete(
            ClipboardHistoryEntity(
                id = entry.id,
                deviceSerial = "",
                content = entry.content,
                source = entry.source,
                timestamp = entry.timestamp
            )
        )
    }
}

class HighlightRuleRepository(
    private val database: AdbToolDatabase
) {
    fun getAllRules(): Flow<List<HighlightRule>> {
        return database.highlightRuleDao().getAllRules().map { entities ->
            entities.map { entity ->
                HighlightRule(
                    id = entity.id,
                    label = entity.label,
                    pattern = entity.pattern,
                    color = entity.color,
                    enabled = entity.enabled,
                    builtin = entity.builtin
                )
            }
        }
    }

    fun getEnabledRules(): Flow<List<HighlightRule>> {
        return database.highlightRuleDao().getEnabledRules().map { entities ->
            entities.map { entity ->
                HighlightRule(
                    id = entity.id,
                    label = entity.label,
                    pattern = entity.pattern,
                    color = entity.color,
                    enabled = entity.enabled,
                    builtin = entity.builtin
                )
            }
        }
    }

    suspend fun addRule(rule: HighlightRule) {
        database.highlightRuleDao().insert(
            HighlightRuleEntity(
                id = rule.id,
                label = rule.label,
                pattern = rule.pattern,
                color = rule.color,
                enabled = rule.enabled,
                builtin = rule.builtin
            )
        )
    }

    suspend fun updateRule(rule: HighlightRule) {
        database.highlightRuleDao().update(
            HighlightRuleEntity(
                id = rule.id,
                label = rule.label,
                pattern = rule.pattern,
                color = rule.color,
                enabled = rule.enabled,
                builtin = rule.builtin
            )
        )
    }

    suspend fun deleteRule(ruleId: String) {
        database.highlightRuleDao().deleteById(ruleId)
    }
}
