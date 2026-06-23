package com.adbtool

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.adbtool.data.model.DeviceProperty
import com.adbtool.data.model.NavItem
import com.adbtool.data.remote.AdbToolApiClient
import com.adbtool.data.repository.AppRepository
import com.adbtool.data.repository.CommandRepository
import com.adbtool.data.repository.DeviceRepository
import com.adbtool.data.repository.createDatabase
import com.adbtool.ui.app.AppInfo
import com.adbtool.ui.app.AppManagerScreen
import com.adbtool.ui.app.FilterType
import com.adbtool.ui.app.filterApps
import com.adbtool.ui.command.AdbCommandScreen
import com.adbtool.ui.command.CommandHistory
import com.adbtool.ui.command.QuickCommand
import com.adbtool.ui.device.DeviceInfoScreen
import com.adbtool.ui.home.HomeScreen
import com.adbtool.viewmodel.appState
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

@Composable
fun AdbToolRoot() {
    val api = remember { AdbToolApiClient() }
    val database = remember { createDatabase() }
    val deviceRepository = remember { DeviceRepository(api, database) }
    val commandRepository = remember { CommandRepository(api, database) }
    val appRepository = remember { AppRepository(api) }
    val scope = rememberCoroutineScope()

    val darkTheme by appState.darkTheme.collectAsState()
    val devices by appState.devices.collectAsState()
    val selectedDevice by appState.selectedDevice.collectAsState()
    val expandedDevices by appState.expandedDevices.collectAsState()
    val currentNavItem by appState.currentNavItem.collectAsState()
    val backendOnline by appState.backendOnline.collectAsState()

    LaunchedEffect(Unit) {
        refreshDevices(deviceRepository)
    }

    AdbToolApp(darkTheme = darkTheme) {
        HomeScreen(
            devices = devices,
            selectedDevice = selectedDevice,
            expandedDevices = expandedDevices,
            currentNavItem = currentNavItem,
            backendOnline = backendOnline,
            darkTheme = darkTheme,
            onDeviceSelect = { appState.selectDevice(it) },
            onDeviceExpand = { appState.toggleDeviceExpanded(it) },
            onNavItemSelect = { appState.navigateTo(it) },
            onRefresh = { scope.launch { refreshDevices(deviceRepository) } },
            onWirelessAdb = {},
            onToggleTheme = { appState.toggleTheme() }
        ) {
            when (currentNavItem) {
                NavItem.Status -> DeviceStatusContent(deviceRepository)
                NavItem.Apps -> AppsContent(appRepository)
                NavItem.Command -> CommandContent(commandRepository)
                else -> UnsupportedContent()
            }
        }
    }
}

private suspend fun refreshDevices(deviceRepository: DeviceRepository) {
    appState.setBackendOnline(deviceRepository.isBackendReady())
    deviceRepository.getDevices()
        .onSuccess { appState.replaceDevices(it) }
        .onFailure {
            appState.setBackendOnline(false)
            appState.replaceDevices(emptyList())
        }
}

@Composable
private fun DeviceStatusContent(deviceRepository: DeviceRepository) {
    val selectedDevice by appState.selectedDevice.collectAsState()
    val scope = rememberCoroutineScope()
    var isLoading by remember { mutableStateOf(false) }
    var properties by remember { mutableStateOf(emptyList<DeviceProperty>()) }

    LaunchedEffect(selectedDevice?.serial) {
        val serial = selectedDevice?.serial ?: return@LaunchedEffect
        isLoading = true
        deviceRepository.getDeviceInfo(serial)
            .onSuccess { (device, props) ->
                appState.selectDevice(device)
                properties = props
            }
            .onFailure { properties = emptyList() }
        isLoading = false
    }

    DeviceInfoScreen(
        device = selectedDevice,
        properties = properties.map { com.adbtool.ui.device.DeviceProperty(it.label, it.value) },
        isLoading = isLoading,
        selectedDeviceSerial = selectedDevice?.serial,
        onRefresh = {
            scope.launch {
                val serial = selectedDevice?.serial ?: return@launch
                isLoading = true
                deviceRepository.getDeviceInfo(serial)
                    .onSuccess { (device, props) ->
                        appState.selectDevice(device)
                        properties = props
                    }
                    .onFailure { properties = emptyList() }
                isLoading = false
            }
        },
        onOpenApps = { appState.navigateTo(NavItem.Apps) }
    )
}

