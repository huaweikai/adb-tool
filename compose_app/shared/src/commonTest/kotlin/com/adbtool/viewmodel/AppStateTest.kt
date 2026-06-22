package com.adbtool.viewmodel

import com.adbtool.data.model.Device
import com.adbtool.data.model.DeviceStatus
import com.adbtool.data.model.NavItem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AppStateTest {
    @Test
    fun replaceDevicesSelectsFirstDeviceAndStatusPageWhenNothingSelected() {
        val state = AppState()
        val device = Device(serial = "ABC123", model = "Pixel", status = DeviceStatus.Online)

        state.replaceDevices(listOf(device))

        assertEquals(device, state.selectedDevice.value)
        assertEquals(NavItem.Status, state.currentNavItem.value)
        assertTrue(state.expandedDevices.value.contains("ABC123"))
    }

    @Test
    fun replaceDevicesClearsSelectionWhenSelectedDeviceDisappears() {
        val state = AppState()
        state.replaceDevices(listOf(Device(serial = "ABC123", status = DeviceStatus.Online)))
        state.replaceDevices(emptyList())

        assertEquals(null, state.selectedDevice.value)
        assertEquals(null, state.currentNavItem.value)
        assertEquals(emptySet(), state.expandedDevices.value)
    }
}
