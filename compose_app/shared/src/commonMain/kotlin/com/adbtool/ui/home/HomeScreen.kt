package com.adbtool.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.automirrored.filled.ListAlt
import androidx.compose.material.icons.filled.Adb
import androidx.compose.material.icons.filled.Android
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.Brightness6
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.ListAlt
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.WifiTethering
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.adbtool.data.model.Device
import com.adbtool.data.model.NavItem
import com.adbtool.theme.AdbToolColorScheme
import com.adbtool.i18n.Translations

@Composable
fun HomeScreen(
    tr: Translations,
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
    content: @Composable () -> Unit = { WelcomeView(tr) }
) {
    Row(modifier = Modifier.fillMaxSize()) {
        Sidebar(
            tr = tr,
            devices = devices,
            selectedDevice = selectedDevice,
            expandedDevices = expandedDevices,
            currentNavItem = currentNavItem,
            darkTheme = darkTheme,
            onDeviceSelect = onDeviceSelect,
            onDeviceExpand = onDeviceExpand,
            onNavItemSelect = onNavItemSelect,
            onRefresh = onRefresh,
            onWirelessAdb = onWirelessAdb,
            onToggleTheme = onToggleTheme
        )

        Column(modifier = Modifier.weight(1f)) {
            AnimatedVisibility(visible = !backendOnline) {
                OfflineBanner(tr = tr)
            }

            content()
        }
    }
}

@Composable
private fun Sidebar(
    tr: Translations,
    devices: List<Device>,
    selectedDevice: Device?,
    expandedDevices: Set<String>,
    currentNavItem: NavItem?,
    darkTheme: Boolean,
    onDeviceSelect: (Device?) -> Unit,
    onDeviceExpand: (String) -> Unit,
    onNavItemSelect: (NavItem) -> Unit,
    onRefresh: () -> Unit,
    onWirelessAdb: () -> Unit,
    onToggleTheme: () -> Unit
) {
    Surface(
        modifier = Modifier.width(240.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 1.dp
    ) {
        Column(modifier = Modifier.fillMaxHeight()) {
            SidebarHeader(
                tr = tr,
                darkTheme = darkTheme,
                onRefresh = onRefresh,
                onWirelessAdb = onWirelessAdb,
                onToggleTheme = onToggleTheme
            )

            HorizontalDivider()

            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(vertical = 4.dp)
            ) {
                items(devices) { device ->
                    DeviceNode(
                        tr = tr,
                        device = device,
                        isExpanded = expandedDevices.contains(device.serial),
                        isSelected = selectedDevice?.serial == device.serial,
                        currentNavItem = currentNavItem,
                        onExpand = { onDeviceExpand(device.serial) },
                        onSelect = { onDeviceSelect(device) },
                        onNavItemSelect = onNavItemSelect
                    )
                }

                if (devices.isEmpty()) {
                    item {
                        EmptyDeviceView(tr)
                    }
                }
            }

            HorizontalDivider()

            GlobalEntry(
                icon = Icons.Default.Tune,
                label = tr.testConfigCenter,
                badge = "Config",
                onClick = {}
            )

            GlobalEntry(
                icon = Icons.Default.Terminal,
                label = tr.backendLogs,
                badge = "Go",
                onClick = {}
            )
        }
    }
}

@Composable
private fun SidebarHeader(
    tr: Translations,
    darkTheme: Boolean,
    onRefresh: () -> Unit,
    onWirelessAdb: () -> Unit,
    onToggleTheme: () -> Unit
) {
    Column(modifier = Modifier.padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = Icons.Default.Adb,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "ADB Tool",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(modifier = Modifier.weight(1f))
            Surface(
                modifier = Modifier.clip(RoundedCornerShape(6.dp)),
                color = MaterialTheme.colorScheme.surfaceVariant,
                border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
            ) {
                Text(
                    text = if (darkTheme) "EN" else "文",
                    modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp),
                    fontSize = 10.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            HeaderAction(icon = Icons.Default.Sync, label = tr.refresh, onClick = onRefresh)
            HeaderAction(icon = Icons.Default.WifiTethering, label = tr.wirelessAdb, onClick = onWirelessAdb)
            HeaderAction(icon = Icons.Default.Brightness6, label = tr.theme, onClick = onToggleTheme)
        }
    }
}

