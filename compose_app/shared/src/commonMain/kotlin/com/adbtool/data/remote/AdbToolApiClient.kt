package com.adbtool.data.remote

import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.plugins.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.plugins.logging.*
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.json.Json
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

class AdbToolApiClient(
    private val baseUrl: String = "http://127.0.0.1:9876"
) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        prettyPrint = false
    }

    private val client = HttpClient {
        install(ContentNegotiation) {
            json(json)
        }
        install(Logging) {
            logger = Logger.DEFAULT
            level = LogLevel.HEADERS
        }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 10_000
            socketTimeoutMillis = 60_000
        }
        defaultRequest {
            url(baseUrl)
            contentType(ContentType.Application.Json)
        }
    }

    suspend fun getDevices(): Result<List<DeviceDto>> = runCatching {
        val request = AdbToolApiContract.devices()
        client.get(request.path).apiBody<List<BackendDeviceDto>>().map(DeviceDto::fromBackend)
    }

    suspend fun getDeviceInfo(serial: String): Result<DeviceInfoDto> = runCatching {
        val request = AdbToolApiContract.deviceDetail(serial)
        val data = client.get(request.path) {
            request.query.forEach { (key, value) -> parameter(key, value) }
        }.apiBody<DeviceDetailDataDto>()
        DeviceInfoDto.fromBackend(serial, data.props)
    }

    suspend fun getFiles(serial: String, path: String): Result<List<FileItemDto>> = runCatching {
        val request = AdbToolApiContract.files(serial, path)
        client.get(request.path) {
            request.query.forEach { (key, value) -> parameter(key, value) }
        }.apiBody<FilesDataDto>().files
    }

    suspend fun getApps(serial: String): Result<List<AppInfoDto>> = runCatching {
        val request = AdbToolApiContract.packages(serial)
        client.get(request.path) {
            request.query.forEach { (key, value) -> parameter(key, value) }
        }.apiBody<PackagesDataDto>().packages.map(AppInfoDto::fromBackend)
    }

    @OptIn(ExperimentalTime::class)
    suspend fun executeCommand(serial: String, command: String): Result<CommandResultDto> = runCatching {
        val request = AdbToolApiContract.executeCommand(serial, command)
        val startedAt = Clock.System.now().toEpochMilliseconds()
        val data = client.post(request.path) {
            request.query.forEach { (key, value) -> parameter(key, value) }
            setBody(AdbExecRequest(request.args))
        }.apiBody<AdbExecDataDto>()
        CommandResultDto(
            command = command,
            output = data.output,
            exitCode = if (data.ok) 0 else 1,
            duration = Clock.System.now().toEpochMilliseconds() - startedAt
        )
    }

    suspend fun screenshot(serial: String): Result<ByteArray> = runCatching {
        val request = AdbToolApiContract.screenshot(serial)
        client.get(request.path) {
            request.query.forEach { (key, value) -> parameter(key, value) }
        }.body()
    }

    suspend fun pushClipboard(serial: String, text: String): Result<Unit> = runCatching {
        client.post("/api/clipboard-send") {
            parameter("serial", serial)
            setBody(mapOf("text" to text))
        }.apiBody<Map<String, String>>()
        return@runCatching
    }

    suspend fun pullClipboard(serial: String): Result<String> = runCatching {
        throw UnsupportedOperationException("当前后端未提供读取设备剪贴板接口")
    }

    suspend fun launchApp(serial: String, packageName: String): Result<Unit> = executeCommand(
        serial = serial,
        command = "shell monkey -p $packageName 1"
    ).map { }

    suspend fun stopApp(serial: String, packageName: String): Result<Unit> = executeCommand(
        serial = serial,
        command = "shell am force-stop $packageName"
    ).map { }

    suspend fun uninstallApp(serial: String, packageName: String): Result<Unit> = runCatching {
        client.post("/api/uninstall-package") {
            parameter("serial", serial)
            parameter("package", packageName)
        }.apiBody<Map<String, String>>()
        return@runCatching
    }

    suspend fun rebootDevice(serial: String): Result<Unit> = executeCommand(
        serial = serial,
        command = "reboot"
    ).map { }

    suspend fun checkHealth(): Result<Unit> = runCatching {
        val request = AdbToolApiContract.readiness()
        client.get(request.path).apiBody<Map<String, String>>()
        return@runCatching
    }

    fun close() {
        client.close()
    }

    private suspend inline fun <reified T> io.ktor.client.statement.HttpResponse.apiBody(): T {
        val response = body<ApiResponse<T>>()
        if (!response.ok) {
            throw IllegalStateException(response.error.ifBlank { "请求失败" })
        }
        return response.data ?: throw IllegalStateException("响应数据为空")
    }
}
