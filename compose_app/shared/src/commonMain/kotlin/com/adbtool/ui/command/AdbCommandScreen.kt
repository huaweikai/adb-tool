package com.adbtool.ui.command

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.adbtool.theme.MonoSmallTypography
import com.adbtool.i18n.stringResource

data class CommandHistory(
    val id: Long,
    val command: String,
    val output: String,
    val exitCode: Int,
    val timestamp: Long,
    val duration: Long
)

data class QuickCommand(
    val id: String,
    val label: String,
    val command: String,
    val description: String = ""
)

@Composable
fun AdbCommandScreen(
    currentCommand: String = "",
    commandHistory: List<CommandHistory> = emptyList(),
    quickCommands: List<QuickCommand> = emptyList(),
    isExecuting: Boolean = false,
    selectedDeviceSerial: String? = null,
    onCommandChange: (String) -> Unit = {},
    onExecute: () -> Unit = {},
    onQuickCommand: (QuickCommand) -> Unit = {},
    onStop: () -> Unit = {},
    onClearHistory: () -> Unit = {},
    onDeleteHistory: (CommandHistory) -> Unit = {}
) {
    val listState = rememberLazyListState()

    LaunchedEffect(commandHistory.size) {
        if (commandHistory.isNotEmpty()) {
            listState.animateScrollToItem(commandHistory.size - 1)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        if (selectedDeviceSerial == null) {
            EmptyView()
        } else {
            CommandToolbar(commandHistory.isNotEmpty(), isExecuting, onClearHistory, onStop)

            if (quickCommands.isNotEmpty()) {
                QuickCommandBar(quickCommands, onQuickCommand)
            }

            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(commandHistory, key = { it.id }) { item ->
                    CommandOutputItem(item, onDelete = { onDeleteHistory(item) })
                }

                if (commandHistory.isEmpty() && !isExecuting) {
                    item {
                        Box(modifier = Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.Terminal, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f))
                                Spacer(Modifier.height(8.dp))
                                Text("Execute ADB commands", color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }

            CommandInput(currentCommand, isExecuting, onCommandChange, onExecute)
        }
    }
}

@Composable
private fun CommandToolbar(hasHistory: Boolean, isExecuting: Boolean, onClearHistory: () -> Unit, onStop: () -> Unit) {
    Surface(color = MaterialTheme.colorScheme.surfaceVariant, tonalElevation = 1.dp) {
        Row(modifier = Modifier.fillMaxWidth().padding(12.dp, 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.Terminal, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(stringResource("command"), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.weight(1f))

            if (isExecuting) {
                Surface(shape = RoundedCornerShape(4.dp), color = MaterialTheme.colorScheme.errorContainer) {
                    Row(modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(6.dp))
                        Text("Executing...", fontSize = 11.sp, color = MaterialTheme.colorScheme.onErrorContainer)
                    }
                }
                Spacer(Modifier.width(8.dp))
                OutlinedButton(onClick = onStop, contentPadding = PaddingValues(horizontal = 12.dp)) {
                    Icon(Icons.Filled.Stop, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(stringResource("action_stop"), fontSize = 12.sp)
                }
            }

            if (hasHistory && !isExecuting) {
                OutlinedButton(onClick = onClearHistory, contentPadding = PaddingValues(horizontal = 12.dp)) {
                    Icon(Icons.Filled.Delete, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(stringResource("clear"), fontSize = 12.sp)
                }
            }
        }
    }
}

@Composable
private fun QuickCommandBar(commands: List<QuickCommand>, onCommandClick: (QuickCommand) -> Unit) {
    Surface(color = MaterialTheme.colorScheme.surface, tonalElevation = 0.5.dp) {
        LazyColumn(modifier = Modifier.height(IntrinsicSize.Min), contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)) {
            items(commands.chunked(4)) { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { cmd ->
                        AssistChip(onClick = { onCommandClick(cmd) }, label = { Text(cmd.label, fontSize = 11.sp) }, leadingIcon = { Icon(Icons.Default.Terminal, contentDescription = null, modifier = Modifier.size(14.dp)) })
                    }
                    repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

@Composable
private fun CommandOutputItem(item: CommandHistory, onDelete: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(8.dp)) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Terminal, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(6.dp))
                Text(item.command, modifier = Modifier.weight(1f), fontSize = 12.sp, fontFamily = FontFamily.Monospace, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("${item.duration}ms", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.width(4.dp))
                Surface(shape = RoundedCornerShape(4.dp), color = if (item.exitCode == 0) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f) else MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.5f)) {
                    Text("${item.exitCode}", fontSize = 10.sp, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp))
                }
                Spacer(Modifier.width(4.dp))
                IconButton(onClick = onDelete, modifier = Modifier.size(24.dp)) {
                    Icon(Icons.Filled.Close, contentDescription = null, modifier = Modifier.size(14.dp))
                }
            }

            if (item.output.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Surface(modifier = Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), shape = RoundedCornerShape(4.dp)) {
                    Text(text = item.output, modifier = Modifier.padding(8.dp), style = MonoSmallTypography, maxLines = 10, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun CommandInput(command: String, isExecuting: Boolean, onCommandChange: (String) -> Unit, onExecute: () -> Unit) {
    Surface(color = MaterialTheme.colorScheme.surfaceVariant, tonalElevation = 2.dp) {
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp, 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("$", fontSize = 16.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(8.dp))
            OutlinedTextField(
                value = command,
                onValueChange = onCommandChange,
                modifier = Modifier.weight(1f),
                placeholder = { Text("adb shell ...") },
                textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace, fontSize = 13.sp),
                singleLine = true,
                enabled = !isExecuting,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { if (command.isNotEmpty()) onExecute() })
            )
            Spacer(Modifier.width(12.dp))
            FilledTonalButton(onClick = onExecute, enabled = command.isNotEmpty() && !isExecuting) {
                Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text(stringResource("action_start"))
            }
        }
    }
}

@Composable
private fun EmptyView() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.Terminal, contentDescription = null, modifier = Modifier.size(64.dp), tint = androidx.compose.ui.graphics.Color.Gray.copy(alpha = 0.5f))
            Spacer(Modifier.height(16.dp))
            Text(stringResource("select_device"), color = androidx.compose.ui.graphics.Color.Gray)
        }
    }
}