@Composable
private fun HeaderAction(icon: ImageVector, label: String, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onClick),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(imageVector = icon, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(modifier = Modifier.width(5.dp))
            Text(text = label, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun DeviceNode(
    tr: Translations,
    device: Device,
    isExpanded: Boolean,
    isSelected: Boolean,
    currentNavItem: NavItem?,
    onExpand: () -> Unit,
    onSelect: () -> Unit,
    onNavItemSelect: (NavItem) -> Unit
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.Transparent)
                .clickable(onClick = onExpand)
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (isExpanded) Icons.Default.ExpandMore else Icons.Default.ChevronRight,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(4.dp))
            Box(
                modifier = Modifier.size(8.dp).clip(CircleShape).background(
                    if (device.isConnected) AdbToolColorScheme.StatusConnected else AdbToolColorScheme.StatusDisconnected
                )
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = device.displayName,
                modifier = Modifier.weight(1f),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = if (device.serial.length > 12) "...${device.serial.takeLast(8)}" else device.serial,
                fontSize = 9.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        AnimatedVisibility(visible = isExpanded) {
            Column {
                listOf(
                    NavItem.Status to Icons.Default.PhoneAndroid,
                    NavItem.Logcat to Icons.AutoMirrored.Filled.ListAlt,
                    NavItem.Files to Icons.Default.FolderOpen,
                    NavItem.Apps to Icons.Default.Android,
                    NavItem.Clipboard to Icons.Default.ContentPaste,
                    NavItem.Command to Icons.Default.Terminal,
                    NavItem.Session to Icons.AutoMirrored.Filled.Assignment
                ).forEach { (navItem, icon) ->
                    NavItemEntry(
                        icon = icon,
                        label = when (navItem) {
                            NavItem.Status -> tr.deviceStatus
                            NavItem.Logcat -> tr.logcat
                            NavItem.Files -> tr.files
                            NavItem.Apps -> tr.apps
                            NavItem.Clipboard -> tr.clipboard
                            NavItem.Command -> tr.command
                            NavItem.Session -> tr.testSession
                            else -> ""
                        },
                        isActive = currentNavItem == navItem && isSelected,
                        onClick = { onSelect(); onNavItemSelect(navItem) }
                    )
                }
            }
        }
    }
}

@Composable
private fun NavItemEntry(icon: ImageVector, label: String, isActive: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(if (isActive) MaterialTheme.colorScheme.primaryContainer else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(start = 42.dp, end = 12.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = label,
            fontSize = 12.sp,
            fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
            color = if (isActive) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun GlobalEntry(icon: ImageVector, label: String, badge: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(imageVector = icon, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(modifier = Modifier.width(10.dp))
        Text(text = label, modifier = Modifier.weight(1f), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface)
        Surface(shape = RoundedCornerShape(4.dp), color = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)) {
            Text(text = badge, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp), fontSize = 9.sp)
        }
    }
}

@Composable
private fun EmptyDeviceView(tr: Translations) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.PhoneAndroid,
            contentDescription = null,
            modifier = Modifier.size(40.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(text = tr.noDevices, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = tr.noDevicesHint, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f))
    }
}

@Composable
private fun OfflineBanner(tr: Translations) {
    Surface(color = MaterialTheme.colorScheme.errorContainer, modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(12.dp, 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(imageVector = Icons.Default.CloudOff, contentDescription = null, tint = MaterialTheme.colorScheme.onErrorContainer)
            Spacer(modifier = Modifier.width(8.dp))
            Text(text = tr.backendOffline, modifier = Modifier.weight(1f), fontSize = 12.sp, color = MaterialTheme.colorScheme.onErrorContainer)
            TextButton(onClick = {}) { Text(tr.restart, fontSize = 12.sp) }
        }
    }
}

@Composable
private fun WelcomeView(tr: Translations) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                imageVector = Icons.Default.Android,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(text = tr.welcome, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
