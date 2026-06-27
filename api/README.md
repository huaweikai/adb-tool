# ADB Tool API 响应协议

后端 JSON API 统一使用响应 envelope。客户端先根据 HTTP 状态判断请求是否成功，再读取 JSON 里的 `ok` 和 `data`。

## 通用 JSON 响应

成功响应：

```json
{
  "ok": true,
  "data": {}
}
```

失败响应：

```json
{
  "ok": false,
  "data": null,
  "error": "serial required"
}
```

字段含义：

- `ok`：接口业务处理是否成功。成功为 `true`，失败为 `false`。
- `data`：接口业务数据。不同接口的字段不同；失败时通常为 `null`，部分接口会带上可用于展示或诊断的补充字段。
- `error`：失败原因。`ok=false` 时给前端展示或记录；`ok=true` 时通常省略。

HTTP 状态码含义：

- `200`：接口成功，且 `ok=true`。
- `400`：请求参数错误、ADB 命令执行失败、安装失败等可预期业务错误。
- `403`：请求来源不允许，例如关停接口不是本机回环地址。
- `405`：请求方法错误，例如要求 `POST` 的接口使用了其他方法。
- `409`：当前状态冲突，例如正在录屏时再次开始录屏。
- `499`：客户端主动取消上传、下载或安装。
- `500`：后端或 ADB 执行过程中出现未归类错误。

## 非 JSON 成功响应例外

以下接口成功时直接返回二进制内容，不包 envelope：

- `GET /api/screenshot`：返回 `image/png`。
- `GET /api/pull-file`：返回 `application/octet-stream`，通过 `Content-Disposition` 附带文件名。
- `GET /api/screen-record-video`：返回 `video/mp4`。

这些接口失败时仍返回统一 JSON 错误 envelope。

`/ws/logs` 是 WebSocket 接口，不使用 HTTP JSON envelope。连接建立后的消息仍按 WebSocket 消息格式传输。

## 主要接口 data 字段

### 设备与基础信息

`GET /api/devices`

`data` 是设备数组：

- `serial`：设备序列号或无线连接地址。
- `state`：ADB 设备状态，例如 `device`、`offline`、`unauthorized`。
- `model`：设备型号。
- `brand`：设备品牌。
- `sdk`：Android SDK 版本。

`GET /api/adb-path`

- `path`：当前后端使用的 ADB 可执行文件路径。

`GET /api/info`

- `props`：设备 `getprop` 原始输出文本。

`GET /api/device-detail`

- `props`：设备属性键值表，来源于 `getprop`。

`POST /api/shutdown`

- `status`：固定为 `shutting down`，表示后端已接受关停请求。

`GET /api/identify`

- `name`：后端服务名称。
- `pid`：后端进程 ID。
- `started`：后端启动时间，RFC3339 格式。

### Logcat 与进程

`GET /api/clear`

- `status`：固定为 `ok`。

`GET /api/package-pid`

- `pid`：指定包名对应的进程 ID。

失败时 `data.pid` 可能为空字符串。

`GET /api/running-packages`

- `packages`：当前运行中的包名数组。

失败时 `data.packages` 可能为空数组。

### 文件管理

`GET /api/files`

- `files`：文件条目数组。

文件条目字段：

- `name`：文件名。
- `path`：设备端完整路径。
- `size`：文件大小，单位字节。
- `isDir`：是否为目录。符号链接目前也按可进入项处理。
- `permissions`：`ls -la` 输出里的权限字符串。
- `modified`：修改时间文本。

`GET /api/file-content`

- `content`：文本文件内容。

`POST /api/push-file`

- `status`：固定为 `ok`。

`POST /api/file-delete`

- `status`：固定为 `ok`。

`POST /api/file-rename`

- `status`：固定为 `ok`。

`POST /api/file-mkdir`

- `status`：固定为 `ok`。

`POST /api/file-touch`

- `status`：固定为 `ok`。

`GET /api/file-stat`

- `stat`：单个文件或目录的详情。

`stat` 字段：

- `name`：文件名。
- `path`：设备端完整路径。
- `size`：文件大小，单位字节。
- `isDir`：是否为目录。
- `permissions`：权限字符串。
- `modified`：修改时间文本。
- `raw`：原始 `ls -ld` 输出，便于排查解析问题。

