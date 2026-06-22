package com.adbtool.viewmodel

import com.adbtool.data.model.Device
import com.adbtool.data.model.NavItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class AppState {
    private val _devices = MutableStateFlow<List<Device>>(emptyList())
    val devices: StateFlow<List<Device>> = _devices.asStateFlow()

    private val _selectedDevice = MutableStateFlow<Device?>(null)
    val selectedDevice: StateFlow<Device?> = _selectedDevice.asStateFlow()

    private val _expandedDevices = MutableStateFlow<Set<String>>(emptySet())
    val expandedDevices: StateFlow<Set<String>> = _expandedDevices.asStateFlow()

    private val _currentNavItem = MutableStateFlow<NavItem?>(null)
    val currentNavItem: StateFlow<NavItem?> = _currentNavItem.asStateFlow()

    private val _backendOnline = MutableStateFlow(false)
    val backendOnline: StateFlow<Boolean> = _backendOnline.asStateFlow()

    private val _darkTheme = MutableStateFlow(true)
    val darkTheme: StateFlow<Boolean> = _darkTheme.asStateFlow()

    fun updateDevices(devices: List<Device>) {
        replaceDevices(devices)
    }

    fun replaceDevices(devices: List<Device>) {
        _devices.value = devices
        val selected = _selectedDevice.value
        val nextSelected = when {
            devices.isEmpty() -> null
            selected == null -> devices.first()
            devices.none { it.serial == selected.serial } -> devices.first()
            else -> devices.first { it.serial == selected.serial }
        }
        _selectedDevice.value = nextSelected
        _expandedDevices.value = nextSelected?.let { setOf(it.serial) } ?: emptySet()
        _currentNavItem.value = nextSelected?.let { _currentNavItem.value ?: NavItem.Status }
    }

    fun selectDevice(device: Device?) {
        _selectedDevice.value = device
    }

    fun toggleDeviceExpanded(serial: String) {
        val current = _expandedDevices.value.toMutableSet()
        if (current.contains(serial)) {
            current.remove(serial)
        } else {
            current.add(serial)
        }
        _expandedDevices.value = current
    }

    fun navigateTo(navItem: NavItem) {
        _currentNavItem.value = navItem
    }

    fun setBackendOnline(online: Boolean) {
        _backendOnline.value = online
    }

    fun toggleTheme() {
        _darkTheme.value = !_darkTheme.value
    }
}

val appState = AppState()
