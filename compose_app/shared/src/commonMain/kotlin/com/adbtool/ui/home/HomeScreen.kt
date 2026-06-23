package com.adbtool.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.automirrored.filled.ListAlt
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.adbtool.data.model.Device
import com.adbtool.data.model.NavItem
import com.adbtool.i18n.stringResource

@Composable
fun HomeScreen(
    devices: List<Device> = emptyList(),
    selectedDevice: Device? = null,
    expandedDevices: Set<String> = emptySet(),
    currentNavItem: NavItem? = null,
    backendOnline: Boolean = false,
    darkTheme: Boolean = true,
    onDeviceSelect: (Device?) -> Unit = {},
    onDeviceExpand: (String) -> Unit = {},
    onNavItemSelect: (NavItem) -> Unit = {},
    onRefresh: () -> Unit = {},
    onWirelessAdb: () -> Unit = {},
    onToggleTheme: () -> Unit = {},
    content: @Composable () -> Unit = { WelcomeView() }
) {
    Row(modifier = Modifier.fillMaxSize()) {
        Sidebar(
            devices = devices,
            selectedDevice = selectedDevice,
            expandedDevices = expandedDevices,
            currentNavItem = currentNavItem,
            backendOnline = backendOnline,
            onDeviceSelect = onDeviceSelect,
            onDeviceExpand = onDeviceExpand,
            onNavItemSelect = onNavItemSelect,
            onRefresh = onRefresh,
            onToggleTheme = onToggleTheme,
            modifier = Modifier.width(240.dp)
        )
        Box(modifier = Modifier.weight(1f).fillMaxHeight()) {
            content()
        }
    }
}

@Composable
private fun Sidebar(
    devices: List<Device>,
    selectedDevice: Device?,
    expandedDevices: Set<String>,
    currentNavItem: NavItem?,
    backendOnline: Boolean,
    onDeviceSelect: (Device?) -> Unit,
    onDeviceExpand: (String) -> Unit,
    onNavItemSelect: (NavItem) -> Unit,
    onRefresh: () -> Unit,
    onToggleTheme: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier.fillMaxHeight()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "ADB Tool",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Row {
                IconButton(onClick = onRefresh) {
                    Icon(Icons.Default.Sync, contentDescription = stringResource("refresh"))
                }
                IconButton(onClick = onToggleTheme) {
                    Icon(Icons.Default.Brightness6, contentDescription = stringResource("theme"))
                }
            }
        }
        HorizontalDivider()
        LazyColumn(modifier = Modifier.weight(1f)) {
            if (!backendOnline) {
                item { OfflineBanner() }
            }
            items(NavItem.entries) { item ->
                NavItemRow(
                    item = item,
                    selected = currentNavItem == item,
                    onClick = { onNavItemSelect(item) }
                )
            }
            if (devices.isEmpty() && backendOnline) {
                item { EmptyDeviceView() }
            }
            items(devices, key = { it.serial }) { device ->
                DeviceItem(
                    device = device,
                    expanded = expandedDevices.contains(device.serial),
                    selected = selectedDevice?.serial == device.serial,
                    onClick = { onDeviceSelect(device) },
                    onExpand = { onDeviceExpand(device.serial) },
                    currentNavItem = currentNavItem,
                    onNavItemSelect = onNavItemSelect
                )
            }
        }
    }
}

@Composable
private fun OfflineBanner() {
    Card(
        modifier = Modifier.fillMaxWidth().padding(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
    ) {
        Row(
            modifier = Modifier.padding(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.CloudOff, contentDescription = null, tint = MaterialTheme.colorScheme.error)
            Spacer(Modifier.width(8.dp))
            Text(
                text = stringResource("backend_offline"),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onErrorContainer
            )
        }
    }
}

@Composable
private fun NavItemRow(item: NavItem, selected: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        color = if (selected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(item.icon, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(12.dp))
            Text(text = item.navTitle(), style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun NavItem.navTitle(): String = when (this) {
    NavItem.Status -> stringResource("device_status")
    NavItem.Apps -> stringResource("apps")
    NavItem.Files -> stringResource("files")
    NavItem.Logcat -> stringResource("logcat")
    NavItem.Command -> stringResource("command")
    NavItem.Session -> stringResource("test_session")
    NavItem.Clipboard -> stringResource("clipboard")
    NavItem.Info -> stringResource("device_info")
}

private val NavItem.icon get(): androidx.compose.ui.graphics.vector.ImageVector = when (this) {
    NavItem.Status -> Icons.Default.Info
    NavItem.Apps -> Icons.Default.Apps
    NavItem.Files -> Icons.Default.FolderOpen
    NavItem.Logcat -> Icons.AutoMirrored.Filled.ListAlt
    NavItem.Command -> Icons.Default.Terminal
    NavItem.Session -> Icons.AutoMirrored.Filled.Assignment
    NavItem.Clipboard -> Icons.Default.ContentPaste
    NavItem.Info -> Icons.Default.Info
}

@Composable
private fun EmptyDeviceView() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            Icons.Default.PhoneAndroid,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource("no_devices"),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = stringResource("no_devices_hint"),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun DeviceItem(
    device: Device,
    expanded: Boolean,
    selected: Boolean,
    onClick: () -> Unit,
    onExpand: () -> Unit,
    currentNavItem: NavItem?,
    onNavItemSelect: (NavItem) -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Surface(
            modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
            color = if (selected) MaterialTheme.colorScheme.secondaryContainer else Color.Transparent
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier.size(8.dp).clip(CircleShape).background(
                        if (device.isConnected) Color(0xFF4CAF50) else Color(0xFF9E9E9E)
                    )
                )
                Spacer(Modifier.width(8.dp))
                Icon(Icons.Default.Android, contentDescription = null, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = device.model.ifEmpty { device.serial },
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = device.serial,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                IconButton(onClick = onExpand, modifier = Modifier.size(24.dp)) {
                    Icon(Icons.Default.ExpandMore, contentDescription = null, modifier = Modifier.size(16.dp))
                }
            }
        }
        AnimatedVisibility(visible = expanded) {
            Column(modifier = Modifier.padding(start = 40.dp)) {
                NavItem.entries.forEach { item ->
                    val itemSelected = selected && currentNavItem == item
                    Surface(
                        modifier = Modifier.fillMaxWidth().clickable { onNavItemSelect(item) },
                        color = if (itemSelected)
                            MaterialTheme.colorScheme.tertiaryContainer else Color.Transparent
                    ) {
                        Row(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                            Icon(item.icon, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(text = item.navTitle(), style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun WelcomeView() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Default.Adb,
                contentDescription = null,
                modifier = Modifier.size(80.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Spacer(Modifier.height(16.dp))
            Text(
                text = stringResource("app_welcome"),
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource("select_device_hint"),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
