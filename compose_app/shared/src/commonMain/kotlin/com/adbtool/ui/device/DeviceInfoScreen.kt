package com.adbtool.ui.device

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.adbtool.data.model.Device
import com.adbtool.theme.AdbToolColorScheme
import com.adbtool.i18n.stringResource
import com.adbtool.ui.common.EmptyView
import com.adbtool.ui.common.LoadingView

data class DeviceProperty(
    val label: String,
    val value: String,
    val icon: ImageVector? = null
)

@Composable
fun DeviceInfoScreen(
    device: Device? = null,
    properties: List<DeviceProperty> = emptyList(),
    isLoading: Boolean = false,
    selectedDeviceSerial: String? = null,
    onRefresh: () -> Unit = {},
    onReboot: () -> Unit = {},
    onScreenshot: () -> Unit = {},
    onScreenRecord: () -> Unit = {},
    onOpenApps: () -> Unit = {},
    onInstallApk: () -> Unit = {}
) {
    Column(modifier = Modifier.fillMaxSize()) {
        if (selectedDeviceSerial == null || device == null) {
            EmptyView()
        } else {
            DeviceInfoToolbar(device, onRefresh, onReboot, onScreenshot, onScreenRecord, onOpenApps, onInstallApk)

            Box(modifier = Modifier.weight(1f)) {
                when {
                    isLoading -> LoadingView()
                    else -> DeviceInfoContent(device, properties)
                }
            }
        }
    }
}

@Composable
private fun DeviceInfoToolbar(
    device: Device,
    onRefresh: () -> Unit,
    onReboot: () -> Unit,
    onScreenshot: () -> Unit,
    onScreenRecord: () -> Unit,
    onOpenApps: () -> Unit,
    onInstallApk: () -> Unit
) {
    Surface(color = MaterialTheme.colorScheme.surfaceVariant, tonalElevation = 1.dp) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp, 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(modifier = Modifier.size(10.dp).clip(RoundedCornerShape(5.dp)).background(
                if (device.isConnected) AdbToolColorScheme.StatusConnected else AdbToolColorScheme.StatusDisconnected
            ))
            Spacer(Modifier.width(8.dp))
            Text(device.displayName, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
            Spacer(Modifier.width(8.dp))
            Text(device.serial, fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant)

            Spacer(Modifier.weight(1f))

            ActionButton(Icons.Default.Refresh, stringResource("refresh"), onRefresh)
            Spacer(Modifier.width(8.dp))
            ActionButton(Icons.Default.RestartAlt, stringResource("restart"), onReboot)
            Spacer(Modifier.width(8.dp))
            ActionButton(Icons.Default.CameraAlt, stringResource("screenshot"), onScreenshot)
            Spacer(Modifier.width(8.dp))
            ActionButton(Icons.Default.Videocam, "Record", onScreenRecord)
            Spacer(Modifier.width(8.dp))
            ActionButton(Icons.Default.Apps, stringResource("apps"), onOpenApps)
            Spacer(Modifier.width(8.dp))
            ActionButton(Icons.Default.InstallMobile, "APK", onInstallApk)
        }
    }
}

@Composable
private fun ActionButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    FilledTonalButton(onClick = onClick, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(4.dp))
        Text(label, fontSize = 12.sp)
    }
}

@Composable
private fun DeviceInfoContent(device: Device, properties: List<DeviceProperty>) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item { DeviceBasicCard(device) }
        if (properties.isNotEmpty()) {
            item {
                Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(stringResource("device_info"), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(12.dp))
                        properties.chunked(2).forEach { row ->
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                row.forEach { prop ->
                                    PropertyItem(modifier = Modifier.weight(1f), icon = prop.icon, label = prop.label, value = prop.value)
                                }
                                if (row.size == 1) { Spacer(Modifier.weight(1f)) }
                            }
                            if (row != properties.chunked(2).last()) { Spacer(Modifier.height(12.dp)) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DeviceBasicCard(device: Device) {
    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
        Row(modifier = Modifier.fillMaxWidth().padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.size(64.dp).clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.primaryContainer), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.PhoneAndroid, contentDescription = null, modifier = Modifier.size(36.dp), tint = MaterialTheme.colorScheme.primary)
            }
            Spacer(Modifier.width(20.dp))
            Column {
                Text(device.displayName, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(4.dp))
                Text(text = "${device.manufacturer} • Android ${device.androidVersion} (API ${device.sdk})", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatusBadge(text = if (device.isConnected) "Online" else "Offline", color = if (device.isConnected) AdbToolColorScheme.StatusConnected else AdbToolColorScheme.StatusDisconnected)
                    StatusBadge(text = "ADB", color = MaterialTheme.colorScheme.primary)
                }
            }
        }
    }
}

@Composable
private fun StatusBadge(text: String, color: Color) {
    Surface(shape = RoundedCornerShape(6.dp), color = color.copy(alpha = 0.15f)) {
        Text(text = text, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = color, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp))
    }
}

@Composable
private fun PropertyItem(modifier: Modifier = Modifier, icon: ImageVector? = null, label: String, value: String) {
    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
        if (icon != null) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(8.dp))
        }
        Column {
            Text(text = label, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(text = value, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
        }
    }
}
