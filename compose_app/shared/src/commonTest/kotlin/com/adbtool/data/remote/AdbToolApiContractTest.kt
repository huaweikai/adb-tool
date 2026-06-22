package com.adbtool.data.remote

import kotlin.test.Test
import kotlin.test.assertEquals

class AdbToolApiContractTest {
    @Test
    fun deviceListEndpointUsesBackendRoute() {
        val request = AdbToolApiContract.devices()

        assertEquals("GET", request.method)
        assertEquals("/api/devices", request.path)
        assertEquals(emptyMap(), request.query)
    }

    @Test
    fun deviceDetailEndpointUsesSerialQuery() {
        val request = AdbToolApiContract.deviceDetail("ABC123")

        assertEquals("GET", request.method)
        assertEquals("/api/device-detail", request.path)
        assertEquals(mapOf("serial" to "ABC123"), request.query)
    }

    @Test
    fun executeCommandEndpointUsesAdbExecWithArgsBody() {
        val request = AdbToolApiContract.executeCommand("ABC123", "shell pm list packages")

        assertEquals("POST", request.method)
        assertEquals("/api/adb-exec", request.path)
        assertEquals(mapOf("serial" to "ABC123"), request.query)
        assertEquals(listOf("shell", "pm", "list", "packages"), request.args)
    }

    @Test
    fun mapsBackendDeviceStateToDtoFields() {
        val dto = DeviceDto.fromBackend(BackendDeviceDto(
            serial = "ABC123",
            state = "device",
            model = "Pixel 8",
            brand = "Google",
            sdk = "35"
        ))

        assertEquals("ABC123", dto.serial)
        assertEquals("Pixel 8", dto.model)
        assertEquals("Google", dto.manufacturer)
        assertEquals(35, dto.sdk)
        assertEquals("online", dto.status)
    }

    @Test
    fun mapsBackendDeviceDetailPropsToInfo() {
        val info = DeviceInfoDto.fromBackend("ABC123", mapOf(
            "ro.product.model" to "Pixel 8",
            "ro.product.manufacturer" to "Google",
            "ro.build.version.release" to "15",
            "ro.build.version.sdk" to "35"
        ))

        assertEquals("ABC123", info.serial)
        assertEquals("Pixel 8", info.model)
        assertEquals("Google", info.manufacturer)
        assertEquals("15", info.androidVersion)
        assertEquals(35, info.sdk)
        assertEquals("online", info.status)
        assertEquals("Pixel 8", info.properties["ro.product.model"])
    }
}
