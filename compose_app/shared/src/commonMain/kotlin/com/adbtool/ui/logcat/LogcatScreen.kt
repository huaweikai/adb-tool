@file:OptIn(ExperimentalMaterial3Api::class)

package com.adbtool.ui.logcat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Article
import androidx.compose.material.icons.filled.ColorLens
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SaveAlt
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.adbtool.data.model.HighlightRule
import com.adbtool.data.model.LogEntry
import com.adbtool.theme.AdbToolColorScheme
import com.adbtool.theme.MonoSmallTypography
import com.adbtool.i18n.Translations

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LogcatScreen(
    tr: Translations,
    entries: List<LogEntry> = emptyList(),
    isStreaming: Boolean = false,
    isPaused: Boolean = false,
    autoScroll: Boolean = true,
    highlightRules: List<HighlightRule> = emptyList(),
    packagePid: String? = null,
    selectedDeviceSerial: String? = null,
    onStart: () -> Unit = {},
    onStop: () -> Unit = {},
    onPause: () -> Unit = {},
    onResume: () -> Unit = {},
    onClear: () -> Unit = {},
    onTagChange: (String) -> Unit = {},
    onPriorityChange: (String) -> Unit = {},
    onKeywordChange: (String) -> Unit = {},
    onPackageChange: (String) -> Unit = {},
    onPackageSubmit: () -> Unit = {},
    onAutoScrollToggle: (Boolean) -> Unit = {},
    onShowHighlightRules: () -> Unit = {},
    onSaveToSession: () -> Unit = {}
) {
    val listState = rememberLazyListState()
    @Suppress("DEPRECATION")
    val clipboardManager = LocalClipboardManager.current

    var tag by remember { mutableStateOf("") }
    var keyword by remember { mutableStateOf("") }
    var pkg by remember { mutableStateOf("") }
    var priority by remember { mutableStateOf("D") }

    LaunchedEffect(entries.size, autoScroll) {
        if (autoScroll && entries.isNotEmpty()) {
            listState.animateScrollToItem(entries.size - 1)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        LogcatToolbar(
            tr = tr,
            isStreaming = isStreaming,
            isPaused = isPaused,
            autoScroll = autoScroll,
            hasEntries = entries.isNotEmpty(),
            hasRunningSession = false,
            tag = tag,
            keyword = keyword,
            pkg = pkg,
            priority = priority,
            onTagChange = { tag = it; onTagChange(it) },
            onPriorityChange = { priority = it; onPriorityChange(it) },
            onKeywordChange = { keyword = it; onKeywordChange(it) },
            onPackageChange = { pkg = it; onPackageChange(it) },
            onPackageSubmit = onPackageSubmit,
            onStart = onStart,
            onStop = onStop,
            onPause = onPause,
            onResume = onResume,
            onClear = onClear,
            onSaveToSession = onSaveToSession,
            onAutoScrollToggle = onAutoScrollToggle,
            onShowHighlightRules = onShowHighlightRules
        )

        Box(modifier = Modifier.weight(1f)) {
            if (selectedDeviceSerial == null) {
                EmptyLogcatView(tr)
            } else if (entries.isEmpty()) {
                EmptyLogcatView(tr, showHint = true)
            } else {
                LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                    items(entries, key = { it.hashCode() }) { entry ->
                        LogEntryRow(
                            entry = entry,
                            highlightRule = highlightRules.find {
                                it.enabled && entry.message.contains(it.pattern, ignoreCase = true)
                            },
                            onCopy = { clipboardManager.setText(AnnotatedString(entry.raw)) }
                        )
                    }
                }
            }
        }

        LogcatStatusBar(
            tr = tr,
            entries = entries,
            isStreaming = isStreaming,
            isPaused = isPaused,
            wsConnected = true,
            activeRules = highlightRules.count { it.enabled },
            packagePid = packagePid
        )
    }
}