### 应用管理

`GET /api/packages`

- `packages`：已安装应用数组。

应用字段：

- `packageName`：包名。
- `sourceDir`：APK 安装路径；部分设备或降级命令下可能为空。

`POST /api/uninstall-package`

- `status`：固定为 `ok`。

`POST /api/install-package`

成功时：

- `status`：固定为 `ok`。
- `output`：ADB install 原始输出。

失败时：

- `error`：转换后的安装失败原因，适合直接展示。
- `data.raw`：ADB install 原始输出。

### ADB 命令与无线 ADB

`POST /api/adb-exec`

成功时 `data`：

- `ok`：命令是否成功。
- `output`：ADB 原始输出。

失败时：

- `error`：失败原因。
- `data.ok`：固定为 `false`。
- `data.output`：失败时的 ADB 原始输出。

`POST /api/adb-wireless-pair`

- `ok`：配对命令是否成功。
- `output`：ADB 原始输出。

`POST /api/adb-wireless-connect`

- `ok`：连接命令是否成功。
- `output`：ADB 原始输出。

`POST /api/adb-wireless-disconnect`

- `ok`：断开命令是否成功。
- `output`：ADB 原始输出。

### 后端日志

`GET /api/backend-logs`

- `logs`：后端 ADB 执行日志数组。

日志条目字段由后端日志结构决定，通常包含命令、输出、错误和耗时等信息。

### 剪贴板助手

`GET /api/clipboard-check`

- `installed`：剪贴板助手是否已安装。

`POST /api/clipboard-install`

- `status`：固定为 `ok`。

`POST /api/clipboard-send`

- `status`：固定为 `ok`。

`POST /api/clipboard-uninstall`

- `status`：固定为 `ok`。

### scrcpy 投屏

`POST /api/scrcpy/start?serial=<serial>`

请求体可省略；省略时使用后端默认投屏参数。需要自定义时传入：

```json
{
  "scrcpy_options": {
    "max_size": 1024,
    "video_bit_rate": "8M",
    "video_codec": "h264",
    "audio_source": "output",
    "keyboard": "sdk",
    "mouse": "sdk",
    "stay_awake": true,
    "borderless": true
  }
}
```

成功时：

- `status`：固定为 `started`。
- `serial`：启动投屏的设备序列号。

请求参数或 `scrcpy_options` 校验失败时返回 `400`，`error` 会包含可展示的校验原因。

`POST /api/scrcpy/stop`

- `status`：固定为 `stopped`。即使当前没有投屏进程，也按无操作成功处理。

`GET /api/scrcpy/status`

可选参数：`serial`。传入后，只有当前投屏进程属于该设备时 `running` 才为 `true`。

返回字段：

- `running`：是否正在投屏。
- `serial`：当前投屏绑定的设备序列号。
- `pid`：scrcpy 进程 ID。
- `elapsed`：投屏已运行时长，单位秒。

`POST /api/scrcpy/action?serial=<serial>&action=<action>`

向设备发送快捷动作，底层使用 `adb shell input keyevent`，不要求 scrcpy 窗口处于焦点状态。

成功时：

- `status`：固定为 `ok`。
- `action`：已执行的动作名称。

### 录屏

`GET /api/screen-record?action=start`

- `status`：固定为 `recording`。
- `serial`：正在录屏的设备序列号。

`GET /api/screen-record?action=stop`

- `status`：固定为 `stopped`。
- `elapsed`：录屏持续时间，单位秒。

`GET /api/screen-record?action=status`

未录屏时：

- `recording`：`false`。

正在录屏时：

- `recording`：`true`。
- `serial`：正在录屏的设备序列号。
- `elapsed`：当前已录制时间，单位秒。

## 模拟器管理

模拟器相关的所有端点统一位于 `/api/emulator/...`，外加一条状态推送 WebSocket。

### 共享响应字段

#### EmulatorEngine / 引擎状态

出现在 `/api/emulator/engine/{status,validate,config,use}` 响应里，描述当前引擎探测到的工具链：

