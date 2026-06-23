package com.adbtool.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Launch
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.adbtool.theme.AdbToolColorScheme
import com.adbtool.ui.common.EmptyView
import com.adbtool.i18n.stringResource
import com.adbtool.ui.common.ErrorView
import com.adbtool.ui.common.LoadingView

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

enum class FilterType { All, User, System }

fun filterApps(
    apps: List<AppInfo>,
    filterType: FilterType,
    searchQuery: String
): List<AppInfo> {
    val query = searchQuery.trim().lowercase()
    return apps.filter { app ->
        val matchesType = when (filterType) {
            FilterType.All -> true
            FilterType.User -> !app.isSystemApp
            FilterType.System -> app.isSystemApp
        }
        val matchesQuery = query.isBlank() ||
            app.packageName.lowercase().contains(query) ||
            app.label.lowercase().contains(query)
        matchesType && matchesQuery
    }
}

@Composable
fun AppManagerScreen(
    apps: List<AppInfo> = emptyList(),
    isLoading: Boolean = false,
    error: String? = null,
    filterType: FilterType = FilterType.All,
    searchQuery: String = "",
    selectedDeviceSerial: String? = null,
    onFilterChange: (FilterType) -> Unit = {},
    onSearchChange: (String) -> Unit = {},
    onAppClick: (AppInfo) -> Unit = {},
    onAppLongClick: (AppInfo) -> Unit = {},
    onLaunch: (AppInfo) -> Unit = {},
    onStop: (AppInfo) -> Unit = {},
    onUninstall: (AppInfo) -> Unit = {},
    onRefresh: () -> Unit = {}
) {
    Column(modifier = Modifier.fillMaxSize()) {
        if (selectedDeviceSerial == null) {
            EmptyView()
        } else {
            AppToolbar(filterType, searchQuery, apps.size, onFilterChange, onSearchChange, onRefresh)

            Box(modifier = Modifier.weight(1f)) {
                when {
                    isLoading -> LoadingView()
                    error != null -> ErrorView(error, onRefresh)
                    apps.isEmpty() -> EmptyAppsView()
                    else -> AppList(apps, onAppClick, onAppLongClick, onLaunch, onStop, onUninstall)
                }
            }
        }
    }
}

@Composable
private fun AppToolbar(
    filterType: FilterType,
    searchQuery: String,
    appCount: Int,
    onFilterChange: (FilterType) -> Unit,
    onSearchChange: (String) -> Unit,
    onRefresh: () -> Unit
) {
    Surface(color = MaterialTheme.colorScheme.surfaceVariant, tonalElevation = 1.dp) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp, 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = onSearchChange,
                label = { Text(stringResource("keyword"), fontSize = 12.sp) },
                modifier = Modifier.width(250.dp),
                textStyle = LocalTextStyle.current.copy(fontSize = 12.sp),
                singleLine = true,
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(18.dp)) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { onSearchChange("") }) {
                            Icon(Icons.Default.Clear, contentDescription = null, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            )

            Spacer(Modifier.width(16.dp))

            FilterChip(selected = filterType == FilterType.All, onClick = { onFilterChange(FilterType.All) }, label = { Text("${stringResource("filter_all")} ($appCount)", fontSize = 11.sp) })
            Spacer(Modifier.width(8.dp))
            FilterChip(selected = filterType == FilterType.User, onClick = { onFilterChange(FilterType.User) }, label = { Text(stringResource("apps_user"), fontSize = 11.sp) })
            Spacer(Modifier.width(8.dp))
            FilterChip(selected = filterType == FilterType.System, onClick = { onFilterChange(FilterType.System) }, label = { Text(stringResource("apps_system"), fontSize = 11.sp) })

            Spacer(Modifier.weight(1f))

            IconButton(onClick = onRefresh) {
                Icon(Icons.Default.Refresh, contentDescription = stringResource("refresh"), modifier = Modifier.size(20.dp))
            }
        }
    }
}

@Composable
private fun AppList(
    apps: List<AppInfo>,
    onAppClick: (AppInfo) -> Unit,
    onAppLongClick: (AppInfo) -> Unit,
    onLaunch: (AppInfo) -> Unit,
    onStop: (AppInfo) -> Unit,
    onUninstall: (AppInfo) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        items(apps, key = { it.packageName }) { app ->
            AppListItem(app, onAppClick, onAppLongClick, onLaunch, onStop, onUninstall)
        }
    }
}

@Composable
private fun AppListItem(
    app: AppInfo,
    onClick: (AppInfo) -> Unit,
    onLongClick: (AppInfo) -> Unit,
    onLaunch: (AppInfo) -> Unit,
    onStop: (AppInfo) -> Unit,
    onUninstall: (AppInfo) -> Unit
) {
    var showMenu by remember { mutableStateOf(false) }

    Card(
        modifier = Modifier.fillMaxWidth().combinedClickable(onClick = { onClick.invoke(app) }, onLongClick = { onLongClick.invoke(app) }),
        shape = RoundedCornerShape(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.Android, contentDescription = null, modifier = Modifier.size(24.dp), tint = MaterialTheme.colorScheme.primary)
            }

            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(text = app.label, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(2.dp))
                Text(text = app.packageName, fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(4.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (app.isSystemApp) { AppBadge("System", AdbToolColorScheme.StatusWarning) }
                    AppBadge(app.version, MaterialTheme.colorScheme.primary)
                    AppBadge(app.sizeFormatted, MaterialTheme.colorScheme.secondary)
                }
            }

            Box {
                IconButton(onClick = { showMenu = true }) {
                    Icon(Icons.Default.MoreVert, contentDescription = null)
                }

                DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                    DropdownMenuItem(
                        text = { Text("Launch", fontSize = 12.sp) },
                        onClick = { onLaunch(app); showMenu = false },
                        leadingIcon = { Icon(Icons.AutoMirrored.Filled.Launch, contentDescription = null, modifier = Modifier.size(18.dp)) }
                    )
                    DropdownMenuItem(
                        text = { Text("Stop", fontSize = 12.sp) },
                        onClick = { onStop(app); showMenu = false },
                        leadingIcon = { Icon(Icons.Default.Stop, contentDescription = null, modifier = Modifier.size(18.dp)) }
                    )
                    if (!app.isSystemApp) {
                        DropdownMenuItem(
                            text = { Text(stringResource("delete"), fontSize = 12.sp, color = MaterialTheme.colorScheme.error) },
                            onClick = { onUninstall(app); showMenu = false },
                            leadingIcon = { Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.error) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AppBadge(text: String, color: Color) {
    Surface(shape = RoundedCornerShape(4.dp), color = color.copy(alpha = 0.15f)) {
        Text(text = text, fontSize = 10.sp, color = color, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp))
    }
}

@Composable
private fun EmptyAppsView() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.Apps, contentDescription = null, modifier = Modifier.size(48.dp), tint = Color.Gray)
            Spacer(Modifier.height(12.dp))
            Text(stringResource("select_device"), color = Color.Gray)
        }
    }
}
