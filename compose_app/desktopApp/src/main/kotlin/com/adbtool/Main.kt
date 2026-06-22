package com.adbtool

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import com.adbtool.i18n.AppLanguage
import com.adbtool.i18n.LocalTranslations
import com.adbtool.i18n.Translations

@Composable
fun AdbToolDesktopApp() {
    val translations = Translations(AppLanguage.CHINESE)

    CompositionLocalProvider(LocalTranslations provides translations) {
        AdbToolRoot(tr = translations)
    }
}

fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        title = "ADB Tool"
    ) {
        AdbToolDesktopApp()
    }
}
