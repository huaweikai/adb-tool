package com.adbtool.data.repository

import androidx.room.Room
import androidx.sqlite.driver.bundled.BundledSQLiteDriver
import com.adbtool.data.db.AdbToolDatabase
import java.io.File

actual fun createDatabase(): AdbToolDatabase {
    val dbDir = File(System.getProperty("user.home"), ".adb_tool")
    if (!dbDir.exists()) {
        dbDir.mkdirs()
    }

    val dbFile = File(dbDir, "adb_tool.db")

    return Room.databaseBuilder<AdbToolDatabase>(
        name = dbFile.absolutePath
    )
        .setDriver(BundledSQLiteDriver())
        .build()
}
