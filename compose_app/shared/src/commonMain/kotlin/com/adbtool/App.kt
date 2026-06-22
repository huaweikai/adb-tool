package com.adbtool

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import com.adbtool.theme.AdbToolColorScheme
import com.adbtool.theme.AdbToolTypography

private val DarkColorScheme = darkColorScheme(
    primary = AdbToolColorScheme.Primary,
    onPrimary = AdbToolColorScheme.OnPrimary,
    primaryContainer = AdbToolColorScheme.PrimaryContainer,
    onPrimaryContainer = AdbToolColorScheme.OnPrimaryContainer,
    secondary = AdbToolColorScheme.Secondary,
    onSecondary = AdbToolColorScheme.OnSecondary,
    secondaryContainer = AdbToolColorScheme.SecondaryContainer,
    onSecondaryContainer = AdbToolColorScheme.OnSecondaryContainer,
    tertiary = AdbToolColorScheme.Tertiary,
    onTertiary = AdbToolColorScheme.OnTertiary,
    background = AdbToolColorScheme.DarkBackground,
    onBackground = AdbToolColorScheme.DarkOnBackground,
    surface = AdbToolColorScheme.DarkSurface,
    onSurface = AdbToolColorScheme.DarkOnSurface,
    surfaceVariant = AdbToolColorScheme.DarkSurfaceVariant,
    onSurfaceVariant = AdbToolColorScheme.DarkOnSurfaceVariant,
    error = AdbToolColorScheme.Error,
    onError = AdbToolColorScheme.OnError,
    errorContainer = AdbToolColorScheme.ErrorContainer,
    onErrorContainer = AdbToolColorScheme.OnErrorContainer,
    outline = AdbToolColorScheme.DarkOutline,
    outlineVariant = AdbToolColorScheme.DarkOutlineVariant
)

private val LightColorScheme = lightColorScheme(
    primary = AdbToolColorScheme.Primary,
    onPrimary = AdbToolColorScheme.OnPrimary,
    primaryContainer = AdbToolColorScheme.PrimaryContainer,
    onPrimaryContainer = AdbToolColorScheme.OnPrimaryContainer,
    secondary = AdbToolColorScheme.Secondary,
    onSecondary = AdbToolColorScheme.OnSecondary,
    secondaryContainer = AdbToolColorScheme.SecondaryContainer,
    onSecondaryContainer = AdbToolColorScheme.OnSecondaryContainer,
    tertiary = AdbToolColorScheme.Tertiary,
    onTertiary = AdbToolColorScheme.OnTertiary,
    background = AdbToolColorScheme.LightBackground,
    onBackground = AdbToolColorScheme.LightOnBackground,
    surface = AdbToolColorScheme.LightSurface,
    onSurface = AdbToolColorScheme.LightOnSurface,
    surfaceVariant = AdbToolColorScheme.LightSurfaceVariant,
    onSurfaceVariant = AdbToolColorScheme.LightOnSurfaceVariant,
    error = AdbToolColorScheme.Error,
    onError = AdbToolColorScheme.OnError,
    errorContainer = AdbToolColorScheme.ErrorContainer,
    onErrorContainer = AdbToolColorScheme.OnErrorContainer,
    outline = AdbToolColorScheme.LightOutline,
    outlineVariant = AdbToolColorScheme.LightOutlineVariant
)

@Composable
fun AdbToolApp(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AdbToolTypography
    ) {
        content()
    }
}
