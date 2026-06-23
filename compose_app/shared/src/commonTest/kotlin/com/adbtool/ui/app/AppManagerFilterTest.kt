package com.adbtool.ui.app

import kotlin.test.Test
import kotlin.test.assertEquals

class AppManagerFilterTest {
    private val apps = listOf(
        AppInfo(
            packageName = "com.android.settings",
            label = "Settings",
            version = "",
            isSystemApp = true,
            installTime = "",
            updateTime = "",
            size = 0
        ),
        AppInfo(
            packageName = "com.example.demo",
            label = "Demo App",
            version = "1.0",
            isSystemApp = false,
            installTime = "",
            updateTime = "",
            size = 1024
        )
    )

    @Test
    fun filtersUserApps() {
        val result = filterApps(apps, FilterType.User, "")

        assertEquals(listOf("com.example.demo"), result.map { it.packageName })
    }

    @Test
    fun filtersSystemApps() {
        val result = filterApps(apps, FilterType.System, "")

        assertEquals(listOf("com.android.settings"), result.map { it.packageName })
    }

    @Test
    fun filtersByPackageOrLabelIgnoringCase() {
        val result = filterApps(apps, FilterType.All, "demo")

        assertEquals(listOf("com.example.demo"), result.map { it.packageName })
    }
}
