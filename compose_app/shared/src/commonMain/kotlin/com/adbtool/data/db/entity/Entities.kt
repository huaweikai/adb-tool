package com.adbtool.data.db.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "highlight_rules")
data class HighlightRuleEntity(
    @PrimaryKey
    val id: String,
    val label: String,
    val pattern: String,
    val color: Long,
    val enabled: Boolean = true,
    val builtin: Boolean = false
)

@Entity(tableName = "test_sessions")
data class TestSessionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val deviceSerial: String,
    val name: String,
    val createdAt: Long = System.currentTimeMillis(),
    val endedAt: Long? = null,
    val status: String = "Running"
)

@Entity(tableName = "log_entries")
data class LogEntryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val sessionId: Long,
    val time: String,
    val pid: String,
    val tid: String,
    val priority: String,
    val tag: String,
    val message: String,
    val raw: String
)

@Entity(tableName = "command_history")
data class CommandHistoryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val deviceSerial: String,
    val command: String,
    val output: String,
    val exitCode: Int,
    val duration: Long,
    val timestamp: Long = System.currentTimeMillis()
)

@Entity(tableName = "clipboard_history")
data class ClipboardHistoryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val deviceSerial: String,
    val content: String,
    val source: String = "Device",
    val timestamp: Long = System.currentTimeMillis()
)
