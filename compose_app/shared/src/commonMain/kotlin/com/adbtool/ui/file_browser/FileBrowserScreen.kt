@file:OptIn(ExperimentalMaterial3Api::class)

package com.adbtool.ui.file_browser

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.adbtool.data.model.FileItem
import com.adbtool.theme.AdbToolColorScheme
import com.adbtool.i18n.Translations
import com.adbtool.ui.common.ErrorView
import com.adbtool.ui.common.LoadingView

enum class SortKey { Name, Date, Size }

@Composable
fun FileBrowserScreen(
    tr: Translations,
    currentPath: String = "/",
    files: List<FileItem> = emptyList(),
    isLoading: Boolean = false,
    error: String? = null,
    history: List<String> = emptyList(),
    isGridMode: Boolean = false,
    isTransferring: Boolean = false,
    transferProgress: Float = 0f,
    transferFileName: String = "",
    transferPhase: String = "",
    selectedDeviceSerial: String? = null,
    onNavigate: (String) -> Unit = {},
    onGoHome: () -> Unit = {},
    onGoUp: () -> Unit = {},
    onRefresh: () -> Unit = {},
    onUpload: () -> Unit = {},
    onScreenshot: () -> Unit = {},
    onToggleGridMode: () -> Unit = {},
    onSortChange: (SortKey) -> Unit = {},
    onSortDirectionChange: () -> Unit = {},
    onCancelTransfer: () -> Unit = {},
    onDownload: (FileItem) -> Unit = {},
    onUploadToDir: (FileItem) -> Unit = {},
    onDelete: (FileItem) -> Unit = {},
    onRename: (FileItem) -> Unit = {},
    onCopyPath: (FileItem) -> Unit = {},
    onViewDetails: (FileItem) -> Unit = {}
) {
    var sortKey by remember { mutableStateOf(SortKey.Name) }
    var sortAsc by remember { mutableStateOf(true) }

    Column(modifier = Modifier.fillMaxSize()) {
        if (selectedDeviceSerial == null) {
            EmptyView(tr)
        } else {
            FilePathBar(
                tr = tr,
                currentPath = currentPath,
                isGridMode = isGridMode,
                isTransferring = isTransferring,
                onGoHome = onGoHome,
                onGoUp = onGoUp,
                onRefresh = onRefresh,
                onUpload = onUpload,
                onScreenshot = onScreenshot,
                onToggleGridMode = onToggleGridMode,
                sortKey = sortKey,
                sortAsc = sortAsc,
                onSortChange = { sortKey = it },
                onSortDirectionChange = { sortAsc = !sortAsc }
            )

            Box(modifier = Modifier.weight(1f)) {
                when {
                    isLoading -> LoadingView()
                    error != null -> ErrorView(tr, error, onRefresh)
                    files.isEmpty() -> EmptyDirView(tr)
                    isGridMode -> FileGridView(
                        tr = tr,
                        files = sortedFiles(files, sortKey, sortAsc),
                        onFileClick = { file -> if (file.isDir) onNavigate(file.path) },
                        onFileLongClick = {}
                    )
                    else -> FileListView(
                        tr = tr,
                        files = sortedFiles(files, sortKey, sortAsc),
                        onFileClick = { file -> if (file.isDir) onNavigate(file.path) },
                        onFileLongClick = {}
                    )
                }

                if (isTransferring) {
                    TransferOverlay(tr, transferFileName, transferProgress, transferPhase, onCancelTransfer)
                }
            }
        }
    }
}

private fun sortedFiles(files: List<FileItem>, sortKey: SortKey, asc: Boolean): List<FileItem> {
    val sorted = when (sortKey) {
        SortKey.Name -> files.sortedBy { it.name.lowercase() }
        SortKey.Date -> files.sortedBy { it.modified }
        SortKey.Size -> files.sortedBy { it.size }
    }
    return if (asc) sorted else sorted.reversed()
}