@Composable
private fun LogcatToolbar(
    tr: Translations,
    isStreaming: Boolean,
    isPaused: Boolean,
    autoScroll: Boolean,
    hasEntries: Boolean,
    hasRunningSession: Boolean,
    tag: String,
    keyword: String,
    pkg: String,
    priority: String,
    onTagChange: (String) -> Unit,
    onPriorityChange: (String) -> Unit,
    onKeywordChange: (String) -> Unit,
    onPackageChange: (String) -> Unit,
    onPackageSubmit: () -> Unit,
    onStart: () -> Unit,
    onStop: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onClear: () -> Unit,
    onSaveToSession: () -> Unit,
    onAutoScrollToggle: (Boolean) -> Unit,
    onShowHighlightRules: () -> Unit
) {
    val priorities = listOf("", "V", "D", "I", "W", "E", "F")
    var priorityExpanded by remember { mutableStateOf(false) }

    Surface(color = MaterialTheme.colorScheme.surfaceVariant, tonalElevation = 1.dp) {
        Column(modifier = Modifier.padding(12.dp, 8.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                ToolbarButton(icon = Icons.Filled.PlayArrow, label = tr.start, enabled = !isStreaming, onClick = onStart)
                ToolbarButton(icon = Icons.Filled.Stop, label = tr.stop, enabled = isStreaming, onClick = onStop)
                ToolbarButton(icon = Icons.Filled.Pause, label = tr.pause, enabled = isStreaming && !isPaused, onClick = onPause)
                ToolbarButton(icon = Icons.Filled.PlayArrow, label = tr.resume, enabled = isPaused, onClick = onResume)
                ToolbarButton(icon = Icons.Filled.Delete, label = tr.clear, enabled = isStreaming || hasEntries, onClick = onClear)
                ToolbarButton(icon = Icons.Filled.SaveAlt, label = tr.save, enabled = hasEntries && hasRunningSession, onClick = onSaveToSession)

                VerticalDivider(modifier = Modifier.height(20.dp), color = MaterialTheme.colorScheme.outline)

                OutlinedTextField(
                    value = tag,
                    onValueChange = onTagChange,
                    label = { Text("Tag", fontSize = 11.sp) },
                    modifier = Modifier.width(120.dp),
                    textStyle = LocalTextStyle.current.copy(fontSize = 12.sp),
                    singleLine = true
                )

                ExposedDropdownMenuBox(expanded = priorityExpanded, onExpandedChange = { priorityExpanded = it }) {
                    OutlinedTextField(
                        value = priority,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Level", fontSize = 11.sp) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = priorityExpanded) },
                        modifier = Modifier.width(85.dp).menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable, true),
                        textStyle = LocalTextStyle.current.copy(fontSize = 12.sp),
                        singleLine = true
                    )
                    ExposedDropdownMenu(expanded = priorityExpanded, onDismissRequest = { priorityExpanded = false }) {
                        priorities.forEach { p ->
                            DropdownMenuItem(
                                text = { Text(if (p.isEmpty()) tr.all else p, fontSize = 12.sp) },
                                onClick = { onPriorityChange(p); priorityExpanded = false }
                            )
                        }
                    }
                }

                OutlinedTextField(
                    value = keyword,
                    onValueChange = onKeywordChange,
                    label = { Text(tr.selectDevice, fontSize = 11.sp) },
                    modifier = Modifier.width(130.dp),
                    textStyle = LocalTextStyle.current.copy(fontSize = 12.sp),
                    singleLine = true
                )

                VerticalDivider(modifier = Modifier.height(20.dp), color = MaterialTheme.colorScheme.outline)

                OutlinedTextField(
                    value = pkg,
                    onValueChange = onPackageChange,
                    label = { Text("Package", fontSize = 11.sp) },
                    modifier = Modifier.width(180.dp),
                    textStyle = LocalTextStyle.current.copy(fontSize = 11.sp, fontFamily = FontFamily.Monospace),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { onPackageSubmit() })
                )

                Spacer(Modifier.weight(1f))

                FilledTonalButton(onClick = onShowHighlightRules, contentPadding = PaddingValues(horizontal = 12.dp)) {
                    Icon(Icons.Filled.ColorLens, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("${tr.selectDevice} 0", fontSize = 12.sp)
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = autoScroll, onCheckedChange = onAutoScrollToggle, modifier = Modifier.height(24.dp))
                    Text(tr.selectDevice, fontSize = 11.sp)
                }
            }
        }
    }
}

