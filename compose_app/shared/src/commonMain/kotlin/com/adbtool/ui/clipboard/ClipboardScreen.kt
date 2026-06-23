package com.adbtool.ui.clipboard

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import com.adbtool.i18n.stringResource
import java.util.*

data class ClipboardEntry(
    val id: Long,
    val content: String,
    val timestamp: Long,
    val source: String = "Device"
)

@Composable
fun ClipboardScreen(
    entries: List<ClipboardEntry> = emptyList(),
    isLoading: Boolean = false,
    deviceClipboard: String = "",
    computerClipboard: String = "",
    selectedDeviceSerial: String? = null,
    onPushToDevice: (String) -> Unit = {},
    onPullFromDevice: () -> Unit = {},
    onCopyToComputer: (String) -> Unit = {},
    onDelete: (ClipboardEntry) -> Unit = {},
    onClearHistory: () -> Unit = {}
) {
    var textToSend by remember { mutableStateOf("") }

    Column(modifier = Modifier.fillMaxSize()) {
        if (selectedDeviceSerial == null) {
            EmptyView()
        } else {
            ClipboardToolbar(entries.isNotEmpty(), onPullFromDevice, onClearHistory)

            Row(
                modifier = Modifier.weight(1f).fillMaxWidth().padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(stringResource("clipboard"), style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(8.dp))
                    Text(deviceClipboard.ifEmpty { "(empty)" }, fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = if (deviceClipboard.isEmpty()) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text("Computer Clipboard", style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(8.dp))
                    Text(computerClipboard.ifEmpty { "(empty)" }, fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = if (computerClipboard.isEmpty()) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                }
            }

            HorizontalDivider()

            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = textToSend,
                    onValueChange = { textToSend = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Text to push to device") },
                    textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace, fontSize = 13.sp),
                    maxLines = 3
                )
                Spacer(Modifier.width(12.dp))
                FilledTonalButton(
                    onClick = { if (textToSend.isNotEmpty()) { onPushToDevice(textToSend); textToSend = "" } },
                    enabled = textToSend.isNotEmpty()
                ) {
                    Icon(Icons.Filled.PushPin, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Push")
                }
                Spacer(Modifier.width(8.dp))
                OutlinedButton(onClick = onPullFromDevice) {
                    Icon(Icons.Filled.QrCodeScanner, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Pull")
                }
            }

            HorizontalDivider()

            Text("History", style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(16.dp, 12.dp, 16.dp, 8.dp))

            if (entries.isEmpty()) {
                Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Text("No clipboard history", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } else {
                LazyColumn(modifier = Modifier.weight(1f), contentPadding = PaddingValues(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(entries, key = { it.id }) { entry ->
                        ClipboardHistoryItem(entry, onCopy = { onCopyToComputer(entry.content) }, onDelete = { onDelete(entry) })
                    }
                }
            }
        }
    }
}

@Composable
private fun ClipboardToolbar(hasHistory: Boolean, onPullFromDevice: () -> Unit, onClearHistory: () -> Unit) {
    Surface(color = MaterialTheme.colorScheme.surfaceVariant, tonalElevation = 1.dp) {
        Row(modifier = Modifier.fillMaxWidth().padding(12.dp, 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.ContentPaste, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(stringResource("clipboard"), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.weight(1f))
            if (hasHistory) {
                OutlinedButton(onClick = onClearHistory, contentPadding = PaddingValues(horizontal = 12.dp)) {
                    Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(stringResource("clear"), fontSize = 12.sp)
                }
            }
        }
    }
}

@Composable
private fun ClipboardHistoryItem(entry: ClipboardEntry, onCopy: () -> Unit, onDelete: () -> Unit) {
    val dateFormat = remember { SimpleDateFormat("HH:mm:ss", Locale.getDefault()) }

    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(8.dp)) {
        Row(modifier = Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.Top) {
            Column(modifier = Modifier.weight(1f)) {
                SelectionContainer {
                    Text(text = entry.content, fontSize = 12.sp, fontFamily = FontFamily.Monospace, maxLines = 3)
                }
                Spacer(Modifier.height(4.dp))
                Text(text = "${entry.source} • ${dateFormat.format(Date(entry.timestamp))}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = onCopy) {
                Icon(Icons.Default.ContentCopy, contentDescription = stringResource("copy_path"), modifier = Modifier.size(18.dp))
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Delete, contentDescription = stringResource("delete"), modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
private fun EmptyView() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.ContentPaste, contentDescription = null, modifier = Modifier.size(64.dp), tint = androidx.compose.ui.graphics.Color.Gray.copy(alpha = 0.5f))
            Spacer(Modifier.height(16.dp))
            Text(stringResource("select_device"), color = androidx.compose.ui.graphics.Color.Gray)
        }
    }
}