@Composable
private fun AppsContent(appRepository: AppRepository) {
    val selectedDevice by appState.selectedDevice.collectAsState()
    val scope = rememberCoroutineScope()
    var allApps by remember(selectedDevice?.serial) { mutableStateOf(emptyList<AppInfo>()) }
    var filterType by remember { mutableStateOf(FilterType.All) }
    var searchQuery by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    suspend fun loadApps() {
        val serial = selectedDevice?.serial ?: return
        isLoading = true
        error = null
        appRepository.getApps(serial)
            .onSuccess { apps ->
                allApps = apps.map {
                    AppInfo(
                        packageName = it.packageName,
                        label = it.label,
                        version = it.version,
                        isSystemApp = it.isSystemApp,
                        installTime = it.installTime,
                        updateTime = it.updateTime,
                        size = it.size
                    )
                }
            }
            .onFailure { error = it.message ?: "加载应用列表失败" }
        isLoading = false
    }

    LaunchedEffect(selectedDevice?.serial) {
        allApps = emptyList()
        error = null
        if (selectedDevice != null) {
            loadApps()
        }
    }

    AppManagerScreen(
        apps = filterApps(allApps, filterType, searchQuery),
        isLoading = isLoading,
        error = error,
        filterType = filterType,
        searchQuery = searchQuery,
        selectedDeviceSerial = selectedDevice?.serial,
        onFilterChange = { filterType = it },
        onSearchChange = { searchQuery = it },
        onRefresh = { scope.launch { loadApps() } },
        onLaunch = { app ->
            val serial = selectedDevice?.serial ?: return@AppManagerScreen
            scope.launch { appRepository.launchApp(serial, app.packageName) }
        },
        onStop = { app ->
            val serial = selectedDevice?.serial ?: return@AppManagerScreen
            scope.launch { appRepository.stopApp(serial, app.packageName) }
        },
        onUninstall = { app ->
            val serial = selectedDevice?.serial ?: return@AppManagerScreen
            scope.launch {
                appRepository.uninstallApp(serial, app.packageName)
                    .onSuccess { loadApps() }
                    .onFailure { error = it.message ?: "卸载失败" }
            }
        }
    )
}

@Composable
private fun CommandContent(commandRepository: CommandRepository) {
    val selectedDevice by appState.selectedDevice.collectAsState()
    val scope = rememberCoroutineScope()
    var currentCommand by remember { mutableStateOf("") }
    var isExecuting by remember { mutableStateOf(false) }
    val history by remember(selectedDevice?.serial) {
        selectedDevice?.serial?.let { serial ->
            commandRepository.getHistory(serial).map { items ->
                items.map {
                    CommandHistory(
                        id = it.id,
                        command = it.command,
                        output = it.output,
                        exitCode = it.exitCode,
                        timestamp = it.timestamp,
                        duration = it.duration
                    )
                }
            }
        } ?: kotlinx.coroutines.flow.flowOf(emptyList())
    }.collectAsState(emptyList())

    AdbCommandScreen(
        currentCommand = currentCommand,
        commandHistory = history,
        quickCommands = defaultQuickCommands(),
        isExecuting = isExecuting,
        selectedDeviceSerial = selectedDevice?.serial,
        onCommandChange = { currentCommand = it },
        onExecute = {
            val serial = selectedDevice?.serial ?: return@AdbCommandScreen
            val command = currentCommand.trim()
            if (command.isBlank()) return@AdbCommandScreen
            scope.launch {
                isExecuting = true
                commandRepository.executeAndSave(serial, command)
                currentCommand = ""
                isExecuting = false
            }
        },
        onQuickCommand = { currentCommand = it.command },
        onClearHistory = { scope.launch { commandRepository.clearHistory() } },
        onDeleteHistory = {
            scope.launch {
                commandRepository.deleteHistory(
                    com.adbtool.data.model.CommandHistory(
                        id = it.id,
                        command = it.command,
                        output = it.output,
                        exitCode = it.exitCode,
                        duration = it.duration,
                        timestamp = it.timestamp
                    )
                )
            }
        }
    )
}

@Composable
private fun UnsupportedContent() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text("该页面将在下一步迁移")
    }
}

private fun defaultQuickCommands(): List<QuickCommand> = listOf(
    QuickCommand("devices", "Devices", "devices"),
    QuickCommand("props", "Props", "shell getprop"),
    QuickCommand("packages", "Packages", "shell pm list packages"),
    QuickCommand("activity", "Activity", "shell dumpsys activity top")
)