- `isValid`：引擎是否可用（emulator + avdmanager + sdkmanager + java 都齐备）。
- `emulatorPath`：emulator 可执行文件绝对路径；Windows 下带 `.exe`。
- `androidHome`：Android SDK 根目录。
- `emulatorVersion`：`emulator -version` 解析出的版本号。
- `avdmanagerPath` / `sdkmanagerPath`：对应工具路径。
- `javaPath` / `javaVersion`：当前选定的 Java 运行时。
- `toolchainReady`：工具链是否就绪（简化版的 `isValid`，用于 UI 状态指示）。
- `lastVerified`：最近一次校验时间，RFC3339 格式。
- `error`：最近一次探测错误信息，无错时为空。
- `hasSDK`：SDK 目录是否存在（`/engine/status` 独有）。
- `sdkPath`：当前 SDK 目录路径（`/engine/status` 独有）。
- `selectedSDKPath`：用户上次选择的 SDK 路径（`/engine/status` 独有）。
- `selectedSDKInvalid`：持久化的选择是否已失效（`/engine/status` 独有）。
- `emulatorMissing`：SDK 路径下是否缺 `emulator` 二进制（`/engine/use` 独有，UI 用来提示"点此安装"）。

#### SystemImage / 镜像条目

出现在 `/api/emulator/images`、`/api/emulator/image/{get,add,scan,import}`、`/api/emulator/instance/create`：

- `id`：镜像唯一标识，格式 `<apiLevel>-<variant>-<arch>`（如 `android-35-google_apis-x86_64`）。
- `name`：人类可读名字，如 `Android 15 (API 35, google_apis, x86_64)`。
- `apiLevel`：Android API level。
- `androidVersion`：人类可读版本号（"15"），由 API level 反查映射表得到。
- `arch`：CPU 架构（`x86_64` / `arm64-v8a`）。
- `variant`：`google_apis` / `google_apis_playstore` / `default`。
- `localPath`：镜像在磁盘上的真实路径。
- `managed`：路径是否在 adb-tool 管理目录 `~/.adb-tool/emulator/system-images/` 下，`true` 表示删除时会同时清理磁盘文件。
- `files`：镜像包含的文件名 → 相对路径字典（部分端点不返回）。
- `fileSize`：磁盘占用字节数。
- `status`：`pending` / `downloading` / `ready` / `error`。
- `progress`：0..1 的下载进度（仅在 `downloading` 时有意义）。

#### Instance / AVD 实例

出现在 `/api/emulator/instances`、`/api/emulator/instance/{get,create,start,stop}`，由 `emulatorInstanceToMap` 统一生成：

- `id`：实例 ID（服务端生成的稳定 UUID）。
- `imageId`：引用的镜像 ID。
- `name`：AVD 名称。
- `avdPath`：AVD 目录绝对路径。
- `config`：硬件配置，字段：
  - `cores`、`memoryMb`、`width`、`height`、`density`、`sdcardSize`、`gpuMode`。
- `status`：`stopped` / `starting` / `running` / `error`。
- `consolePort` / `adbPort`：分配给该实例的端口。
- `pid`：emulator 进程 ID，未运行时为 0。
- `serial`：emulator 启动后分配的 ADB 序列号。
- `snapshotId`：保存的快照 ID（如果有）。
- `createdAt` / `lastStartedAt`：RFC3339 时间戳。
- `lastError`：最近一次启动失败的错误信息。
- `logPath`：emulator stdout/stderr 捕获文件路径。
- `bootStage`：`launching` / `booting` / `adb_connecting` / `ready`。
- `bootProgress`：0..100 的启动进度。
- `bootMessage`：当前阶段的简短描述。

#### DownloadItem / 下载条目

出现在 `/api/emulator/downloads`、`/api/emulator/download/{progress,cancel,pause,resume}` 以及 SDK/Java/Image 启动下载的响应：

- `id`：下载唯一 ID，由 `DownloadMgr` 生成。
- `type`：`sdk` / `java` / `image` / `runtime`。
- `name`：人类可读名字。
- `status`：`pending` / `downloading` / `paused` / `completed` / `error` / `cancelled`。
- `progress`：0..1。
- `downloaded`：已下载字节数。
- `size`：总字节数。
- `error`：错误信息。
- `url`：实际下载的 URL（部分端点返回）。

### 引擎探测 / 配置

`GET /api/emulator/engine/status`

返回最新的 Engine 字段（见上文），同时触发一次重新探测。