@Composable
private fun ToolbarButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, enabled: Boolean, onClick: () -> Unit) {
    FilledTonalButton(onClick = onClick, enabled = enabled, contentPadding = PaddingValues(horizontal = 12.dp)) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(4.dp))
        Text(label, fontSize = 12.sp)
    }
}

@Composable
private fun LogEntryRow(
    entry: LogEntry,
    highlightRule: HighlightRule?,
    onCopy: () -> Unit
) {
    val bgColor = highlightRule?.let { Color(it.color).copy(alpha = 0.1f) }
    val textColor = highlightRule?.let { Color(it.color) } ?: MaterialTheme.colorScheme.onSurface

    Row(
        modifier = Modifier.fillMaxWidth().background(bgColor ?: Color.Transparent).clickable(onClick = onCopy).padding(horizontal = 16.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (entry.isContinuation) {
            Text("│ ", style = MonoSmallTypography, color = MaterialTheme.colorScheme.outline)
            Text(entry.message.replace("\n", "↵ "), style = MonoSmallTypography, color = textColor, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        } else if (entry.time.isEmpty()) {
            Text(entry.raw, style = MonoSmallTypography, color = textColor, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        } else {
            Text(entry.time, style = MonoSmallTypography.copy(fontSize = 11.sp), color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(130.dp))
            Text("${entry.pid}-${entry.tid}", style = MonoSmallTypography.copy(fontSize = 11.sp), color = AdbToolColorScheme.StatusConnected, modifier = Modifier.width(80.dp), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Box(modifier = Modifier.width(24.dp).background(color = getPriorityColor(entry.priority).copy(alpha = 0.2f), shape = RoundedCornerShape(3.dp)), contentAlignment = Alignment.Center) {
                Text(entry.priority, style = MonoSmallTypography.copy(fontSize = 11.sp, fontWeight = FontWeight.Bold), color = getPriorityColor(entry.priority))
            }
            Spacer(Modifier.width(4.dp))
            Text(entry.tag.replace("\n", "↵ "), style = MonoSmallTypography.copy(fontSize = 11.sp), color = MaterialTheme.colorScheme.primary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.width(100.dp))
            Spacer(Modifier.width(4.dp))
            Text(entry.message.replace("\n", "↵ "), style = MonoSmallTypography.copy(fontSize = 11.sp), color = textColor, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun getPriorityColor(priority: String): Color = when (priority) {
    "V" -> AdbToolColorScheme.LogPriorityVerbose
    "D" -> AdbToolColorScheme.LogPriorityDebug
    "I" -> AdbToolColorScheme.LogPriorityInfo
    "W" -> AdbToolColorScheme.LogPriorityWarn
    "E" -> AdbToolColorScheme.LogPriorityError
    "F" -> AdbToolColorScheme.LogPriorityFatal
    else -> MaterialTheme.colorScheme.onSurfaceVariant
}

@Composable
private fun LogcatStatusBar(tr: Translations, entries: List<LogEntry>, isStreaming: Boolean, isPaused: Boolean, wsConnected: Boolean, activeRules: Int, packagePid: String?) {
    val status = when {
        isPaused -> tr.selectDevice
        isStreaming -> tr.selectDevice
        else -> tr.selectDevice
    }

    Surface(color = MaterialTheme.colorScheme.surfaceVariant, tonalElevation = 1.dp) {
        Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).height(28.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("${tr.selectDevice}: $status", fontSize = 11.sp)
            Text("${tr.selectDevice}: ${entries.size}", fontSize = 11.sp)
            Text("${tr.selectDevice}: $activeRules", fontSize = 11.sp)
            Box(modifier = Modifier.size(8.dp).background(color = if (wsConnected) AdbToolColorScheme.StatusConnected else AdbToolColorScheme.StatusDisconnected, shape = RoundedCornerShape(4.dp)))
            if (packagePid != null) {
                Spacer(Modifier.weight(1f))
                Text("${tr.selectDevice}: $packagePid", fontSize = 11.sp, color = MaterialTheme.colorScheme.primary)
            }
        }
    }
}

@Composable
private fun EmptyLogcatView(tr: Translations, showHint: Boolean = false) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.AutoMirrored.Filled.Article, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f))
            Spacer(Modifier.height(12.dp))
            Text(text = tr.selectDevice, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (showHint) Text(text = tr.selectDevice, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f))
        }
    }
}
