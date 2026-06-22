package com.adbtool.data.db

import androidx.room.ConstructedBy
import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.RoomDatabaseConstructor
import com.adbtool.data.db.dao.*
import com.adbtool.data.db.entity.*

@Database(
    entities = [
        HighlightRuleEntity::class,
        TestSessionEntity::class,
        LogEntryEntity::class,
        CommandHistoryEntity::class,
        ClipboardHistoryEntity::class
    ],
    version = 1,
    exportSchema = true
)
@ConstructedBy(AdbToolDatabaseConstructor::class)
abstract class AdbToolDatabase : RoomDatabase() {
    abstract fun highlightRuleDao(): HighlightRuleDao
    abstract fun testSessionDao(): TestSessionDao
    abstract fun logEntryDao(): LogEntryDao
    abstract fun commandHistoryDao(): CommandHistoryDao
    abstract fun clipboardHistoryDao(): ClipboardHistoryDao
}

@Suppress("KotlinNoActualForExpect")
expect object AdbToolDatabaseConstructor : RoomDatabaseConstructor<AdbToolDatabase> {
    override fun initialize(): AdbToolDatabase
}
