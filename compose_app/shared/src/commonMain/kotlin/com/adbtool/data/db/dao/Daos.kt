package com.adbtool.data.db.dao

import androidx.room.*
import com.adbtool.data.db.entity.*
import kotlinx.coroutines.flow.Flow

@Dao
interface HighlightRuleDao {
    @Query("SELECT * FROM highlight_rules ORDER BY builtin DESC, label ASC")
    fun getAllRules(): Flow<List<HighlightRuleEntity>>

    @Query("SELECT * FROM highlight_rules WHERE enabled = 1")
    fun getEnabledRules(): Flow<List<HighlightRuleEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(rule: HighlightRuleEntity)

    @Update
    suspend fun update(rule: HighlightRuleEntity)

    @Delete
    suspend fun delete(rule: HighlightRuleEntity)

    @Query("DELETE FROM highlight_rules WHERE id = :id")
    suspend fun deleteById(id: String)
}

@Dao
interface TestSessionDao {
    @Query("SELECT * FROM test_sessions ORDER BY createdAt DESC")
    fun getAllSessions(): Flow<List<TestSessionEntity>>

    @Query("SELECT * FROM test_sessions WHERE id = :id")
    suspend fun getSessionById(id: Long): TestSessionEntity?

    @Query("SELECT * FROM test_sessions WHERE status = 'Running' LIMIT 1")
    suspend fun getRunningSession(): TestSessionEntity?

    @Insert
    suspend fun insert(session: TestSessionEntity): Long

    @Update
    suspend fun update(session: TestSessionEntity)

    @Query("UPDATE test_sessions SET status = :status, endedAt = :endedAt WHERE id = :id")
    suspend fun updateStatus(id: Long, status: String, endedAt: Long?)
}

@Dao
interface LogEntryDao {
    @Query("SELECT * FROM log_entries WHERE sessionId = :sessionId ORDER BY id ASC")
    fun getLogsBySession(sessionId: Long): Flow<List<LogEntryEntity>>

    @Insert
    suspend fun insert(log: LogEntryEntity)

    @Insert
    suspend fun insertAll(logs: List<LogEntryEntity>)

    @Query("DELETE FROM log_entries WHERE sessionId = :sessionId")
    suspend fun deleteBySession(sessionId: Long)

    @Query("SELECT COUNT(*) FROM log_entries WHERE sessionId = :sessionId")
    suspend fun getLogCount(sessionId: Long): Int
}

@Dao
interface CommandHistoryDao {
    @Query("SELECT * FROM command_history WHERE deviceSerial = :serial ORDER BY timestamp DESC LIMIT 100")
    fun getHistoryByDevice(serial: String): Flow<List<CommandHistoryEntity>>

    @Insert
    suspend fun insert(command: CommandHistoryEntity): Long

    @Delete
    suspend fun delete(command: CommandHistoryEntity)

    @Query("DELETE FROM command_history WHERE deviceSerial = :serial")
    suspend fun deleteByDevice(serial: String)

    @Query("DELETE FROM command_history")
    suspend fun deleteAll()
}

@Dao
interface ClipboardHistoryDao {
    @Query("SELECT * FROM clipboard_history WHERE deviceSerial = :serial ORDER BY timestamp DESC LIMIT 50")
    fun getHistoryByDevice(serial: String): Flow<List<ClipboardHistoryEntity>>

    @Insert
    suspend fun insert(entry: ClipboardHistoryEntity): Long

    @Delete
    suspend fun delete(entry: ClipboardHistoryEntity)

    @Query("DELETE FROM clipboard_history WHERE deviceSerial = :serial")
    suspend fun deleteByDevice(serial: String)

    @Query("DELETE FROM clipboard_history")
    suspend fun deleteAll()
}