`POST /api/emulator/engine/validate`

请求体：

```json
{ "androidHome": "/path/to/sdk", "emulatorPath": "/path/to/emulator" }
```

返回 Engine 字段；如果两个路径都为空则走默认探测流程。

`PUT /api/emulator/engine/config`

同 `/validate` 的请求体与响应，但额外持久化用户的工具链选择到磁盘。重启后端后会自动套用。

`POST /api/emulator/engine/use`

请求体：

```json
{ "sdkPath": "/path/to/sdk" }
```

接受该路径作为当前 SDK，并把工具链选择持久化。校验规则（`validateScanPath`）：

- 拒绝 `..`、纯根（`/`、`C:\`）、相对路径。
- 要求至少满足：`<sdkPath>/emulator/emulator`（或 `.exe`）存在 **或** `<sdkPath>/cmdline-tools/latest/bin/sdkmanager` 存在（cmdline-tools-only SDK）。

返回 Engine 字段 + `emulatorMissing: boolean`（提示用户是否还需要装 emulator 二进制）。

`POST /api/emulator/sdk/use`

`use` 的旧别名，部分老客户端还在用；与 `/engine/use` 同语义。

### SDK 管理

`POST /api/emulator/sdk/import`

multipart/form-data 上传 zip：

- 字段 `sdk`：zip 文件，最大 500MB。

解压到 `~/.adb-tool/sdk/`，重检测引擎。返回：

- `success`
- `sdkPath`、`emulatorPath`、`sizeBytes`、`toolchainReady`

`DELETE /api/emulator/sdk/delete?confirm=true`

销毁性：递归删除 `~/.adb-tool/sdk/` 整个目录。**必须**带 `?confirm=true`，否则 400。返回 `{success: true}`。

`GET /api/emulator/sdk/detect`

扫描系统中常见的 SDK 安装位置，返回 `{sdks: [...]}`。`sdks` 条目字段定义在 `emulator.ScanSystemSDKs()`，通常包含 `path`、`androidHome`、`platformToolsPath`、`hasEmulator` 等。

`POST /api/emulator/sdk/download`

请求体：

```json
{
  "url": "https://dl.google.com/.../commandlinetools-mac-11076708_latest.zip",
  "id": "commandlinetools",
  "sha256": "可选校验",
  "name": "Command-line Tools (latest)"
}
```

URL 必须通过 `validateDownloadURL`（仅 `http(s)`，拒绝 loopback/link-local），ID 必须通过 `sanitizeDownloadIDComponent`（拒绝路径分隔符、`..`）。返回 `{id, status, progress}` 形式的下载快照（详见 DownloadItem）。

`POST /api/emulator/sdk/install`

启动 sdkmanager 异步安装一个或多个包：

```json
{ "packages": ["emulator", "platform-tools", "system-images;android-35;google_apis;arm64-v8a"] }
```

前提：已通过 `/engine/use` 选过 SDK，且接受过所有 license。返回完整的安装 job 对象（`InstallJob`）：

- `id`
- `status`：`pending` / `running` / `completed` / `error`
- `progress`：0..1
- `message`：当前阶段描述
- `packages`：原始传入的包列表
- `error`：失败原因（`status=error` 时）
- `startedAt` / `finishedAt`：RFC3339

`GET /api/emulator/sdk/install/status?id=<jobId>`

轮询获取上面那个 job 的当前状态。

### Java 运行时

`GET /api/emulator/java/status`

返回：

- `status`：`found` / `not_found`
- `systemJava`：系统 PATH 上探测到的 Java（`{path, version, vendor}`，没有时为 `null`）
- `path` / `version`：`systemJava` 的扁平化字段（仅在 `status=found` 时存在）
- `runtimes`：所有可用运行时数组
- `selectedPath`：用户上次选择的运行时路径（持久化）
- `selectedInvalid`：选择是否已失效
- `embedded`：内置随包发布的 Java 列表
- `downloads`：当前 Java 类型下载条目数组
- `defaultDownloads`：建议下载列表（Eclipse Temurin 各版本）

`GET /api/emulator/java/list`

只返回 `{runtimes, selectedPath}` 的精简版。

`POST /api/emulator/java/validate`

请求体 `{javaPath}`，调用 `java -version` 探测。返回：

- 成功：`{valid: true, path, version, vendor}`
- 失败：`{valid: false, error}`

`POST /api/emulator/java/select`

请求体 `{javaPath}`，校验通过后持久化并写入当前 engine。返回 `{selected: true, path, version, vendor}` 或失败 `{selected: false, error}`。

`POST /api/emulator/java/download`

请求体：

```json
{
  "url": "可选，省略时按 version 走 Temurin 默认下载",
  "id": "temurin-17",
  "sha256": "可选",
  "name": "可选",
  "version": "17"
}
```

`id` 通过 `sanitizeDownloadIDComponent`，URL 通过 `validateDownloadURL`。返回 `{id, status, progress, url}`。

`POST /api/emulator/java/import`

multipart/form-data 上传 zip：

- `id`：runtime id，将作为管理目录名
- `file`：zip 文件，最大 500MB

解压到 `~/.adb-tool/emulator/java-runtime/<id>/`。返回 `{success, id, path, version, vendor, originalName}`。

`POST /api/emulator/java/delete`

请求体 `{id}`。仅删除 adb-tool 管理的运行时，不影响系统 Java；如果被删的是当前 selected 且验证后无法恢复，selected 会被清空。返回 `{success, id}`。

### 统一下载管理

模拟器相关的所有下载都走同一组端点，按 `type` 区分（`sdk` / `java` / `image` / `runtime`）。

`GET /api/emulator/downloads?type=<type>`

返回 `{downloads: DownloadItem[]}`。`type` 省略时返回全部。

`GET /api/emulator/download/progress?id=<id>`

返回单个 DownloadItem。未找到时返回 `{id, status: "not_found", progress: 0}`，**不返回 404**（方便前端轮询）。

`POST /api/emulator/download/cancel?id=<id>`

返回 `{status: "cancelled"}`。

`POST /api/emulator/download/pause?id=<id>`

返回 `{status: "paused"}`。

`POST /api/emulator/download/resume?id=<id>`

恢复后返回该 DownloadItem 的当前 `{id, status, progress}`，找不到则 `{status: "not_found"}`。

### 镜像管理

`GET /api/emulator/images`

返回 `{images: SystemImage[]}`（见上文"共享响应字段"）。

`GET /api/emulator/image/get?id=<id>`

返回单个 SystemImage。404 时返回 `{error: "image not found"}`。

`POST /api/emulator/image/add`

请求体：

```json
{
  "url": "https://.../system-images.zip",
  "id": "android-35-google_apis-arm64-v8a",
  "name": "Android 35 (google_apis, arm64-v8a)",
  "sha256": "可选",
  "apiLevel": 35,
  "arch": "arm64-v8a",
  "variant": "google_apis"
}
```

URL 通过 `validateDownloadURL`，`id` / `arch` / `variant` 通过 `sanitizeDownloadIDComponent`。同时把 URL 加入 `ImageSources` 持久化地址簿（按 URL 去重）。返回 `{id, status, progress}`。

`POST /api/emulator/image/import` （multipart/form-data）

字段 `image`：zip 文件，最大 2GB。解压后扫描出所有 image 并注册到持久化 registry。返回：

- `success: true`
- `count`：注册成功的镜像数
- `images`：SystemImage 数组
- `image`：数组第一个元素（兼容旧客户端；空数组时为 `null`）

`POST /api/emulator/image/import-path`

请求体 `{path}`（绝对路径，可指向目录或 zip）。扫描后注册。校验规则同 `/image/scan`（`validateScanPath` 拒 `..`、根、相对路径）。

返回同 `/image/import`。

`POST /api/emulator/image/scan`

请求体 `{path}`。仅扫描 + 注册，不导入文件。校验同 `/image/import-path`。返回 `{success, found: <int>}`。

`DELETE /api/emulator/image/delete?id=<id>&confirm=true`

销毁性：分两种模式：

- managed（路径在 `~/.adb-tool/emulator/system-images/` 下）→ `os.RemoveAll(path)` 真删磁盘文件
- 其它路径 → 仅从 `~/.adb-tool/emulator/images.json` 摘掉记录，文件不动

`?confirm=true` 是必需的安全闸，与 SDK/AVD 删除一致。**被 AVD 引用的镜像会被拒绝**：

- 返回 `409 Conflict`
- `error`：可读原因
- `data.inUseBy`：`string[]`，正在引用该镜像的 AVD 名称列表

成功时返回 `{success, id, path, managed, deleteMode}`，其中 `deleteMode` 为 `filesRemoved` 或 `registryOnly`。

`GET /api/emulator/image/sources`

返回 `{sources: ImageSource[]}`，字段包含 `url` / `name` / `apiLevel` / `arch` / `variant` / `sha256` / `addedAt`。

`POST /api/emulator/image/source/add`

请求体同 `/image/add` 的镜像元数据子集（`url` / `name` / `apiLevel` / `arch` / `variant` / `sha256`）。URL 重复时跳过；返回 `{success, sources}`。

`POST /api/emulator/image/source/remove`

请求体 `{url}`。返回 `{success, sources}`。

### 实例（AVD）管理

`GET /api/emulator/instances`

返回 `{instances: Instance[]}`（见上文 Instance 字段）。实例管理器未初始化时 503。

`GET /api/emulator/instance/get?id=<id>`

返回单个 Instance 或 404。

`POST /api/emulator/instance/create`

请求体：

```json
{
  "imageId": "android-35-google_apis-x86_64",
  "name": "Pixel_7_API_35",
  "cores": 4,
  "memoryMb": 2048,
  "width": 1080,
  "height": 1920,
  "density": 420,
  "sdcardSize": "512M",
  "gpuMode": "auto"
}
```

`imageId` + `name` 必填。返回新创建的 Instance。

`POST /api/emulator/instance/start?id=<id>`

启动 emulator 子进程。返回启动后的 Instance（`status: "starting"`），同时通过 `/ws/emulator/status` 推送 boot 进度。启动后会发布 `BroadcastStatus` 让所有 watcher 看到状态切换。

`POST /api/emulator/instance/stop?id=<id>`

请求先 `Get(id)` 验证存在（避免 404 时已经 partial stop），再 Stop。返回停止后的 Instance（`status: "stopped"`，PID=0，boot 字段清空）。

`DELETE /api/emulator/instance/delete?id=<id>&confirm=true`

销毁性：递归删 AVD 目录、删除 `<name>.ini` pointer 文件、释放端口。**必须**带 `?confirm=true`。返回 `{id, deleted: true}`。

`GET /api/emulator/instance/log?id=<id>&tail=<N>`

读 AVD emulator.log 最后 N 行（默认 80，最大 500）。返回 `{id, logPath, tail, lines: string[]}`。文件不存在时返回 200 + 空 `lines`（不报错，方便 UI 占位）。

### WebSocket：实时状态推送

`GET /ws/emulator/status?id=<id1>&id=<id2>&...` （upgrade）

维持长连接，后端推送实例状态变更。多个 `id=` 查询参数指定要订阅的实例列表；省略则订阅全部。

推送消息是 JSON 对象（`emulator.StatusUpdate`）：

- `type`：`status` / `log` / `metrics`
- `instanceId`：被更新的实例 ID
- `status`：新的 `InstanceStatus`（`type=status` 时）
- `message`：日志或说明（`type=log` 时）
- `timestamp`：RFC3339
- `data`：扩展数据（`type=metrics` 时携带序列号、ping 等）
- `bootStage` / `bootProgress` / `bootMessage`：启动进度（`launching` / `booting` / `adb_connecting` / `ready`，0..100）

WebSocket 自带心跳：

- 服务端每 25 秒发一次 Ping
- 客户端必须在 60 秒内 Pong 一次，否则连接被回收（防止半开连接泄漏 goroutine，B5）

客户端也可以发送字符串消息 `ping`，服务端会回 `PongMessage` 帧作为应用层心跳。

错误响应与 envelope 一致：`{ok: false, error: "...", data?: {...}}`。具体 status：

- `400` 参数错误 / 校验失败 / 缺 `?confirm=true`
- `403` 调用方不在 loopback（罕见，理论上不会发生）
- `404` 实例或镜像 ID 找不到
- `405` 方法错误
- `409` 资源状态冲突（如镜像被实例引用）
- `500` 后端内部错误
- `503` 模拟器子系统未初始化（`/api/emulator/instances*` 在 InstanceManager 没起来时）