@Composable
private fun FilePathBar(
    tr: Translations,
    currentPath: String,
    isGridMode: Boolean,
    isTransferring: Boolean,
    onGoHome: () -> Unit,
    onGoUp: () -> Unit,
    onRefresh: () -> Unit,
    onUpload: () -> Unit,
    onScreenshot: () -> Unit,
    onToggleGridMode: () -> Unit,
    sortKey: SortKey,
    sortAsc: Boolean,
    onSortChange: (SortKey) -> Unit,
    onSortDirectionChange: () -> Unit
) {
    val pathParts = currentPath.split("/").filter { it.isNotEmpty() }
    var sortExpanded by remember { mutableStateOf(false) }

    Surface(color = MaterialTheme.colorScheme.surfaceVariant, tonalElevation = 1.dp) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp, 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onGoHome, enabled = !isTransferring) {
                Icon(Icons.Default.Home, contentDescription = tr.selectDevice, modifier = Modifier.size(20.dp))
            }
            IconButton(onClick = onGoUp, enabled = !isTransferring && currentPath != "/") {
                Icon(Icons.Filled.ArrowUpward, contentDescription = tr.path, modifier = Modifier.size(20.dp))
            }

            Spacer(Modifier.width(8.dp))

            listOf(
                "/" to tr.name,
                "/storage/emulated/0" to tr.files
            ).forEach { (_, label) ->
                QuickPathButton(label = label, isActive = false, onClick = {})
                Spacer(Modifier.width(4.dp))
            }

            Row(modifier = Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                pathParts.forEachIndexed { index, part ->
                    if (index > 0) Icon(Icons.Default.ChevronRight, contentDescription = null, modifier = Modifier.size(14.dp), tint = Color.Gray)
                    Text(
                        text = part,
                        fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = if (index == pathParts.size - 1) FontWeight.W600 else FontWeight.Normal,
                        color = if (index == pathParts.size - 1) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 2.dp)
                    )
                }
            }

            if (!isGridMode) {
                ExposedDropdownMenuBox(expanded = sortExpanded, onExpandedChange = { sortExpanded = it }) {
                    Surface(
                        onClick = { sortExpanded = true },
                        shape = RoundedCornerShape(4.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
                    ) {
                        Row(modifier = Modifier.padding(8.dp, 4.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(if (sortAsc) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("${
                                when (sortKey) {
                                    SortKey.Name -> tr.name
                                    SortKey.Date -> tr.modified
                                    SortKey.Size -> tr.size
                                }
                            }${if (sortAsc) " ↑" else " ↓"}", fontSize = 11.sp)
                        }
                    }
                    ExposedDropdownMenu(expanded = sortExpanded, onDismissRequest = { sortExpanded = false }) {
                        listOf(SortKey.Name to tr.name, SortKey.Date to tr.modified, SortKey.Size to tr.size).forEach { (key, label) ->
                            DropdownMenuItem(
                                text = { Text(label, fontSize = 12.sp) },
                                onClick = { onSortChange(key); sortExpanded = false },
                                trailingIcon = if (sortKey == key) { { Icon(if (sortAsc) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward, contentDescription = null, modifier = Modifier.size(16.dp)) } } else null
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.width(8.dp))

            IconButton(onClick = onToggleGridMode, enabled = !isTransferring) {
                Icon(if (isGridMode) Icons.AutoMirrored.Filled.List else Icons.Default.GridView, contentDescription = null, modifier = Modifier.size(20.dp))
            }

            Spacer(Modifier.width(8.dp))

            FilledTonalButton(onClick = onScreenshot, enabled = !isTransferring, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp)) {
                Icon(Icons.Default.CameraAlt, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text(tr.screenshot, fontSize = 12.sp)
            }

            Spacer(Modifier.width(8.dp))

            FilledTonalButton(onClick = onUpload, enabled = !isTransferring, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp)) {
                Icon(Icons.Default.Upload, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text(tr.upload, fontSize = 12.sp)
            }

            Spacer(Modifier.width(8.dp))

            IconButton(onClick = onRefresh, enabled = !isTransferring) {
                Icon(Icons.Default.Refresh, contentDescription = tr.refresh, modifier = Modifier.size(20.dp))
            }
        }
    }
}

@Composable
private fun QuickPathButton(label: String, isActive: Boolean, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(4.dp),
        color = if (isActive) MaterialTheme.colorScheme.primaryContainer else Color.Transparent,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
    ) {
        Text(text = label, fontSize = 11.sp, fontFamily = FontFamily.Monospace, modifier = Modifier.padding(8.dp, 4.dp))
    }
}

@Composable
private fun FileListView(tr: Translations, files: List<FileItem>, onFileClick: (FileItem) -> Unit, onFileLongClick: (FileItem) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize()) {
        items(files, key = { it.path }) { file ->
            FileListItem(tr, file, onFileClick, onFileLongClick)
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FileListItem(tr: Translations, file: FileItem, onClick: (FileItem) -> Unit, onLongClick: (FileItem) -> Unit) {
    val isTextFile = listOf(".txt", ".json", ".xml", ".log", ".md", ".kt", ".java", ".gradle", ".properties").any { file.name.endsWith(it) }

    Row(
        modifier = Modifier.fillMaxWidth().combinedClickable(onClick = { onClick.invoke(file) }, onLongClick = { onLongClick.invoke(file) }).padding(horizontal = 16.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = when {
                file.isDir -> Icons.Default.Folder
                isTextFile -> Icons.Default.Description
                else -> Icons.AutoMirrored.Filled.InsertDriveFile
            },
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = if (file.isDir) AdbToolColorScheme.FileFolder else MaterialTheme.colorScheme.primary
        )
        Spacer(Modifier.width(10.dp))
        Text(text = file.name, modifier = Modifier.weight(1f), fontSize = 12.sp, fontFamily = FontFamily.Monospace, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(text = file.modified, fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(100.dp))
        if (file.sizeFormatted.isNotEmpty()) {
            Text(text = file.sizeFormatted, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(70.dp), textAlign = TextAlign.End)
        }
    }
}

@Composable
private fun FileGridView(tr: Translations, files: List<FileItem>, onFileClick: (FileItem) -> Unit, onFileLongClick: (FileItem) -> Unit) {
    LazyVerticalGrid(columns = GridCells.Fixed(5), contentPadding = PaddingValues(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items(files, key = { it.path }) { file ->
            FileGridItem(tr, file, onFileClick, onFileLongClick)
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FileGridItem(tr: Translations, file: FileItem, onClick: (FileItem) -> Unit, onLongClick: (FileItem) -> Unit) {
    val isTextFile = listOf(".txt", ".json", ".xml", ".log", ".md", ".kt", ".java").any { file.name.endsWith(it) }

    Card(
        modifier = Modifier.aspectRatio(0.8f).combinedClickable(onClick = { onClick.invoke(file) }, onLongClick = { onLongClick.invoke(file) }),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(modifier = Modifier.fillMaxSize().padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Icon(
                imageVector = when {
                    file.isDir -> Icons.Default.Folder
                    isTextFile -> Icons.Default.Description
                    else -> Icons.AutoMirrored.Filled.InsertDriveFile
                },
                contentDescription = null,
                modifier = Modifier.size(28.dp),
                tint = if (file.isDir) AdbToolColorScheme.FileFolder else MaterialTheme.colorScheme.primary
            )
            Spacer(Modifier.height(6.dp))
            Text(text = file.name, fontSize = 10.sp, fontFamily = FontFamily.Monospace, maxLines = 2, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
            if (file.sizeFormatted.isNotEmpty()) {
                Text(text = file.sizeFormatted, fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun EmptyDirView(tr: Translations) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(tr.selectDevice, color = Color.Gray)
    }
}

@Composable
private fun EmptyView(tr: Translations) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.FolderOpen, contentDescription = null, modifier = Modifier.size(64.dp), tint = Color.Gray.copy(alpha = 0.5f))
            Spacer(Modifier.height(16.dp))
            Text(tr.selectDeviceHint, color = Color.Gray)
        }
    }
}

@Composable
private fun TransferOverlay(tr: Translations, fileName: String, progress: Float, phase: String, onCancel: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Surface(modifier = Modifier.fillMaxSize(), color = Color.Black.copy(alpha = 0.5f)) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Card(modifier = Modifier.width(300.dp), shape = RoundedCornerShape(12.dp)) {
                    Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(fileName, fontSize = 14.sp)
                        Spacer(Modifier.height(16.dp))
                        LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth())
                        Spacer(Modifier.height(8.dp))
                        Text("${(progress * 100).toInt()}% - $phase", fontSize = 12.sp)
                        Spacer(Modifier.height(16.dp))
                        OutlinedButton(onClick = onCancel) { Text(tr.cancel) }
                    }
                }
            }
        }
    }
}
